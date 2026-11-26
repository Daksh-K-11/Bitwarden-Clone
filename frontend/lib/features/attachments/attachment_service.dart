import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../../app/providers.dart';
import '../../core/cloud/cloud_interfaces.dart';
import '../../core/cloud/r2_object_storage.dart';
import '../../core/config/app_paths.dart';
import '../../core/crypto/aad.dart';
import '../../core/crypto/crypto_exceptions.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/crypto/enc_blob.dart';
import '../../core/crypto/key_hierarchy.dart';
import '../../core/db/database.dart';
import '../../core/util/log.dart';
import '../session/session_controller.dart';
import '../settings/settings_controller.dart';
import '../vault/application/vault_controller.dart';
import '../vault/domain/vault_models.dart';

class AttachmentException implements Exception {
  const AttachmentException(this.message);
  final String message;
  @override
  String toString() => message;
}

final attachmentServiceProvider = Provider(
  (ref) => AttachmentService(
    crypto: ref.watch(cryptoProvider),
    db: ref.watch(databaseProvider),
    paths: ref.watch(appPathsProvider),
    storage: ref.watch(objectStorageProvider),
    keys: () => ref.read(vaultKeysProvider),
    maxBytes: () => ref.read(settingsProvider).attachmentMaxMb * 1024 * 1024,
    cloudEnabled: () => ref.read(cloudUserProvider).value != null,
  ),
);

/// Encrypted attachments.
///
/// * Each file gets a random 256-bit file key; content is encrypted with
///   libsodium secretstream (XChaCha20-Poly1305, 64 KiB authenticated chunks,
///   final-chunk tag => truncation detected).
/// * The file key is wrapped with the attachment subkey (HKDF of the VEK) and
///   bound by AAD to (vaultId, attachmentId). Name, MIME type, size and the
///   wrapped key are stored only inside the encrypted item payload.
/// * Encrypted blobs live in the app sandbox (`attachments/<id>.bin`) and in
///   R2 at `users/{uid}/attachment/{id}`. The server sees opaque bytes.
/// * Plaintext is only ever held in memory for previews / saving. The SHA-256
///   of the ciphertext is verified before decryption.
class AttachmentService {
  AttachmentService({
    required this.crypto,
    required this.db,
    required this.paths,
    required this.storage,
    required this.keys,
    required this.maxBytes,
    required this.cloudEnabled,
  });

  final CryptoService crypto;
  final AppDatabase db;
  final AppPaths paths;
  final ObjectStorage storage;
  final VaultKeys? Function() keys;
  final int Function() maxBytes;
  final bool Function() cloudEnabled;

  VaultKeys get _keys => keys() ?? (throw const AttachmentException('Vault is locked'));

  File _blob(String id) => File(p.join(paths.attachments.path, '$id.bin'));

  /// Encrypts [bytes] and returns metadata to add to the item.
  Future<AttachmentMeta> add({required String itemId, required String fileName, required Uint8List bytes}) async {
    if (bytes.length > maxBytes()) {
      throw AttachmentException('File exceeds the ${maxBytes() ~/ (1024 * 1024)} MB attachment limit');
    }
    final k = _keys;
    final id = newId();
    final fileKey = crypto.randomKey();
    try {
      final cipher = await crypto.encryptBytes(bytes, fileKey);
      final blob = _blob(id);
      final tmp = File('${blob.path}.tmp');
      await tmp.writeAsBytes(cipher, flush: true);
      await tmp.rename(blob.path); // atomic: never a half-written blob
      final sha = CryptoService.sha256Hex(cipher);
      final wrapped = crypto.wrapKey(k.attachmentKey, fileKey, Aad.attachmentKey(k.vaultId, id));
      await db
          .into(db.localAttachments)
          .insert(
            LocalAttachmentsCompanion.insert(
              id: id,
              itemId: itemId,
              localPath: Value(blob.path),
              encryptedSize: cipher.length,
              cipherSha256: sha,
              syncState: cloudEnabled() ? AttachmentSyncState.pendingUpload : AttachmentSyncState.localOnly,
              createdAt: DateTime.now(),
            ),
          );
      return AttachmentMeta(
        id: id,
        fileName: p.basename(fileName),
        mimeType: lookupMimeType(fileName, headerBytes: bytes.take(32).toList()) ?? 'application/octet-stream',
        size: bytes.length,
        createdAt: DateTime.now().toUtc(),
        wrappedFileKey: wrapped.toBase64(),
        cipherSha256: sha,
        encryptedSize: cipher.length,
      );
    } finally {
      fileKey.dispose();
    }
  }

