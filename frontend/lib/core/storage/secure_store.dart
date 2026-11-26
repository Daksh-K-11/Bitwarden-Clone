import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keys stored in the OS keystore-backed secure storage.
///
/// Android: values are AES-GCM encrypted with a key wrapped by an
/// Android Keystore RSA key (hardware-backed where available).
/// iOS: Keychain, `first_unlock_this_device` (never synced to iCloud).
abstract final class SecureKeys {
  /// [VaultKeyMaterial] JSON (salt, KDF params, wrapped VEK). Not secret,
  /// but kept here rather than in the database so the lock screen works even
  /// if the database is damaged.
  static const vaultMaterial = 'vault.material.v1';

  /// Random 256-bit SQLCipher key for the local database (hex).
  static const databaseKey = 'db.key.v1';

  /// VEK wrapped by the biometric Keystore key: {iv, ct, allowCred}.
  static const biometricBlob = 'unlock.biometric.v1';

  /// VEK wrapped by an Argon2id(PIN) key: {salt, ops, mem, blob, fails}.
  static const pinBlob = 'unlock.pin.v1';

  /// Device identity {deviceId, sign keys, kx keys}.
  static const deviceIdentity = 'device.identity.v1';

  /// Failed master password attempts {count, lastAt}.
  static const unlockFailures = 'unlock.failures.v1';

  /// Firebase uid this vault is bound to (cloud mode).
  static const boundUid = 'cloud.uid.v1';
}

class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              // Never silently wipe storage on a keystore error: for a
              // vault this could destroy the only copy of the wrapped key.
              resetOnError: false,
              migrateOnAlgorithmChange: true,
            ),
            iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device, synchronizable: false),
          );

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<bool> contains(String key) => _storage.containsKey(key: key);

  /// Secure logout / vault deletion.
  Future<void> wipeAll() => _storage.deleteAll();
}
