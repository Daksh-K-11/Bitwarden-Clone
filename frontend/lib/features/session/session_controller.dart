import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../core/crypto/kdf_params.dart';
import '../../core/crypto/key_hierarchy.dart';
import '../../core/storage/secure_store.dart';
import '../../core/util/log.dart';
import 'unlock_service.dart';

sealed class SessionState {
  const SessionState();
}

class SessionLoading extends SessionState {
  const SessionLoading();
}

/// No vault on this device yet (onboarding).
class SessionNoVault extends SessionState {
  const SessionNoVault();
}

class SessionLocked extends SessionState {
  const SessionLocked(this.material, this.options, {this.reason});
  final VaultKeyMaterial material;
  final UnlockOptions options;

  /// Why we locked (shown on the lock screen), e.g. "Vault key rotated".
  final String? reason;
}

class SessionUnlocked extends SessionState {
  const SessionUnlocked(this.keys, this.material);
  final VaultKeys keys;
  final VaultKeyMaterial material;
}

final unlockServiceProvider = Provider(
  (ref) => UnlockService(
    crypto: ref.watch(cryptoProvider),
    hierarchy: ref.watch(keyHierarchyProvider),
    store: ref.watch(secureStoreProvider),
    platform: ref.watch(platformSecurityProvider),
  ),
);

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Convenience: current keys or null.
final vaultKeysProvider = Provider<VaultKeys?>((ref) {
  final s = ref.watch(sessionProvider);
  return s is SessionUnlocked ? s.keys : null;
});

/// Callbacks run on every lock (clipboard, temp files, caches...).
final lockHooksProvider = Provider<List<FutureOr<void> Function()>>((_) => []);

class SessionController extends Notifier<SessionState> {
  UnlockService get _unlock => ref.read(unlockServiceProvider);

  @override
  SessionState build() {
    Future.microtask(_init);
    return const SessionLoading();
  }

  Future<void> _init() async {
    final material = await _unlock.loadMaterial();
    if (material == null) {
      state = const SessionNoVault();
    } else {
      state = SessionLocked(material, await _unlock.options());
    }
  }

  Future<void> refreshLocked({String? reason}) async {
    final material = await _unlock.loadMaterial();
    state = material == null
        ? const SessionNoVault()
        : SessionLocked(material, await _unlock.options(), reason: reason);
  }

  /// Creates a new vault protected by [masterPassword].
  Future<VaultKeyMaterial> createVault(String masterPassword, {KdfPreset preset = KdfPreset.standard}) async {
    final (material, keys) = await ref
        .read(keyHierarchyProvider)
        .createVault(vaultId: const Uuid().v4(), masterPassword: masterPassword, preset: preset);
    await _unlock.saveMaterial(material);
    state = SessionUnlocked(keys, material);
    return material;
  }

  /// Adopts key material downloaded from the cloud (new device sign-in).
  Future<void> adoptRemoteVault(VaultKeyMaterial material, String masterPassword) async {
    final keys = await _unlock.unlockWithPassword(material, masterPassword);
    await _unlock.saveMaterial(material);
    state = SessionUnlocked(keys, material);
  }

  Future<void> unlockWithPassword(String password) async {
    final s = state;
    if (s is! SessionLocked) return;
    final keys = await _unlock.unlockWithPassword(s.material, password);
    state = SessionUnlocked(keys, s.material);
  }

  Future<void> unlockWithBiometric() async {
    final s = state;
    if (s is! SessionLocked) return;
    try {
      final keys = await _unlock.unlockWithBiometric(s.material);
      state = SessionUnlocked(keys, s.material);
    } finally {
      if (state is SessionLocked) await refreshLocked();
    }
  }

  Future<void> unlockWithPin(String pin) async {
    final s = state;
    if (s is! SessionLocked) return;
    try {
      final keys = await _unlock.unlockWithPin(s.material, pin);
      state = SessionUnlocked(keys, s.material);
    } on PinDisabledException {
      await refreshLocked(reason: 'PIN unlock was disabled after too many attempts.');
      rethrow;
    }
  }

  /// Locks: disposes (zeroes) all keys and runs lock hooks.
  Future<void> lock({String? reason}) async {
    final s = state;
    if (s is! SessionUnlocked) return;
    state = SessionLocked(s.material, await _unlock.options(), reason: reason);
    for (final hook in ref.read(lockHooksProvider)) {
      try {
        await hook();
      } catch (e) {
        Log.w('session', 'Lock hook failed (${e.runtimeType})');
      }
    }
    // Dispose after UI has dropped references to decrypted data.
    scheduleMicrotask(s.keys.dispose);
  }

  /// Replaces the stored key material (master password changed / rotated).
  Future<void> replaceMaterial(VaultKeyMaterial material, {VaultKeys? keys}) async {
    await _unlock.saveMaterial(material);
    final s = state;
    if (s is SessionUnlocked) {
      if (keys != null && !identical(keys, s.keys)) {
        final old = s.keys;
        state = SessionUnlocked(keys, material);
        scheduleMicrotask(old.dispose);
      } else {
        state = SessionUnlocked(s.keys, material);
      }
    } else if (s is SessionLocked) {
      state = SessionLocked(material, s.options, reason: s.reason);
    }
  }

  /// Removes every local trace of the vault (secure logout / delete).
  Future<void> wipeLocal() async {
    final s = state;
    for (final hook in ref.read(lockHooksProvider)) {
      try {
        await hook();
      } catch (_) {}
    }
    await ref.read(databaseProvider).wipe();
    final store = ref.read(secureStoreProvider);
    await ref.read(platformSecurityProvider).biometricDeleteKey();
    // Keep the database key: the (now empty) DB stays encrypted with it.
    for (final k in [
      SecureKeys.vaultMaterial,
      SecureKeys.biometricBlob,
      SecureKeys.pinBlob,
      SecureKeys.unlockFailures,
      SecureKeys.boundUid,
      SecureKeys.deviceIdentity,
    ]) {
      await store.delete(k);
    }
    final paths = ref.read(appPathsProvider);
    for (final dir in [paths.attachments, paths.backups]) {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create(recursive: true);
      }
    }
    await paths.wipePreviews();
    state = const SessionNoVault();
    if (s is SessionUnlocked) scheduleMicrotask(s.keys.dispose);
  }
}
