import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/crypto/kdf_params.dart';
import '../../core/crypto/key_hierarchy.dart';
import '../../core/db/database.dart';
import '../../core/storage/secure_store.dart';
import '../../core/util/log.dart';
import '../attachments/attachment_service.dart';
import '../backup/backup_service.dart';
import '../session/session_controller.dart';
import '../settings/settings_controller.dart';
import '../sync/sync_controller.dart';
import '../sync/sync_engine.dart';
import '../vault/application/vault_controller.dart';
import '../vault/domain/vault_models.dart';

final accountServiceProvider = Provider((ref) => AccountService(ref));

class AccountException implements Exception {
  const AccountException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Orchestrates account-level flows across session, cloud and storage.
class AccountService {
  AccountService(this.ref);
  final Ref ref;

  SessionController get _session => ref.read(sessionProvider.notifier);

  SessionUnlocked get _unlocked {
    final s = ref.read(sessionProvider);
    if (s is! SessionUnlocked) throw const AccountException('Unlock the vault first');
    return s;
  }

  // ------------------------------------------------------------ vault setup

  /// Creates a vault (offline or for the signed-in cloud account).
  Future<void> createVault(String masterPassword) async {
    final preset = ref.read(settingsProvider).kdfPreset;
    final material = await _session.createVault(masterPassword, preset: preset);
    final user = ref.read(authRepositoryProvider).currentUser;
    final remote = ref.read(remoteVaultStoreProvider);
    if (user != null && remote != null) {
      await remote.putKeyMaterial(user.uid, material);
      await ref.read(secureStoreProvider).write(SecureKeys.boundUid, user.uid);
      await registerDevice();
    }
  }

  /// New device: the cloud already holds this account's key material.
  Future<VaultKeyMaterial?> fetchRemoteMaterial() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final remote = ref.read(remoteVaultStoreProvider);
    if (user == null || remote == null) return null;
    return remote.fetchKeyMaterial(user.uid);
  }

  Future<void> unlockRemoteVault(VaultKeyMaterial material, String masterPassword) async {
    final user = ref.read(authRepositoryProvider).currentUser!;
    await _session.adoptRemoteVault(material, masterPassword);
    await ref.read(secureStoreProvider).write(SecureKeys.boundUid, user.uid);
    await ref.read(databaseProvider).deleteValue(SyncKeys.cursor); // full initial sync
    await registerDevice();
  }

