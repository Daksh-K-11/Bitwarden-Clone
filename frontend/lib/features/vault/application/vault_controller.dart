import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/db/database.dart';
import '../../../core/util/log.dart';
import '../../session/session_controller.dart';
import '../../settings/settings_controller.dart';
import '../data/vault_repository.dart';
import '../domain/item_type.dart';
import '../domain/vault_models.dart';
import 'vault_search.dart';

const trashRetention = Duration(days: 30);

String newId() => const Uuid().v4();

class VaultState {
  const VaultState({
    required this.snapshot,
    required this.index,
    this.loading = false,
    this.recentIds = const [],
    this.conflictCount = 0,
  });

  static const locked = VaultState(snapshot: VaultSnapshot.empty, index: SearchIndex.empty);

  final VaultSnapshot snapshot;
  final SearchIndex index;
  final bool loading;
  final List<String> recentIds;
  final int conflictCount;

  Map<String, VaultItem> get items => snapshot.items;
  Map<String, Folder> get folders => snapshot.folders;
  Map<String, Tag> get tags => snapshot.tags;

  VaultState copyWith({
    VaultSnapshot? snapshot,
    SearchIndex? index,
    bool? loading,
    List<String>? recentIds,
    int? conflictCount,
  }) => VaultState(
    snapshot: snapshot ?? this.snapshot,
    index: index ?? this.index,
    loading: loading ?? this.loading,
    recentIds: recentIds ?? this.recentIds,
    conflictCount: conflictCount ?? this.conflictCount,
  );
}

final vaultProvider = NotifierProvider<VaultController, VaultState>(VaultController.new);

/// Owns the decrypted vault while unlocked. Rebuilding on lock drops every
/// decrypted object (and the search index) for garbage collection.
class VaultController extends Notifier<VaultState> {
  VaultRepository get _repo => ref.read(vaultRepositoryProvider);
  AppDatabase get _db => ref.read(databaseProvider);

  @override
  VaultState build() {
    final keys = ref.watch(vaultKeysProvider);
    ref.watch(settingsProvider.select((s) => s.searchNotes));
    if (keys == null) return VaultState.locked;
    Future.microtask(reload);
    return const VaultState(snapshot: VaultSnapshot.empty, index: SearchIndex.empty, loading: true);
  }

  SessionUnlocked get _session {
    final s = ref.read(sessionProvider);
    if (s is! SessionUnlocked) throw StateError('Vault is locked');
    return s;
  }

  int get _keyGen => _session.material.keyGeneration;

  Future<void> reload() async {
    final keys = ref.read(vaultKeysProvider);
    if (keys == null) return;
    final snapshot = await _repo.loadAll(keys);
    if (ref.read(vaultKeysProvider) != keys) return; // locked meanwhile
    final recents = (await _db.recents()).map((r) => r.itemId).toList();
    final conflicts = await _db.select(_db.syncConflicts).get();
    state = VaultState(
      snapshot: snapshot,
      index: _buildIndex(snapshot),
      recentIds: recents,
      conflictCount: conflicts.length,
    );
    unawaited(_purgeExpiredTrash());
  }

  SearchIndex _buildIndex(VaultSnapshot s) => SearchIndex.build(
    s.items.values,
    folders: s.folders,
    tags: s.tags,
    includeNotes: ref.read(settingsProvider).searchNotes,
  );

  void _setSnapshot(VaultSnapshot s) => state = state.copyWith(snapshot: s, index: _buildIndex(s));

  VaultSnapshot _withItems(Iterable<VaultItem> changed, {Iterable<String> removed = const []}) {
    final items = Map<String, VaultItem>.of(state.items);
    for (final i in changed) {
      items[i.id] = i;
    }
    for (final id in removed) {
      items.remove(id);
    }
    return VaultSnapshot(items: items, folders: state.folders, tags: state.tags);
  }

  // ------------------------------------------------------------------ items

  VaultItem draft(ItemType type, {String? folderId}) {
    final now = DateTime.now().toUtc();
    return VaultItem(id: newId(), type: type, name: '', createdAt: now, updatedAt: now, folderId: folderId);
  }

