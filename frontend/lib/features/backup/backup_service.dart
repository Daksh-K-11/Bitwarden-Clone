import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:sodium/sodium_sumo.dart';

import '../../app/providers.dart';
import '../../core/cloud/cloud_interfaces.dart';
import '../../core/cloud/r2_object_storage.dart';
import '../../core/crypto/kdf_params.dart';
import '../../core/crypto/key_hierarchy.dart';
import '../../core/util/log.dart';
import '../attachments/attachment_service.dart';
import '../session/session_controller.dart';
import '../settings/settings_controller.dart';
import '../vault/application/vault_controller.dart';
import '../vault/domain/item_type.dart';
import '../vault/domain/vault_models.dart';
import 'backup_format.dart';

class BackupFileInfo {
  const BackupFileInfo(this.file, this.size, this.modified);
  final File file;
  final int size;
  final DateTime modified;
  String get name => p.basename(file.path);
}

class BackupVerification {
  const BackupVerification({
    required this.header,
    required this.items,
    required this.folders,
    required this.tags,
    required this.attachments,
    required this.missingAttachments,
  });
  final ArchiveHeader header;
  final int items;
  final int folders;
  final int tags;
  final int attachments;
  final int missingAttachments;
}

class PasswordRequiredException implements Exception {
  const PasswordRequiredException(this.header);
  final ArchiveHeader header;
  @override
  String toString() => header.mode == ArchiveMode.password
      ? 'Enter the export password for this archive.'
      : 'This backup was made with a different vault key. Enter the master password you used at that time.';
}

/// What to include in an export.
class ExportSelection {
  const ExportSelection({this.itemIds, this.folderIds, this.types, this.includeTrash = false});
  const ExportSelection.all() : itemIds = null, folderIds = null, types = null, includeTrash = false;
  final Set<String>? itemIds;
  final Set<String>? folderIds;
  final Set<ItemType>? types;
  final bool includeTrash;

  List<VaultItem> apply(Iterable<VaultItem> items) => items.where((i) {
    if (!includeTrash && i.isTrashed) return false;
    if (itemIds != null && !itemIds!.contains(i.id)) return false;
    if (folderIds != null && !folderIds!.contains(i.folderId)) return false;
    if (types != null && !types!.contains(i.type)) return false;
    return true;
  }).toList();
}

final backupServiceProvider = Provider((ref) => BackupService(ref));

/// Encrypted backups (independent of cloud replication - a replica that
/// faithfully syncs a mass deletion is not a backup).
class BackupService {
  BackupService(this.ref);
  final Ref ref;

  static const lastAutoKey = 'backup.lastAuto';

  ArchiveCodec get _codec => ArchiveCodec(ref.read(cryptoProvider));

  SessionUnlocked get _session {
    final s = ref.read(sessionProvider);
    if (s is! SessionUnlocked) throw StateError('Vault is locked');
    return s;
  }

  Directory get _dir => ref.read(appPathsProvider).backups;

  Future<List<BackupFileInfo>> listLocal() async {
    if (!await _dir.exists()) return [];
    final files = <BackupFileInfo>[];
    await for (final e in _dir.list()) {
      if (e is File && e.path.endsWith('.citadel')) {
        final st = await e.stat();
        files.add(BackupFileInfo(e, st.size, st.modified));
      }
    }
    files.sort((a, b) => b.modified.compareTo(a.modified));
    return files;
  }

  Future<Uint8List?> _loadAttachment(AttachmentMeta m) async {
    try {
      return await ref.read(attachmentServiceProvider).open(m);
    } catch (e) {
      Log.w('backup', 'Attachment ${m.id} unavailable (${e.runtimeType})');
      return null;
    }
  }