  /// Decrypts into memory. Downloads the blob first if needed.
  Future<Uint8List> open(AttachmentMeta meta, {void Function(int, int)? onProgress}) async {
    final k = _keys;
    final file = await _ensureLocal(meta, onProgress: onProgress);
    final cipher = await file.readAsBytes();
    if (CryptoService.sha256Hex(cipher) != meta.cipherSha256) {
      throw const AttachmentException('Attachment failed its integrity check and was not opened');
    }
    final fileKey = crypto.unwrapKey(
      k.attachmentKey,
      EncBlob.fromBase64(meta.wrappedFileKey),
      Aad.attachmentKey(k.vaultId, meta.id),
    );
    try {
      return await crypto.decryptBytes(cipher, fileKey);
    } on DecryptionFailedException catch (e) {
      throw AttachmentException(e.message);
    } finally {
      fileKey.dispose();
    }
  }

  Future<File> _ensureLocal(AttachmentMeta meta, {void Function(int, int)? onProgress}) async {
    final file = _blob(meta.id);
    if (await file.exists()) return file;
    if (!storage.available || !cloudEnabled()) {
      throw const AttachmentException('Attachment is not on this device and cloud storage is unavailable');
    }
    await storage.download(ObjectKind.attachment, meta.id, file, onProgress: onProgress);
    final row = await (db.select(db.localAttachments)..where((a) => a.id.equals(meta.id))).getSingleOrNull();
    if (row == null) {
      await db
          .into(db.localAttachments)
          .insert(
            LocalAttachmentsCompanion.insert(
              id: meta.id,
              itemId: '',
              localPath: Value(file.path),
              encryptedSize: meta.encryptedSize,
              cipherSha256: meta.cipherSha256,
              syncState: AttachmentSyncState.uploaded,
              createdAt: DateTime.now(),
            ),
          );
    }
    return file;
  }

  /// Removes the local blob and queues remote deletion.
  Future<void> delete(AttachmentMeta meta) async {
    final f = _blob(meta.id);
    if (await f.exists()) await f.delete();
    final row = await (db.select(db.localAttachments)..where((a) => a.id.equals(meta.id))).getSingleOrNull();
    final wasRemote = row == null || row.syncState == AttachmentSyncState.uploaded;
    if (wasRemote && cloudEnabled()) {
      await db
          .into(db.localAttachments)
          .insertOnConflictUpdate(
            LocalAttachmentsCompanion.insert(
              id: meta.id,
              itemId: row?.itemId ?? '',
              encryptedSize: meta.encryptedSize,
              cipherSha256: meta.cipherSha256,
              syncState: AttachmentSyncState.pendingDelete,
              createdAt: row?.createdAt ?? DateTime.now(),
            ),
          );
    } else {
      await (db.delete(db.localAttachments)..where((a) => a.id.equals(meta.id))).go();
    }
  }

  Future<void> deleteAllFor(VaultItem item) async {
    for (final a in item.attachments) {
      await delete(a);
    }
  }

  /// Uploads queued blobs and performs queued remote deletions.
  Future<void> syncPending() async {
    if (!storage.available || !cloudEnabled()) return;
    final rows =
        await (db.select(db.localAttachments)..where(
              (a) =>
                  a.syncState.isIn([AttachmentSyncState.pendingUpload.index, AttachmentSyncState.pendingDelete.index]),
            ))
            .get();
    for (final r in rows) {
      try {
        if (r.syncState == AttachmentSyncState.pendingDelete) {
          await storage.delete(ObjectKind.attachment, r.id);
          await (db.delete(db.localAttachments)..where((a) => a.id.equals(r.id))).go();
          continue;
        }
        final file = File(r.localPath ?? _blob(r.id).path);
        if (!await file.exists()) continue;
        final sha = await R2ObjectStorage.sha256OfFile(file);
        if (sha != r.cipherSha256) {
          Log.w('attach', 'Local blob ${r.id} corrupted; not uploading');
          continue;
        }
        await storage.upload(ObjectKind.attachment, r.id, file, sha256: sha);
        await (db.update(db.localAttachments)..where((a) => a.id.equals(r.id))).write(
          const LocalAttachmentsCompanion(syncState: Value(AttachmentSyncState.uploaded)),
        );
      } on ObjectStorageException catch (e) {
        await (db.update(db.localAttachments)..where((a) => a.id.equals(r.id))).write(
          LocalAttachmentsCompanion(uploadAttempts: Value(r.uploadAttempts + 1)),
        );
        if (!e.retryable) rethrow;
      }
    }
  }

  /// Re-wraps file keys after a vault-key rotation (file contents unchanged).
  AttachmentMeta rewrap(AttachmentMeta meta, VaultKeys oldKeys, VaultKeys newKeys) {
    final fileKey = crypto.unwrapKey(
      oldKeys.attachmentKey,
      EncBlob.fromBase64(meta.wrappedFileKey),
      Aad.attachmentKey(oldKeys.vaultId, meta.id),
    );
    try {
      return meta.copyWith(
        wrappedFileKey: crypto
            .wrapKey(newKeys.attachmentKey, fileKey, Aad.attachmentKey(newKeys.vaultId, meta.id))
            .toBase64(),
      );
    } finally {
      fileKey.dispose();
    }
  }
}
