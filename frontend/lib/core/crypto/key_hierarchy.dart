import 'dart:convert';

import 'package:sodium/sodium_sumo.dart';

import 'aad.dart';
import 'crypto_service.dart';
import 'enc_blob.dart';
import 'kdf_params.dart';

/// Key hierarchy
/// =============
/// ```
///  master password ──Argon2id(salt, ops, mem)──▶ MK (32 B, never stored)
///                                               │
///                                 HKDF-SHA256 "citadel/v1/kek"
///                                               ▼
///                                          KEK (32 B, never stored)
///                                               │ XChaCha20-Poly1305 wrap
///                                               ▼
///  CSPRNG ───────────────────────────────▶  VEK (32 B)  ◀── stored only wrapped
///                                               │
///             ┌──────────────┬──────────────────┼──────────────────┐
///      HKDF "records"  HKDF "attachments"   HKDF "backup"     HKDF "conflicts"
///             ▼              ▼                  ▼                  ▼
///        record key   attachment wrap key   backup key       conflict key
/// ```
/// * Changing the master password re-derives MK/KEK and re-wraps the *same*
///   VEK: O(1), no vault re-encryption.
/// * Rotating the VEK (suspected compromise) re-encrypts every record and
///   re-wraps every attachment file key: O(n), see [VaultKeyMaterial].
/// * Each subkey is independent; compromise of one does not reveal others.
abstract final class KeyContexts {
  static const String kek = 'citadel/v1/kek';
  static const String records = 'citadel/v1/records';
  static const String attachments = 'citadel/v1/attachments';
  static const String backup = 'citadel/v1/backup';
  static const String conflicts = 'citadel/v1/conflicts';
  static const String pin = 'citadel/v1/pin';
}

/// Everything needed to unlock a vault with the master password. Safe to
/// store on device and on the server: contains no secret in the clear.
class VaultKeyMaterial {
  VaultKeyMaterial({
    required this.vaultId,
    required this.kdf,
    required this.wrappedVek,
    required this.cryptoVersion,
    required this.keyGeneration,
    required this.updatedAt,
  });

  static const int currentCryptoVersion = 1;

  final String vaultId;
  final KdfParams kdf;
  final EncBlob wrappedVek;
  final int cryptoVersion;

  /// Incremented on every VEK rotation. Devices that see a higher generation
  /// on the server must re-download and re-decrypt.
  final int keyGeneration;
  final DateTime updatedAt;

  Map<String, Object> toJson() => {
    'vaultId': vaultId,
    'kdf': kdf.toJson(),
    'wrappedVek': wrappedVek.toBase64(),
    'cryptoVersion': cryptoVersion,
    'keyGeneration': keyGeneration,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  factory VaultKeyMaterial.fromJson(Map<String, dynamic> json) => VaultKeyMaterial(
    vaultId: json['vaultId'] as String,
    kdf: KdfParams.fromJson((json['kdf'] as Map).cast<String, dynamic>()),
    wrappedVek: EncBlob.fromBase64(json['wrappedVek'] as String),
    cryptoVersion: json['cryptoVersion'] as int,
    keyGeneration: (json['keyGeneration'] as int?) ?? 1,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  String encode() => jsonEncode(toJson());
  static VaultKeyMaterial decode(String s) => VaultKeyMaterial.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// Unlocked key set held in memory only while the vault is unlocked.
class VaultKeys {
  VaultKeys._({
    required this.vaultId,
    required this.vek,
    required this.recordKey,
    required this.attachmentKey,
    required this.backupKey,
    required this.conflictKey,
  });

  factory VaultKeys.fromVek(CryptoService crypto, String vaultId, SecureKey vek) => VaultKeys._(
    vaultId: vaultId,
    vek: vek,
    recordKey: crypto.hkdf(vek, KeyContexts.records),
    attachmentKey: crypto.hkdf(vek, KeyContexts.attachments),
    backupKey: crypto.hkdf(vek, KeyContexts.backup),
    conflictKey: crypto.hkdf(vek, KeyContexts.conflicts),
  );

  final String vaultId;
  final SecureKey vek;
  final SecureKey recordKey;
  final SecureKey attachmentKey;
  final SecureKey backupKey;
  final SecureKey conflictKey;

  bool _disposed = false;
  bool get isDisposed => _disposed;

  /// Zeroes and frees all key memory (sodium_free).
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final k in [recordKey, attachmentKey, backupKey, conflictKey, vek]) {
      k.dispose();
    }
  }
}

/// Pure key-hierarchy operations (no I/O).
class KeyHierarchy {
  KeyHierarchy(this.crypto);
  final CryptoService crypto;

