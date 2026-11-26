import 'dart:convert';
import 'dart:typed_data';

/// Authenticated additional data (AAD) builders.
///
/// Every ciphertext is bound to *what it is* and *where it belongs*. Because the
/// AAD contains the vault id, record kind and record id, a malicious server or
/// a corrupted database cannot:
///  * move an item's ciphertext onto another item id (substitution),
///  * replay a folder ciphertext as an item,
///  * transplant ciphertext between two users' vaults,
/// without the Poly1305 tag failing.
///
/// The vault id (random UUID created with the vault) is used instead of a
/// Firebase uid so the encryption layer is independent of the backend.
abstract final class Aad {
  static const String _prefix = 'citadel:v1';

  static Uint8List _of(List<String> parts) => Uint8List.fromList(utf8.encode([_prefix, ...parts].join('|')));

  /// Vault key wrapped by the master-password derived KEK.
  static Uint8List vekWrap(String vaultId) => _of(['vek-wrap', vaultId]);

  /// Vault key wrapped by an app-PIN derived key (device-local).
  static Uint8List pinWrap(String vaultId) => _of(['pin-wrap', vaultId]);

  /// Vault records (items, folders, tags).
  static Uint8List record(String vaultId, String kind, String recordId) => _of(['record', kind, vaultId, recordId]);

  /// Per-attachment file key wrapped by the attachment key.
  static Uint8List attachmentKey(String vaultId, String attachmentId) => _of(['attachment-key', vaultId, attachmentId]);

  /// Locally stored conflicting copies.
  static Uint8List conflict(String vaultId, String recordId) => _of(['conflict', vaultId, recordId]);

  /// Device identity secret keys at rest.
  static Uint8List deviceIdentity(String deviceId) => _of(['device-identity', deviceId]);
}
