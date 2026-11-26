import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:sodium/sodium_sumo.dart';

import '../../core/crypto/crypto_exceptions.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/crypto/kdf_params.dart';
import '../vault/domain/vault_models.dart';

/// Citadel encrypted archive (`.citadel`), used for backups and encrypted
/// exports.
///
/// ```
/// "CITADEL-ARCHIVE\n"        16-byte magic
/// u32 big-endian             header length
/// header JSON (UTF-8)        format, mode, createdAt, salts, KDF params /
///                            wrapped-key material - nothing secret
/// secretstream ciphertext    24-byte header + 64 KiB authenticated chunks
/// ```
/// Plaintext inside the stream is JSON Lines: folders, tags, items,
/// attachment chunks, then an `end` record with counts. The stream key is
/// `HKDF(baseKey, "citadel/v1/archive|" + SHA-256(header))`, so changing any
/// header byte makes decryption fail, and the FINAL tag plus the `end`
/// record detect truncation. Nothing is ever written to disk in plaintext:
/// encryption happens while streaming into the output sink.
///
/// Modes:
///  * `vault`    - base key = HKDF(VEK, "citadel/v1/backup"). The header
///                 carries the wrapped VEK + KDF params, so the master password
///                 (as of backup time) restores it on any device.
///  * `password` - base key = Argon2id(export password, salt in header).
///                 Portable; independent of the vault keys.
abstract final class ArchiveFormat {
  static final magic = Uint8List.fromList(utf8.encode('CITADEL-ARCHIVE\n'));
  static const formatVersion = 1;
  static const attachmentChunk = 48 * 1024;

  static String streamContext(Uint8List headerBytes) => 'citadel/v1/archive|${CryptoService.sha256Hex(headerBytes)}';
}

enum ArchiveMode { vault, password }

class ArchiveHeader {
  ArchiveHeader({
    required this.mode,
    required this.createdAt,
    required this.purpose,
    this.vaultId,
    this.keyGeneration,
    this.material,
    this.kdf,
  });

  final ArchiveMode mode;
  final DateTime createdAt;

  /// "manual", "auto", "pre-restore", "export"...
  final String purpose;
  final String? vaultId;
  final int? keyGeneration;

  /// VaultKeyMaterial JSON (vault mode).
  final Map<String, dynamic>? material;

  /// KdfParams (password mode).
  final KdfParams? kdf;

  Map<String, Object?> toJson() => {
    'app': 'citadel',
    'format': ArchiveFormat.formatVersion,
    'mode': mode.name,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'purpose': purpose,
    'vaultId': vaultId,
    'keyGeneration': keyGeneration,
    'material': material,
    'kdf': kdf?.toJson(),
  };

  factory ArchiveHeader.fromJson(Map<String, dynamic> j) {
    if (j['app'] != 'citadel' || j['format'] != ArchiveFormat.formatVersion) {
      throw const CryptoFormatException('Unsupported archive version');
    }
    return ArchiveHeader(
      mode: ArchiveMode.values.byName(j['mode'] as String),
      createdAt: DateTime.parse(j['createdAt'] as String),
      purpose: j['purpose'] as String? ?? 'manual',
      vaultId: j['vaultId'] as String?,
      keyGeneration: j['keyGeneration'] as int?,
      material: (j['material'] as Map?)?.cast<String, dynamic>(),
      kdf: j['kdf'] == null ? null : KdfParams.fromJson((j['kdf'] as Map).cast<String, dynamic>()),
    );
  }

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
}

class ArchiveContents {
  ArchiveContents();
  final folders = <Folder>[];
  final tags = <Tag>[];
  final items = <VaultItem>[];

  /// attachment id -> plaintext bytes
  final attachments = <String, Uint8List>{};
  final missingAttachments = <String>[];
  bool complete = false;
}

/// Plaintext record source for the archive writer.
typedef AttachmentLoader = Future<Uint8List?> Function(AttachmentMeta meta);

class ArchiveCodec {
  ArchiveCodec(this.crypto);
  final CryptoService crypto;

