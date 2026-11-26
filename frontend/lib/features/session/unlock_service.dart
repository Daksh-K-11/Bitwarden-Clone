import 'dart:convert';
import 'dart:math' as math;

import 'package:sodium/sodium_sumo.dart';

import '../../core/crypto/aad.dart';
import '../../core/crypto/crypto_exceptions.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/crypto/enc_blob.dart';
import '../../core/crypto/kdf_params.dart';
import '../../core/crypto/key_hierarchy.dart';
import '../../core/platform/platform_security.dart';
import '../../core/storage/secure_store.dart';

class UnlockThrottledException implements Exception {
  const UnlockThrottledException(this.retryAfter);
  final Duration retryAfter;
  @override
  String toString() => 'Too many attempts. Try again in ${retryAfter.inSeconds}s.';
}

class PinDisabledException implements Exception {
  const PinDisabledException();
  @override
  String toString() => 'PIN unlock disabled after too many failed attempts. Use your master password.';
}

class UnlockOptions {
  const UnlockOptions({required this.biometric, required this.pin, this.biometricWithDeviceCredential = false});
  static const none = UnlockOptions(biometric: false, pin: false);
  final bool biometric;
  final bool biometricWithDeviceCredential;
  final bool pin;
}

/// All the ways to recover the VEK on this device.
///
/// * Master password - Argon2id -> KEK -> unwrap VEK. Always available.
/// * Biometric / device credential - VEK wrapped by an AES key that lives in
///   the Android Keystore and is only usable inside a successful
///   BiometricPrompt (see SecurityChannel.kt). Biometrics release a key; they
///   never replace the cryptography.
/// * App PIN - VEK wrapped by Argon2id(PIN, device salt). Device-local only,
///   stored in Keystore-backed secure storage, and wiped after
///   [maxPinAttempts] failures so the low-entropy PIN cannot be guessed
///   indefinitely through the UI.
class UnlockService {
  UnlockService({required this.crypto, required this.hierarchy, required this.store, required this.platform});

  final CryptoService crypto;
  final KeyHierarchy hierarchy;
  final SecureStore store;
  final PlatformSecurity platform;

  static const maxPinAttempts = 5;
  static const _freeAttempts = 5;

  // ---------------------------------------------------------- key material

  Future<VaultKeyMaterial?> loadMaterial() async {
    final raw = await store.read(SecureKeys.vaultMaterial);
    return raw == null ? null : VaultKeyMaterial.decode(raw);
  }

  Future<void> saveMaterial(VaultKeyMaterial m) => store.write(SecureKeys.vaultMaterial, m.encode());

  Future<UnlockOptions> options() async {
    final bio = await store.read(SecureKeys.biometricBlob);
    var withCred = false;
    if (bio != null) {
      try {
        withCred = (jsonDecode(bio) as Map)['allowCred'] == true;
      } catch (_) {}
    }
    return UnlockOptions(
      biometric: bio != null,
      biometricWithDeviceCredential: withCred,
      pin: await store.contains(SecureKeys.pinBlob),
    );
  }

  // ------------------------------------------------------ master password

  /// Exponential back-off after [_freeAttempts] failures (persists across
  /// restarts). Argon2id already makes each guess expensive.
  Future<Duration?> throttleRemaining() async {
    final raw = await store.read(SecureKeys.unlockFailures);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final count = j['count'] as int;
    if (count < _freeAttempts) return null;
    final last = DateTime.parse(j['lastAt'] as String);
    final wait = Duration(seconds: (15 * math.pow(2, count - _freeAttempts)).clamp(15, 3600).toInt());
    final remaining = last.add(wait).difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }

  Future<void> _recordFailure() async {
    final raw = await store.read(SecureKeys.unlockFailures);
    final count = raw == null ? 0 : (jsonDecode(raw) as Map)['count'] as int;
    await store.write(
      SecureKeys.unlockFailures,
      jsonEncode({'count': count + 1, 'lastAt': DateTime.now().toIso8601String()}),
    );
  }

  Future<int> failureCount() async {
    final raw = await store.read(SecureKeys.unlockFailures);
    return raw == null ? 0 : (jsonDecode(raw) as Map)['count'] as int;
  }

  Future<void> _clearFailures() => store.delete(SecureKeys.unlockFailures);

  Future<VaultKeys> unlockWithPassword(VaultKeyMaterial material, String password) async {
    final wait = await throttleRemaining();
    if (wait != null) throw UnlockThrottledException(wait);
    try {
      final keys = await hierarchy.unlock(material, password);
      await _clearFailures();
      return keys;
    } on DecryptionFailedException {
      await _recordFailure();
      rethrow;
    }
  }