  /// Writes a vault-key archive directly to a file in the app sandbox (the
  /// file is ciphertext from its first byte; written to .part then renamed).
  Future<File> createLocalBackup({String purpose = 'manual'}) async {
    final s = _session;
    final vault = ref.read(vaultProvider);
    final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
    final file = File(p.join(_dir.path, 'citadel-$stamp-$purpose.citadel'));
    final part = File('${file.path}.part');
    final sink = part.openWrite();
    try {
      await _codec.write(
        sink: sink,
        header: ArchiveHeader(
          mode: ArchiveMode.vault,
          createdAt: DateTime.now().toUtc(),
          purpose: purpose,
          vaultId: s.material.vaultId,
          keyGeneration: s.material.keyGeneration,
          material: s.material.toJson(),
        ),
        baseKey: s.keys.backupKey,
        folders: vault.folders.values.toList(),
        tags: vault.tags.values.toList(),
        items: vault.items.values.toList(),
        loadAttachment: _loadAttachment,
      );
      await sink.flush();
      await sink.close();
      await part.rename(file.path);
    } catch (_) {
      await sink.close();
      if (await part.exists()) await part.delete();
      rethrow;
    }
    await _prune();
    return file;
  }

  Future<void> _prune() async {
    final keep = ref.read(settingsProvider).autoBackupKeep;
    final autos = (await listLocal()).where((b) => b.name.contains('-auto')).toList();
    for (final b in autos.skip(keep)) {
      await b.file.delete();
    }
  }

  /// Daily automatic backup on unlock.
  Future<void> maybeAutoBackup() async {
    if (!ref.read(settingsProvider).autoBackupEnabled) return;
    final db = ref.read(databaseProvider);
    final last = DateTime.tryParse(await db.getValue(lastAutoKey) ?? '');
    if (last != null && DateTime.now().difference(last) < const Duration(hours: 24)) return;
    if (ref.read(vaultProvider).items.isEmpty) return;
    await createLocalBackup(purpose: 'auto');
    await db.setValue(lastAutoKey, DateTime.now().toIso8601String());
  }

  /// Safety net before destructive operations (restore, empty trash,
  /// import-replace, key rotation, folder deletion).
  Future<void> backupBeforeDestructive(String what) async {
    if (ref.read(vaultProvider).items.isEmpty) return;
    try {
      await createLocalBackup(purpose: 'pre-$what');
    } catch (e) {
      Log.e('backup', 'Pre-$what backup failed', e);
      rethrow; // do not proceed with the destructive action
    }
  }

  /// Encrypted, password-protected export (portable archive).
  Future<Uint8List> exportEncrypted(String password, ExportSelection selection) async {
    if (password.length < 8) throw ArgumentError('Use an export password of at least 8 characters');
    final crypto = ref.read(cryptoProvider);
    final vault = ref.read(vaultProvider);
    final items = selection.apply(vault.items.values);
    final folderIds = items.map((i) => i.folderId).whereType<String>().toSet();
    final kdf = KdfParams.fromPreset(KdfPreset.standard, crypto.randomBytes(KdfParams.saltLength));
    final key = await crypto.deriveMasterKey(password, kdf);
    final builder = BytesBuilder(copy: false);
    final controller = StreamController<List<int>>();
    final done = controller.stream.forEach(builder.add);
    try {
      await _codec.write(
        sink: controller.sink,
        header: ArchiveHeader(
          mode: ArchiveMode.password,
          createdAt: DateTime.now().toUtc(),
          purpose: 'export',
          kdf: kdf,
        ),
        baseKey: key,
        folders: vault.folders.values.where((f) => folderIds.contains(f.id) || selection.folderIds == null).toList(),
        tags: vault.tags.values.toList(),
        items: items,
        loadAttachment: _loadAttachment,
      );
    } finally {
      await controller.close();
      key.dispose();
    }
    await done;
    return builder.takeBytes();
  }

  Future<SecureKey> _baseKeyFor(ArchiveHeader h, String? password) async {
    final crypto = ref.read(cryptoProvider);
    final s = _session;
    switch (h.mode) {
      case ArchiveMode.password:
        if (password == null) throw PasswordRequiredException(h);
        return crypto.deriveMasterKey(password, h.kdf!);
      case ArchiveMode.vault:
        if (h.vaultId == s.material.vaultId && h.keyGeneration == s.material.keyGeneration) {
          return s.keys.backupKey.copy();
        }
        if (password == null) throw PasswordRequiredException(h);
        final material = VaultKeyMaterial.fromJson(h.material!);
        final keys = await ref.read(keyHierarchyProvider).unlock(material, password);
        final k = keys.backupKey.copy();
        keys.dispose();
        return k;
    }
  }