  Stream<List<int>> _lines({
    required List<Folder> folders,
    required List<Tag> tags,
    required List<VaultItem> items,
    required AttachmentLoader? loadAttachment,
  }) async* {
    List<int> line(Map<String, Object?> j) => utf8.encode('${jsonEncode(j)}\n');
    for (final f in folders) {
      yield line({'t': 'folder', 'd': f.toJson()});
    }
    for (final t in tags) {
      yield line({'t': 'tag', 'd': t.toJson()});
    }
    var attachmentCount = 0;
    for (final i in items) {
      yield line({'t': 'item', 'd': i.toJson()});
      if (loadAttachment == null) continue;
      for (final a in i.attachments) {
        final bytes = await loadAttachment(a);
        if (bytes == null) {
          yield line({'t': 'att-missing', 'id': a.id});
          continue;
        }
        attachmentCount++;
        for (var off = 0; off < bytes.length || off == 0; off += ArchiveFormat.attachmentChunk) {
          final end = (off + ArchiveFormat.attachmentChunk).clamp(0, bytes.length);
          yield line({
            't': 'att',
            'id': a.id,
            'last': end >= bytes.length,
            'b': base64.encode(Uint8List.sublistView(bytes, off, end)),
          });
          if (bytes.isEmpty) break;
        }
        bytes.fillRange(0, bytes.length, 0);
      }
    }
    yield line({
      't': 'end',
      'folders': folders.length,
      'tags': tags.length,
      'items': items.length,
      'attachments': attachmentCount,
    });
  }

  /// Writes an archive into [sink]. [baseKey] is the backup subkey (vault
  /// mode) or the Argon2id-derived key (password mode).
  Future<void> write({
    required EventSink<List<int>> sink,
    required ArchiveHeader header,
    required SecureKey baseKey,
    required List<Folder> folders,
    required List<Tag> tags,
    required List<VaultItem> items,
    AttachmentLoader? loadAttachment,
  }) async {
    final headerBytes = header.encode();
    final len = ByteData(4)..setUint32(0, headerBytes.length);
    sink
      ..add(ArchiveFormat.magic)
      ..add(len.buffer.asUint8List())
      ..add(headerBytes);
    final streamKey = crypto.hkdf(baseKey, ArchiveFormat.streamContext(headerBytes));
    try {
      final plain = _lines(folders: folders, tags: tags, items: items, loadAttachment: loadAttachment);
      await for (final chunk in crypto.encryptStream(plain, streamKey)) {
        sink.add(chunk);
      }
    } finally {
      streamKey.dispose();
    }
  }

  /// Splits an archive into (header, header bytes, ciphertext offset).
  static (ArchiveHeader, Uint8List, int) readHeader(Uint8List data) {
    final m = ArchiveFormat.magic;
    if (data.length < m.length + 4) throw const CryptoFormatException('Not a Citadel archive');
    for (var i = 0; i < m.length; i++) {
      if (data[i] != m[i]) throw const CryptoFormatException('Not a Citadel archive');
    }
    final len = ByteData.sublistView(data, m.length, m.length + 4).getUint32(0);
    if (len > 1024 * 1024 || m.length + 4 + len > data.length) {
      throw const CryptoFormatException('Corrupt archive header');
    }
    final headerBytes = Uint8List.sublistView(data, m.length + 4, m.length + 4 + len);
    final header = ArchiveHeader.fromJson(jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>);
    return (header, headerBytes, m.length + 4 + len);
  }

  Future<ArchiveContents> read(Uint8List data, SecureKey baseKey) async {
    final (_, headerBytes, offset) = readHeader(data);
    final streamKey = crypto.hkdf(baseKey, ArchiveFormat.streamContext(headerBytes));
    final out = ArchiveContents();
    final pending = <String, BytesBuilder>{};
    try {
      final plain = crypto.decryptStream(Stream.value(Uint8List.sublistView(data, offset)), streamKey);
      final lines = plain.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter());
      await for (final l in lines) {
        if (l.isEmpty) continue;
        final j = jsonDecode(l) as Map<String, dynamic>;
        switch (j['t']) {
          case 'folder':
            out.folders.add(Folder.fromJson((j['d'] as Map).cast()));
          case 'tag':
            out.tags.add(Tag.fromJson((j['d'] as Map).cast()));
          case 'item':
            out.items.add(VaultItem.fromJson((j['d'] as Map).cast()));
          case 'att':
            final id = j['id'] as String;
            (pending[id] ??= BytesBuilder(copy: false)).add(base64.decode(j['b'] as String));
            if (j['last'] == true) out.attachments[id] = pending.remove(id)!.takeBytes();
          case 'att-missing':
            out.missingAttachments.add(j['id'] as String);
          case 'end':
            out.complete =
                j['items'] == out.items.length && j['folders'] == out.folders.length && j['tags'] == out.tags.length;
        }
      }
    } on SodiumException {
      throw const DecryptionFailedException('Wrong password or the archive was modified');
    } on StreamClosedEarlyException {
      throw const DecryptionFailedException('Archive is truncated');
    } finally {
      streamKey.dispose();
    }
    if (!out.complete) throw const DecryptionFailedException('Archive is incomplete');
    return out;
  }
}
