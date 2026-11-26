import 'dart:async';
import 'dart:typed_data';

import 'package:citadel/core/crypto/crypto_exceptions.dart';
import 'package:citadel/core/crypto/crypto_service.dart';
import 'package:citadel/core/crypto/kdf_params.dart';
import 'package:citadel/features/backup/backup_format.dart';
import 'package:citadel/features/vault/domain/item_type.dart';
import 'package:citadel/features/vault/domain/vault_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';

void main() {
  late CryptoService crypto;
  setUpAll(() async => crypto = CryptoService(await SodiumSumoInit.init()));

  Future<Uint8List> write(
    ArchiveCodec codec,
    ArchiveHeader header,
    SecureKey key, {
    List<VaultItem>? items,
    AttachmentLoader? loader,
  }) async {
    final b = BytesBuilder();
    final c = StreamController<List<int>>();
    final done = c.stream.forEach(b.add);
    await codec.write(
      sink: c.sink,
      header: header,
      baseKey: key,
      folders: [Folder(id: 'f', name: 'Work', createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026))],
      tags: const [],
      items:
          items ??
          [
            VaultItem(
              id: 'i',
              type: ItemType.login,
              name: 'Mail',
              fields: const {'password': 'pw-in-archive'},
              createdAt: DateTime.utc(2026),
              updatedAt: DateTime.utc(2026),
            ),
          ],
      loadAttachment: loader,
    );
    await c.close();
    await done;
    return b.takeBytes();
  }

  test('password archive round trip with attachment, and plaintext never appears', () async {
    final codec = ArchiveCodec(crypto);
    final kdf = KdfParams.fromPreset(KdfPreset.standard, crypto.randomBytes(16));
    final key = await crypto.deriveMasterKey('export password', kdf);
    final att = AttachmentMeta(
      id: 'a1',
      fileName: 'id.png',
      mimeType: 'image/png',
      size: 150000,
      createdAt: DateTime.utc(2026),
      wrappedFileKey: '',
      cipherSha256: '',
      encryptedSize: 0,
    );
    final blob = Uint8List.fromList(List.generate(150000, (i) => i % 256));
    final items = [
      VaultItem(
        id: 'i',
        type: ItemType.secureNote,
        name: 'Docs',
        attachments: [att],
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    ];
    final data = await write(
      codec,
      ArchiveHeader(mode: ArchiveMode.password, createdAt: DateTime.utc(2026), purpose: 'export', kdf: kdf),
      key,
      items: items,
      loader: (_) async => Uint8List.fromList(blob),
    );
    expect(String.fromCharCodes(data).contains('Docs'), isFalse);
    final (header, _, _) = ArchiveCodec.readHeader(data);
    final key2 = await crypto.deriveMasterKey('export password', header.kdf!);
    final out = await codec.read(data, key2);
    expect(out.items.single.name, 'Docs');
    expect(out.attachments['a1'], blob);
    final wrong = await crypto.deriveMasterKey('wrong password', header.kdf!);
    await expectLater(codec.read(data, wrong), throwsA(isA<DecryptionFailedException>()));
  });

  test('header tampering and truncation are detected', () async {
    final codec = ArchiveCodec(crypto);
    final key = crypto.randomKey();
    final data = await write(
      codec,
      ArchiveHeader(mode: ArchiveMode.vault, createdAt: DateTime.utc(2026), purpose: 'manual', vaultId: 'v'),
      key,
    );
    // Flip a byte inside the header JSON (purpose "manual" -> "Manual").
    final tampered = Uint8List.fromList(data);
    final idx = String.fromCharCodes(tampered).indexOf('manual');
    tampered[idx] = 'M'.codeUnitAt(0);
    await expectLater(codec.read(tampered, key), throwsA(isA<DecryptionFailedException>()));
    final truncated = Uint8List.sublistView(data, 0, data.length - 20);
    await expectLater(codec.read(truncated, key), throwsA(isA<DecryptionFailedException>()));
    expect(() => ArchiveCodec.readHeader(Uint8List.fromList([1, 2, 3])), throwsA(isA<CryptoFormatException>()));
  });
}