  Future<SecureKey> _deriveKek(String password, KdfParams kdf) async {
    final mk = await crypto.deriveMasterKey(password, kdf);
    try {
      return crypto.hkdf(mk, KeyContexts.kek);
    } finally {
      mk.dispose();
    }
  }

  /// Creates a brand new vault: random VEK, random salt, wrapped VEK.
  Future<(VaultKeyMaterial, VaultKeys)> createVault({
    required String vaultId,
    required String masterPassword,
    KdfPreset preset = KdfPreset.standard,
  }) async {
    final kdf = KdfParams.fromPreset(preset, crypto.randomBytes(KdfParams.saltLength));
    final kek = await _deriveKek(masterPassword, kdf);
    final vek = crypto.randomKey();
    try {
      final wrapped = crypto.wrapKey(kek, vek, Aad.vekWrap(vaultId));
      final material = VaultKeyMaterial(
        vaultId: vaultId,
        kdf: kdf,
        wrappedVek: wrapped,
        cryptoVersion: VaultKeyMaterial.currentCryptoVersion,
        keyGeneration: 1,
        updatedAt: DateTime.now().toUtc(),
      );
      return (material, VaultKeys.fromVek(crypto, vaultId, vek));
    } finally {
      kek.dispose();
    }
  }

  /// Throws [DecryptionFailedException] on a wrong password (or tampered
  /// material - indistinguishable by design).
  Future<VaultKeys> unlock(VaultKeyMaterial material, String masterPassword) async {
    final kek = await _deriveKek(masterPassword, material.kdf);
    try {
      final vek = crypto.unwrapKey(kek, material.wrappedVek, Aad.vekWrap(material.vaultId));
      return VaultKeys.fromVek(crypto, material.vaultId, vek);
    } finally {
      kek.dispose();
    }
  }

  /// Re-wraps the existing VEK under a new password (and new salt).
  Future<VaultKeyMaterial> changeMasterPassword({
    required VaultKeyMaterial current,
    required VaultKeys unlocked,
    required String newPassword,
    KdfPreset? preset,
  }) async {
    final kdf = KdfParams(
      algorithm: KdfParams.argon2id13,
      opsLimit: preset?.opsLimit ?? current.kdf.opsLimit,
      memLimitKiB: preset?.memLimitKiB ?? current.kdf.memLimitKiB,
      salt: crypto.randomBytes(KdfParams.saltLength),
    );
    final kek = await _deriveKek(newPassword, kdf);
    try {
      return VaultKeyMaterial(
        vaultId: current.vaultId,
        kdf: kdf,
        wrappedVek: crypto.wrapKey(kek, unlocked.vek, Aad.vekWrap(current.vaultId)),
        cryptoVersion: VaultKeyMaterial.currentCryptoVersion,
        keyGeneration: current.keyGeneration,
        updatedAt: DateTime.now().toUtc(),
      );
    } finally {
      kek.dispose();
    }
  }

  /// Generates a new VEK wrapped under the same password. Caller must
  /// re-encrypt all records with the returned keys.
  Future<(VaultKeyMaterial, VaultKeys)> rotateVaultKey({
    required VaultKeyMaterial current,
    required String masterPassword,
  }) async {
    final kek = await _deriveKek(masterPassword, current.kdf);
    final vek = crypto.randomKey();
    try {
      // Prove the password is right before rotating.
      crypto.unwrapKey(kek, current.wrappedVek, Aad.vekWrap(current.vaultId)).dispose();
      final material = VaultKeyMaterial(
        vaultId: current.vaultId,
        kdf: current.kdf,
        wrappedVek: crypto.wrapKey(kek, vek, Aad.vekWrap(current.vaultId)),
        cryptoVersion: VaultKeyMaterial.currentCryptoVersion,
        keyGeneration: current.keyGeneration + 1,
        updatedAt: DateTime.now().toUtc(),
      );
      return (material, VaultKeys.fromVek(crypto, current.vaultId, vek));
    } finally {
      kek.dispose();
    }
  }
}