  /// Saves an item, maintaining encrypted password history and the
  /// monotonic `seq` counter.
  Future<VaultItem> saveItem(VaultItem item) async {
    final previous = state.items[item.id];
    final settings = ref.read(settingsProvider);
    final now = DateTime.now().toUtc();
    var next = item.copyWith(updatedAt: now, seq: (previous?.seq ?? 0) + 1);

    if (previous != null) {
      final history = [...next.passwordHistory];
      var passwordChanged = false;
      for (final key in item.type.template.trackPasswordHistory) {
        final old = previous.fields[key] ?? '';
        final cur = next.fields[key] ?? '';
        if (old.isNotEmpty && old != cur) {
          passwordChanged = true;
          if (settings.passwordHistoryEnabled) {
            history.insert(0, PasswordHistoryEntry(password: old, changedAt: now, fieldKey: key));
          }
        }
      }
      if (passwordChanged) {
        next = next.copyWith(
          passwordUpdatedAt: now,
          passwordHistory: history.take(settings.passwordHistoryMax).toList(),
        );
      }
    } else if ((next.fields['password'] ?? '').isNotEmpty) {
      next = next.copyWith(passwordUpdatedAt: now);
    }

    await _repo.saveItem(_session.keys, next, keyGeneration: _keyGen);
    _setSnapshot(_withItems([next]));
    return next;
  }

  Future<void> _saveMany(List<VaultItem> items) async {
    if (items.isEmpty) return;
    final now = DateTime.now().toUtc();
    final updated = [for (final i in items) i.copyWith(updatedAt: now, seq: i.seq + 1)];
    await _repo.saveBatch(_session.keys, items: updated, keyGeneration: _keyGen);
    _setSnapshot(_withItems(updated));
  }

  Future<void> toggleFavorite(String id) async {
    final i = state.items[id];
    if (i != null) await _saveMany([i.copyWith(favorite: !i.favorite)]);
  }

  Future<void> setArchived(Iterable<String> ids, bool archived) => _saveMany([
    for (final id in ids)
      if (state.items[id] case final i?) i.copyWith(archived: archived),
  ]);

  Future<void> moveToTrash(Iterable<String> ids) => _saveMany([
    for (final id in ids)
      if (state.items[id] case final i?) i.copyWith(trashedAt: DateTime.now().toUtc()),
  ]);

  Future<void> restore(Iterable<String> ids) => _saveMany([
    for (final id in ids)
      if (state.items[id] case final i?) i.copyWith(trashedAt: null),
  ]);

  Future<void> moveToFolder(Iterable<String> ids, String? folderId) => _saveMany([
    for (final id in ids)
      if (state.items[id] case final i?) i.copyWith(folderId: folderId),
  ]);

  Future<void> setTags(String id, List<String> tagIds) async {
    final i = state.items[id];
    if (i != null) await _saveMany([i.copyWith(tagIds: tagIds)]);
  }

  /// Permanently deletes items (and their encrypted attachments).
  Future<void> deleteForever(Iterable<String> ids, {Future<void> Function(VaultItem)? deleteAttachments}) async {
    final list = ids.toList();
    for (final id in list) {
      final item = state.items[id];
      if (item != null && deleteAttachments != null && item.attachments.isNotEmpty) {
        await deleteAttachments(item);
      }
    }
    await _repo.deletePermanently(list);
    _setSnapshot(_withItems(const [], removed: list));
  }

  Future<void> emptyTrash({Future<void> Function(VaultItem)? deleteAttachments}) => deleteForever(
    state.items.values.where((i) => i.isTrashed).map((i) => i.id),
    deleteAttachments: deleteAttachments,
  );

  Future<void> _purgeExpiredTrash() async {
    final cutoff = DateTime.now().toUtc().subtract(trashRetention);
    final expired = state.items.values.where((i) => i.trashedAt != null && i.trashedAt!.isBefore(cutoff));
    if (expired.isEmpty) return;
    Log.d('vault', 'Purging ${expired.length} expired trash items');
    await deleteForever(expired.map((i) => i.id));
  }

  Future<void> recordAccess(String id) async {
    await _db.touchRecent(id);
    final recents = [id, ...state.recentIds.where((r) => r != id)].take(20).toList();
    state = state.copyWith(recentIds: recents);
  }