  Future<ArchiveContents> _open(Uint8List data, String? password) async {
    final (header, _, _) = ArchiveCodec.readHeader(data);
    final key = await _baseKeyFor(header, password);
    try {
      return await _codec.read(data, key);
    } finally {
      key.dispose();
    }
  }

  Future<BackupVerification> verify(Uint8List data, {String? password}) async {
    final (header, _, _) = ArchiveCodec.readHeader(data);
    final c = await _open(data, password);
    for (final b in c.attachments.values) {
      b.fillRange(0, b.length, 0);
    }
    return BackupVerification(
      header: header,
      items: c.items.length,
      folders: c.folders.length,
      tags: c.tags.length,
      attachments: c.attachments.length,
      missingAttachments: c.missingAttachments.length,
    );
  }

  /// Restores an archive. Merge (default) upserts by id, keeping items not in
  /// the archive; replace moves current items not in the archive to Trash
  /// (still recoverable for 30 days). A safety backup is taken first.
  Future<int> restore(Uint8List data, {String? password, bool replace = false}) async {
    final contents = await _open(data, password);
    await backupBeforeDestructive('restore');
    final attachments = ref.read(attachmentServiceProvider);
    final restoredItems = <VaultItem>[];
    for (final item in contents.items) {
      final metas = <AttachmentMeta>[];
      for (final a in item.attachments) {
        final bytes = contents.attachments[a.id];
        if (bytes == null) continue;
        metas.add(await attachments.add(itemId: item.id, fileName: a.fileName, bytes: bytes));
        bytes.fillRange(0, bytes.length, 0);
      }
      restoredItems.add(item.copyWith(attachments: metas));
    }
    final vault = ref.read(vaultProvider.notifier);
    if (replace) {
      final keep = restoredItems.map((i) => i.id).toSet();
      final current = ref.read(vaultProvider).items.values.where((i) => !keep.contains(i.id) && !i.isTrashed);
      await vault.moveToTrash(current.map((i) => i.id));
    }
    await vault.importAll(items: restoredItems, folders: contents.folders, tags: contents.tags);
    return restoredItems.length;
  }

  // ------------------------------------------------------------ cloud copy

  Future<void> uploadToCloud(File backup) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final remote = ref.read(remoteVaultStoreProvider);
    final storage = ref.read(objectStorageProvider);
    if (user == null || remote == null || !storage.available) {
      throw const ObjectStorageException('Cloud backup is not available', retryable: false);
    }
    final id = newId();
    final sha = await R2ObjectStorage.sha256OfFile(backup);
    await storage.upload(ObjectKind.backup, id, backup, sha256: sha);
    final identity = await ref.read(deviceIdentityProvider).ensure();
    await remote.putBackupIndex(
      user.uid,
      BackupIndexEntry(
        id: id,
        createdAt: DateTime.now().toUtc(),
        encryptedSize: await backup.length(),
        cipherSha256: sha,
        formatVersion: ArchiveFormat.formatVersion,
        deviceId: identity.deviceId,
      ),
    );
  }

  Future<Uint8List> downloadCloudBackup(BackupIndexEntry entry) async {
    final storage = ref.read(objectStorageProvider);
    final tmp = File(p.join(_dir.path, 'download-${entry.id}.citadel'));
    await storage.download(ObjectKind.backup, entry.id, tmp);
    final sha = await R2ObjectStorage.sha256OfFile(tmp);
    if (sha != entry.cipherSha256) {
      await tmp.delete();
      throw const ObjectStorageException('Downloaded backup failed its integrity check', retryable: false);
    }
    return tmp.readAsBytes();
  }
}
