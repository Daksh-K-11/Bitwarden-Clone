import 'dart:typed_data';

import '../../../core/crypto/aad.dart';
import '../../../core/crypto/crypto_exceptions.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/crypto/enc_blob.dart';
import '../../../core/crypto/key_hierarchy.dart';
import '../../../core/db/database.dart';
import '../domain/vault_models.dart';

/// Converts domain models <-> encrypted record payloads.
///
/// Payload plaintext is `{"v": 1, "d": <model json>}`; the ciphertext is
/// bound to (vaultId, kind, recordId) through the AAD, and the decrypted id is
/// re-checked against the record id as defence in depth.
class RecordCodec {
  RecordCodec(this.crypto);

  final CryptoService crypto;

  static const int payloadVersion = 1;

  Uint8List encrypt(VaultKeys keys, RecordKind kind, String id, Map<String, dynamic> json) {
    if (json['id'] != id) throw ArgumentError('Record id mismatch');
    return crypto.sealJson(keys.recordKey, {
      'v': payloadVersion,
      'd': json,
    }, Aad.record(keys.vaultId, kind.name, id)).toBytes();
  }

  Map<String, dynamic> decrypt(VaultKeys keys, RecordKind kind, String id, Uint8List payload) {
    final blob = EncBlob.parse(payload);
    final env = crypto.openJson(keys.recordKey, blob, Aad.record(keys.vaultId, kind.name, id));
    final v = env['v'];
    if (v != payloadVersion) throw CryptoFormatException('Unsupported payload version $v');
    final data = (env['d'] as Map).cast<String, dynamic>();
    if (data['id'] != id) throw const DecryptionFailedException('Record id mismatch');
    return data;
  }

  Uint8List encryptItem(VaultKeys keys, VaultItem item) => encrypt(keys, RecordKind.item, item.id, item.toJson());
  Uint8List encryptFolder(VaultKeys keys, Folder folder) =>
      encrypt(keys, RecordKind.folder, folder.id, folder.toJson());
  Uint8List encryptTag(VaultKeys keys, Tag tag) => encrypt(keys, RecordKind.tag, tag.id, tag.toJson());

  VaultItem decryptItem(VaultKeys keys, String id, Uint8List payload) =>
      VaultItem.fromJson(decrypt(keys, RecordKind.item, id, payload));
  Folder decryptFolder(VaultKeys keys, String id, Uint8List payload) =>
      Folder.fromJson(decrypt(keys, RecordKind.folder, id, payload));
  Tag decryptTag(VaultKeys keys, String id, Uint8List payload) =>
      Tag.fromJson(decrypt(keys, RecordKind.tag, id, payload));

  /// Conflict copies use the dedicated conflict subkey.
  Uint8List encryptConflict(VaultKeys keys, String recordId, Uint8List recordPayload) =>
      crypto.seal(keys.conflictKey, recordPayload, Aad.conflict(keys.vaultId, recordId)).toBytes();

  Uint8List decryptConflict(VaultKeys keys, String recordId, Uint8List data) =>
      crypto.open(keys.conflictKey, EncBlob.parse(data), Aad.conflict(keys.vaultId, recordId));
}