  // ------------------------------------------------------------ biometrics

  Future<void> enableBiometric(VaultKeys keys, {required bool allowDeviceCredential}) async {
    final vek = keys.vek.extractBytes();
    try {
      final (iv, ct) = await platform.biometricEncrypt(
        vek,
        title: 'Enable biometric unlock',
        subtitle: 'Confirm to protect your vault key with this device',
        allowDeviceCredential: allowDeviceCredential,
      );
      await store.write(
        SecureKeys.biometricBlob,
        jsonEncode({'iv': base64.encode(iv), 'ct': base64.encode(ct), 'allowCred': allowDeviceCredential}),
      );
    } finally {
      vek.fillRange(0, vek.length, 0);
    }
  }

  Future<void> disableBiometric() async {
    await store.delete(SecureKeys.biometricBlob);
    await platform.biometricDeleteKey();
  }

  Future<VaultKeys> unlockWithBiometric(VaultKeyMaterial material) async {
    final raw = await store.read(SecureKeys.biometricBlob);
    if (raw == null) throw const BiometricException(BiometricErrorCode.noKey);
    final j = jsonDecode(raw) as Map<String, dynamic>;
    try {
      final vek = await platform.biometricDecrypt(
        base64.decode(j['iv'] as String),
        base64.decode(j['ct'] as String),
        title: 'Unlock Citadel',
        allowDeviceCredential: j['allowCred'] == true,
      );
      try {
        if (vek.length != CryptoService.keyLength) throw const CryptoFormatException('Bad key');
        await _clearFailures();
        return VaultKeys.fromVek(crypto, material.vaultId, crypto.keyFromBytes(vek));
      } finally {
        vek.fillRange(0, vek.length, 0);
      }
    } on BiometricException catch (e) {
      if (e.code == BiometricErrorCode.invalidated || e.code == BiometricErrorCode.noKey) {
        await store.delete(SecureKeys.biometricBlob);
      }
      rethrow;
    }
  }

  // ------------------------------------------------------------------ PIN

  Future<SecureKey> _pinKey(String pin, KdfParams kdf) async {
    final mk = await crypto.deriveMasterKey(pin, kdf);
    try {
      return crypto.hkdf(mk, KeyContexts.pin);
    } finally {
      mk.dispose();
    }
  }

  Future<void> enablePin(VaultKeys keys, String pin) async {
    if (!RegExp(r'^\d{4,12}$').hasMatch(pin)) throw ArgumentError('PIN must be 4-12 digits');
    final kdf = KdfParams.fromPreset(KdfPreset.standard, crypto.randomBytes(KdfParams.saltLength));
    final pinKey = await _pinKey(pin, kdf);
    try {
      final blob = crypto.wrapKey(pinKey, keys.vek, Aad.pinWrap(keys.vaultId));
      await store.write(SecureKeys.pinBlob, jsonEncode({'kdf': kdf.toJson(), 'blob': blob.toBase64(), 'fails': 0}));
    } finally {
      pinKey.dispose();
    }
  }

  Future<void> disablePin() => store.delete(SecureKeys.pinBlob);

  Future<VaultKeys> unlockWithPin(VaultKeyMaterial material, String pin) async {
    final raw = await store.read(SecureKeys.pinBlob);
    if (raw == null) throw const PinDisabledException();
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final kdf = KdfParams.fromJson((j['kdf'] as Map).cast<String, dynamic>());
    final pinKey = await _pinKey(pin, kdf);
    try {
      final vek = crypto.unwrapKey(pinKey, EncBlob.fromBase64(j['blob'] as String), Aad.pinWrap(material.vaultId));
      if ((j['fails'] as int) != 0) await store.write(SecureKeys.pinBlob, jsonEncode({...j, 'fails': 0}));
      return VaultKeys.fromVek(crypto, material.vaultId, vek);
    } on DecryptionFailedException {
      final fails = (j['fails'] as int) + 1;
      if (fails >= maxPinAttempts) {
        await disablePin();
        throw const PinDisabledException();
      }
      await store.write(SecureKeys.pinBlob, jsonEncode({...j, 'fails': fails}));
      rethrow;
    } finally {
      pinKey.dispose();
    }
  }

  /// After a VEK rotation both wrapped copies are stale.
  Future<void> invalidateQuickUnlock() async {
    await disablePin();
    await disableBiometric();
  }
}