  Future<void> registerDevice() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final remote = ref.read(remoteVaultStoreProvider);
    if (user == null || remote == null) return;
    final record = await ref.read(deviceIdentityProvider).describe(user.uid);
    await remote.upsertDevice(user.uid, record);
  }

  /// Uploads an existing offline vault to a (new, empty) cloud account.
  Future<void> connectLocalVaultToCloud() async {
    final s = _unlocked;
    final user = ref.read(authRepositoryProvider).currentUser;
    final remote = ref.read(remoteVaultStoreProvider);
    if (user == null || remote == null) throw const AccountException('Sign in first');
    final existing = await remote.fetchKeyMaterial(user.uid);
    if (existing != null && existing.vaultId != s.material.vaultId) {
      throw const AccountException(
        'This cloud account already has a different vault. Export this vault (encrypted), '
        'sign in on a fresh install, and import it there instead.',
      );
    }
    await remote.putKeyMaterial(user.uid, s.material);
    await ref.read(secureStoreProvider).write(SecureKeys.boundUid, user.uid);
    final db = ref.read(databaseProvider);
    await (db.update(
      db.vaultRecords,
    )..where((r) => r.revision.equals(0))).write(const VaultRecordsCompanion(dirty: Value(true)));
    await (db.update(db.localAttachments)..where((a) => a.syncState.equals(AttachmentSyncState.localOnly.index))).write(
      const LocalAttachmentsCompanion(syncState: Value(AttachmentSyncState.pendingUpload)),
    );
    await registerDevice();
    ref.invalidate(syncProvider);
  }

  // ------------------------------------------------------- password & keys

  /// Re-wraps the VEK under a new master password: no item re-encryption.
  Future<void> changeMasterPassword(String current, String next) async {
    final s = _unlocked;
    final hierarchy = ref.read(keyHierarchyProvider);
    // Verify the current password (throws on mismatch).
    (await hierarchy.unlock(s.material, current)).dispose();
    final material = await hierarchy.changeMasterPassword(
      current: s.material,
      unlocked: s.keys,
      newPassword: next,
      preset: ref.read(settingsProvider).kdfPreset,
    );
    final user = ref.read(authRepositoryProvider).currentUser;
    final remote = ref.read(remoteVaultStoreProvider);
    // Cloud first: if the upload fails we keep the old password everywhere.
    if (user != null && remote != null) await remote.putKeyMaterial(user.uid, material);
    await _session.replaceMaterial(material);
  }

  /// Generates a fresh VEK and re-encrypts every record + re-wraps every
  /// attachment key. Use if you believe the vault key was exposed.
  Future<void> rotateVaultKey(String masterPassword) async {
    final s = _unlocked;
    final backup = ref.read(backupServiceProvider);
    await backup.backupBeforeDestructive('key-rotation');
    final (material, newKeys) = await ref
        .read(keyHierarchyProvider)
        .rotateVaultKey(current: s.material, masterPassword: masterPassword);
    final vault = ref.read(vaultProvider);
    final attachments = ref.read(attachmentServiceProvider);
    final items = [
      for (final i in vault.items.values)
        i.copyWith(
          attachments: [for (final a in i.attachments) attachments.rewrap(a, s.keys, newKeys)],
          seq: i.seq + 1,
        ),
    ];
    await ref
        .read(vaultRepositoryProvider)
        .saveBatch(
          newKeys,
          items: items,
          folders: vault.folders.values,
          tags: vault.tags.values,
          keyGeneration: material.keyGeneration,
        );
    final user = ref.read(authRepositoryProvider).currentUser;
    final remote = ref.read(remoteVaultStoreProvider);
    if (user != null && remote != null) await remote.putKeyMaterial(user.uid, material);
    await ref.read(unlockServiceProvider).invalidateQuickUnlock();
    await _session.replaceMaterial(material, keys: newKeys);
    await ref.read(vaultProvider.notifier).reload();
  }

  // ------------------------------------------------------ logout & delete

  Future<int> unsyncedChanges() => ref.read(databaseProvider).dirtyCount();

  /// Signs out of the cloud and removes all local vault data.
  Future<void> logout() async {
    await ref.read(authRepositoryProvider).signOut();
    await _session.wipeLocal();
  }

  /// Permanently deletes the cloud account and all server-side data:
  /// R2 objects -> Firestore documents -> Firebase Auth user -> local data.
  /// Local backups / exports the user saved elsewhere cannot be reached.
  Future<void> deleteAccount({required String accountPassword}) async {
    final auth = ref.read(authRepositoryProvider);
    final user = auth.currentUser;
    if (user == null) {
      await _session.wipeLocal();
      return;
    }
    await auth.reauthenticate(accountPassword);
    final storage = ref.read(objectStorageProvider);
    if (storage.available) {
      await storage.deleteAll();
    }
    await ref.read(remoteVaultStoreProvider)?.deleteAllUserData(user.uid);
    await auth.deleteUser();
    await _session.wipeLocal();
    Log.d('account', 'Account deleted');
  }

  /// Resolves one sync conflict.
  Future<void> resolveConflict(SyncConflict c, ConflictChoice choice) async {
    final s = _unlocked;
    await SyncEngine.resolve(
      db: ref.read(databaseProvider),
      codec: ref.read(recordCodecProvider),
      keys: s.keys,
      conflict: c,
      choice: choice,
      saveItem: (VaultItem i) =>
          ref.read(vaultRepositoryProvider).saveItem(s.keys, i, keyGeneration: s.material.keyGeneration),
      newId: newId,
    );
    await ref.read(vaultProvider.notifier).reload();
  }

  KdfPreset get kdfPreset => ref.read(settingsProvider).kdfPreset;
}