  Future<void> importAll({
    List<VaultItem> items = const [],
    List<Folder> folders = const [],
    List<Tag> tags = const [],
  }) async {
    await _repo.saveBatch(_session.keys, items: items, folders: folders, tags: tags, keyGeneration: _keyGen);
    await reload();
  }

  // ---------------------------------------------------------------- folders

  Future<Folder> saveFolder({String? id, required String name, String? parentId}) async {
    final now = DateTime.now().toUtc();
    final existing = id == null ? null : state.folders[id];
    if (parentId != null && id != null && folderWithDescendants(id, state.folders).contains(parentId)) {
      throw ArgumentError('A folder cannot be moved inside itself');
    }
    final f = Folder(
      id: id ?? newId(),
      name: name.trim(),
      parentId: parentId,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _repo.saveFolder(_session.keys, f, keyGeneration: _keyGen);
    final folders = Map<String, Folder>.of(state.folders)..[f.id] = f;
    _setSnapshot(VaultSnapshot(items: state.items, folders: folders, tags: state.tags));
    return f;
  }

  /// Deletes a folder. Items are never deleted: they move to [moveItemsTo]
  /// (null = "No folder"); sub-folders move up to the deleted folder's parent.
  Future<void> deleteFolder(String folderId, {String? moveItemsTo}) async {
    final folder = state.folders[folderId];
    if (folder == null) return;
    final now = DateTime.now().toUtc();
    final items = [
      for (final i in state.items.values)
        if (i.folderId == folderId) i.copyWith(folderId: moveItemsTo, updatedAt: now, seq: i.seq + 1),
    ];
    final children = [
      for (final f in state.folders.values)
        if (f.parentId == folderId) f.copyWith(parentId: folder.parentId, updatedAt: now),
    ];
    await _repo.saveBatch(_session.keys, items: items, folders: children, keyGeneration: _keyGen);
    await _repo.deletePermanently([folderId]);
    final folders = Map<String, Folder>.of(state.folders)..remove(folderId);
    for (final c in children) {
      folders[c.id] = c;
    }
    final allItems = Map<String, VaultItem>.of(state.items);
    for (final i in items) {
      allItems[i.id] = i;
    }
    _setSnapshot(VaultSnapshot(items: allItems, folders: folders, tags: state.tags));
  }

  // ------------------------------------------------------------------- tags

  Future<Tag> saveTag({String? id, required String name, required int color}) async {
    final now = DateTime.now().toUtc();
    final existing = id == null ? null : state.tags[id];
    final t = Tag(
      id: id ?? newId(),
      name: name.trim(),
      color: color,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _repo.saveTag(_session.keys, t, keyGeneration: _keyGen);
    final tags = Map<String, Tag>.of(state.tags)..[t.id] = t;
    _setSnapshot(VaultSnapshot(items: state.items, folders: state.folders, tags: tags));
    return t;
  }

  /// Deleting a tag only removes it from items; items are kept.
  Future<void> deleteTag(String tagId) async {
    final affected = [
      for (final i in state.items.values)
        if (i.tagIds.contains(tagId)) i.copyWith(tagIds: i.tagIds.where((t) => t != tagId).toList()),
    ];
    await _saveMany(affected);
    await _repo.deletePermanently([tagId]);
    final tags = Map<String, Tag>.of(state.tags)..remove(tagId);
    _setSnapshot(VaultSnapshot(items: state.items, folders: state.folders, tags: tags));
  }
}

/// Item counts per folder (direct children only) for the folder list.
final folderCountsProvider = Provider<Map<String?, int>>((ref) {
  final items = ref.watch(vaultProvider.select((s) => s.items));
  final counts = <String?, int>{};
  for (final i in items.values) {
    if (i.isTrashed || i.archived) continue;
    counts[i.folderId] = (counts[i.folderId] ?? 0) + 1;
  }
  return counts;
});

final tagCountsProvider = Provider<Map<String, int>>((ref) {
  final items = ref.watch(vaultProvider.select((s) => s.items));
  final counts = <String, int>{};
  for (final i in items.values) {
    if (i.isTrashed) continue;
    for (final t in i.tagIds) {
      counts[t] = (counts[t] ?? 0) + 1;
    }
  }
  return counts;
});
