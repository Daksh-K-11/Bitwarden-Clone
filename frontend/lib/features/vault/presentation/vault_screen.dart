import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/common_widgets.dart';
import '../../../app/theme.dart';
import '../../attachments/attachment_service.dart';
import '../../backup/backup_service.dart';
import '../../session/session_controller.dart';
import '../../sync/sync_controller.dart';
import '../application/vault_controller.dart';
import '../application/vault_search.dart';
import '../domain/item_type.dart';
import 'item_widgets.dart';

final vaultFilterProvider = NotifierProvider<VaultFilterController, VaultFilter>(VaultFilterController.new);

class VaultFilterController extends Notifier<VaultFilter> {
  @override
  VaultFilter build() => const VaultFilter();
  void set(VaultFilter f) => state = f;
  void update(VaultFilter Function(VaultFilter) fn) => state = fn(state);
}

final filteredItemsProvider = Provider((ref) {
  final vault = ref.watch(vaultProvider);
  final filter = ref.watch(vaultFilterProvider);
  return applyFilter(
    vault.items.values,
    filter,
    index: vault.index,
    folders: vault.folders,
    recentIds: vault.recentIds,
  );
});

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});
  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _search = TextEditingController();
  final _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _title(VaultFilter f, VaultState v) {
    if (f.folderId != null) return f.folderId!.isEmpty ? 'No folder' : (v.folders[f.folderId]?.name ?? 'Folder');
    if (f.tagIds.length == 1) return '#${v.tags[f.tagIds.first]?.name ?? 'tag'}';
    return switch (f.section) {
      VaultSection.all => 'All items',
      VaultSection.favorites => 'Favorites',
      VaultSection.recent => 'Recently used',
      VaultSection.archive => 'Archive',
      VaultSection.trash => 'Trash',
    };
  }

  Future<void> _add() async {
    final type = await pickItemType(context);
    if (type == null || !mounted) return;
    final f = ref.read(vaultFilterProvider);
    final folder = (f.folderId?.isNotEmpty ?? false) ? '&folder=${f.folderId}' : '';
    context.push('/item/new?type=${type.name}$folder');
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultProvider);
    final filter = ref.watch(vaultFilterProvider);
    final items = ref.watch(filteredItemsProvider);
    final sync = ref.watch(syncProvider);
    final selecting = _selected.isNotEmpty;
    final inTrash = filter.section == VaultSection.trash;

    return Scaffold(
      drawer: const VaultDrawer(),
      appBar: selecting
          ? AppBar(
              leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => setState(_selected.clear)),
              title: Text('${_selected.length} selected'),
              actions: _selectionActions(inTrash),
            )
          : AppBar(
              title: Text(_title(filter, vault)),
              actions: [
                _SyncIndicator(status: sync),
                IconButton(
                  tooltip: 'Lock now',
                  icon: const Icon(Icons.lock_outline_rounded),
                  onPressed: () => ref.read(sessionProvider.notifier).lock(),
                ),
              ],
            ),
      floatingActionButton: inTrash || selecting
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add_rounded),
              label: const Text('New'),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.space4, 0, AppTheme.space4, AppTheme.space2),
            child: SearchBar(
              controller: _search,
              hintText: 'Search vault',
              elevation: const WidgetStatePropertyAll(0),
              leading: const Icon(Icons.search_rounded),
              trailing: [
                if (_search.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _search.clear();
                      ref.read(vaultFilterProvider.notifier).update((f) => f.copyWith(query: ''));
                    },
                  ),
                IconButton(
                  icon: Badge(isLabelVisible: filter.hasRefinements, child: const Icon(Icons.tune_rounded)),
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    useRootNavigator: true,
                    isScrollControlled: true,
                    builder: (_) => const _FilterSheet(),
                  ),
                ),
              ],
              onChanged: (q) => ref.read(vaultFilterProvider.notifier).update((f) => f.copyWith(query: q)),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
              children: [
                for (final t in const [
                  ItemType.login,
                  ItemType.card,
                  ItemType.identity,
                  ItemType.secureNote,
                  ItemType.sshKey,
                  ItemType.apiKey,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(t.template.label),
                      avatar: Icon(t.template.icon, size: 16),
                      selected: filter.types.contains(t),
                      onSelected: (on) => ref
                          .read(vaultFilterProvider.notifier)
                          .update((f) => f.copyWith(types: on ? {...f.types, t} : (f.types.toSet()..remove(t)))),
                    ),
                  ),
              ],
            ),
          ),
          if (vault.conflictCount > 0)
            MaterialBanner(
              content: Text('${vault.conflictCount} item(s) changed on two devices at once.'),
              leading: const Icon(Icons.call_split_rounded),
              actions: [TextButton(onPressed: () => context.push('/settings/conflicts'), child: const Text('Review'))],
            ),
          if (vault.snapshot.undecryptable.isNotEmpty)
            MaterialBanner(
              content: Text(
                '${vault.snapshot.undecryptable.length} record(s) failed integrity checks and are hidden. '
                'They may be corrupted or tampered with.',
              ),
              leading: const Icon(Icons.gpp_maybe_rounded),
              actions: const [SizedBox.shrink()],
            ),
          if (inTrash && items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: AppTheme.space2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Items are deleted permanently 30 days after being moved to Trash.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton(onPressed: _emptyTrash, child: const Text('Empty trash')),
                ],
              ),
            ),
          Expanded(
            child: vault.loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => ref.read(syncProvider.notifier).syncNow(),
                    child: items.isEmpty
                        ? ListView(
                            children: [
                              const SizedBox(height: 80),
                              EmptyState(
                                icon: inTrash ? Icons.delete_outline_rounded : Icons.inventory_2_outlined,
                                title: filter.query.isNotEmpty
                                    ? 'No matches'
                                    : inTrash
                                    ? 'Trash is empty'
                                    : 'Nothing here yet',
                                message: filter.query.isEmpty && !inTrash
                                    ? 'Add your first login, card or note with the New button.'
                                    : null,
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: items.length,
                            itemBuilder: (_, i) {
                              final item = items[i];
                              final sel = _selected.contains(item.id);
                              return ItemTile(
                                item: item,
                                selected: sel,
                                trailing: inTrash ? _TrashRemaining(trashedAt: item.trashedAt!) : null,
                                onTap: selecting
                                    ? () => setState(() => sel ? _selected.remove(item.id) : _selected.add(item.id))
                                    : null,
                                onLongPress: () => setState(() => _selected.add(item.id)),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _selectionActions(bool inTrash) {
    final vault = ref.read(vaultProvider.notifier);
    final ids = _selected.toList();
    void done() => setState(_selected.clear);
    if (inTrash) {
      return [
        IconButton(
          tooltip: 'Restore',
          icon: const Icon(Icons.restore_from_trash_rounded),
          onPressed: () async {
            await vault.restore(ids);
            done();
          },
        ),
        IconButton(
          tooltip: 'Delete permanently',
          icon: const Icon(Icons.delete_forever_rounded),
          onPressed: () async {
            final ok = await confirmDialog(
              context,
              title: 'Delete ${ids.length} item(s) permanently?',
              message: 'This cannot be undone.',
              confirm: 'Delete',
              destructive: true,
            );
            if (!ok) return;
            await vault.deleteForever(ids, deleteAttachments: ref.read(attachmentServiceProvider).deleteAllFor);
            done();
          },
        ),
      ];
    }
    return [
      IconButton(
        tooltip: 'Move to folder',
        icon: const Icon(Icons.drive_file_move_outline),
        onPressed: () async {
          final target = await pickFolder(context, ref);
          if (target == null) return;
          await vault.moveToFolder(ids, target.isEmpty ? null : target);
          done();
        },
      ),
      IconButton(
        tooltip: 'Archive',
        icon: const Icon(Icons.archive_outlined),
        onPressed: () async {
          await vault.setArchived(ids, true);
          done();
        },
      ),
      IconButton(
        tooltip: 'Move to trash',
        icon: const Icon(Icons.delete_outline_rounded),
        onPressed: () async {
          await vault.moveToTrash(ids);
          done();
        },
      ),
    ];
  }

  Future<void> _emptyTrash() async {
    final ok = await confirmDialog(
      context,
      title: 'Empty trash?',
      message: 'All items in Trash will be permanently deleted. An encrypted backup is taken first.',
      confirm: 'Empty trash',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(backupServiceProvider).backupBeforeDestructive('empty-trash');
      await ref
          .read(vaultProvider.notifier)
          .emptyTrash(deleteAttachments: ref.read(attachmentServiceProvider).deleteAllFor);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }
}

class _TrashRemaining extends StatelessWidget {
  const _TrashRemaining({required this.trashedAt});
  final DateTime trashedAt;
  @override
  Widget build(BuildContext context) {
    final left = trashRetention - DateTime.now().toUtc().difference(trashedAt);
    final days = left.inDays.clamp(0, 30);
    return Text(days == 0 ? '< 1 day' : '$days days', style: Theme.of(context).textTheme.labelSmall);
  }
}

class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator({required this.status});
  final SyncStatus status;
  @override
  Widget build(BuildContext context) {
    final (icon, tip) = switch (status.phase) {
      SyncPhase.disabled => (null, ''),
      SyncPhase.idle => (
        status.pending > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done_outlined,
        status.pending > 0 ? '${status.pending} change(s) waiting to sync' : 'Synced',
      ),
      SyncPhase.syncing => (Icons.cloud_sync_outlined, 'Syncing...'),
      SyncPhase.offline => (Icons.cloud_off_outlined, status.message ?? 'Offline'),
      SyncPhase.error => (Icons.sync_problem_rounded, status.message ?? 'Sync error'),
    };
    if (icon == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: tip,
      icon: status.phase == SyncPhase.syncing
          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(icon, color: status.phase == SyncPhase.error ? Theme.of(context).colorScheme.error : null),
      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tip))),
    );
  }
}

/// Returns a folder id, '' for "No folder", or null if cancelled.
Future<String?> pickFolder(BuildContext context, WidgetRef ref) {
  final folders = ref.read(vaultProvider).folders.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  return showModalBottomSheet<String>(
    context: context,
    useRootNavigator: true,
    builder: (c) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_off_outlined),
            title: const Text('No folder'),
            onTap: () => Navigator.pop(c, ''),
          ),
          for (final f in folders)
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(folderPath(f.id, ref.read(vaultProvider))),
              onTap: () => Navigator.pop(c, f.id),
            ),
        ],
      ),
    ),
  );
}

String folderPath(String id, VaultState v) {
  final parts = <String>[];
  String? cur = id;
  var guard = 0;
  while (cur != null && guard++ < 20) {
    final f = v.folders[cur];
    if (f == null) break;
    parts.insert(0, f.name);
    cur = f.parentId;
  }
  return parts.join(' / ');
}

class VaultDrawer extends ConsumerWidget {
  const VaultDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(vaultFilterProvider);
    final vault = ref.watch(vaultProvider);
    final counts = ref.watch(folderCountsProvider);
    final tagCounts = ref.watch(tagCountsProvider);
    final ctrl = ref.read(vaultFilterProvider.notifier);
    final items = vault.items.values;

    void go(VaultFilter f) {
      ctrl.set(f.copyWith(query: filter.query));
      Navigator.pop(context);
    }

    int count(bool Function(dynamic) test) => items.where(test).length;

    final topFolders =
        vault.folders.values.where((f) => f.parentId == null || !vault.folders.containsKey(f.parentId)).toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    Widget folderTile(String id, int depth) {
      final f = vault.folders[id]!;
      final children = vault.folders.values.where((c) => c.parentId == id).toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      return Column(
        children: [
          NavigationDrawerTile(
            icon: Icons.folder_outlined,
            label: f.name,
            count: counts[id] ?? 0,
            indent: depth,
            selected: filter.folderId == id,
            onTap: () => go(VaultFilter(folderId: id)),
          ),
          for (final c in children) folderTile(c.id, depth + 1),
        ],
      );
    }

    return NavigationDrawer(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 8),
          child: Row(
            children: [
              Icon(Icons.shield_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Text('Citadel', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        NavigationDrawerTile(
          icon: Icons.all_inbox_rounded,
          label: 'All items',
          count: count((i) => !i.isTrashed && !i.archived),
          selected: filter.section == VaultSection.all && filter.folderId == null && filter.tagIds.isEmpty,
          onTap: () => go(const VaultFilter()),
        ),
        NavigationDrawerTile(
          icon: Icons.star_outline_rounded,
          label: 'Favorites',
          count: count((i) => i.favorite && !i.isTrashed && !i.archived),
          selected: filter.section == VaultSection.favorites,
          onTap: () => go(const VaultFilter(section: VaultSection.favorites)),
        ),
        NavigationDrawerTile(
          icon: Icons.history_rounded,
          label: 'Recently used',
          selected: filter.section == VaultSection.recent,
          onTap: () => go(const VaultFilter(section: VaultSection.recent)),
        ),
        NavigationDrawerTile(
          icon: Icons.update_rounded,
          label: 'Modified in last 7 days',
          selected: filter.modifiedWithinDays == 7,
          onTap: () => go(const VaultFilter(modifiedWithinDays: 7, sort: SortOrder.recentlyModified)),
        ),
        const Divider(indent: 28, endIndent: 28),
        SectionHeader(
          'Folders',
          trailing: IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => context.push('/folders'),
          ),
        ),
        NavigationDrawerTile(
          icon: Icons.folder_off_outlined,
          label: 'No folder',
          count: counts[null] ?? 0,
          selected: filter.folderId == '',
          onTap: () => go(const VaultFilter(folderId: '')),
        ),
        for (final f in topFolders) folderTile(f.id, 0),
        const Divider(indent: 28, endIndent: 28),
        SectionHeader(
          'Tags',
          trailing: IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => context.push('/tags')),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in vault.tags.values)
                FilterChip(
                  avatar: CircleAvatar(backgroundColor: Color(t.color), radius: 6),
                  label: Text('${t.name} ${tagCounts[t.id] ?? 0}'),
                  selected: filter.tagIds.contains(t.id),
                  onSelected: (on) => ctrl.update(
                    (f) => f.copyWith(tagIds: on ? {...f.tagIds, t.id} : (f.tagIds.toSet()..remove(t.id))),
                  ),
                ),
              if (vault.tags.isEmpty) Text('No tags yet', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const Divider(indent: 28, endIndent: 28),
        NavigationDrawerTile(
          icon: Icons.archive_outlined,
          label: 'Archive',
          count: count((i) => i.archived && !i.isTrashed),
          selected: filter.section == VaultSection.archive,
          onTap: () => go(const VaultFilter(section: VaultSection.archive)),
        ),
        NavigationDrawerTile(
          icon: Icons.delete_outline_rounded,
          label: 'Trash',
          count: count((i) => i.isTrashed),
          selected: filter.section == VaultSection.trash,
          onTap: () => go(const VaultFilter(section: VaultSection.trash)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class NavigationDrawerTile extends StatelessWidget {
  const NavigationDrawerTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.count,
    this.selected = false,
    this.indent = 0,
  });
  final IconData icon;
  final String label;
  final int? count;
  final bool selected;
  final int indent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: 12.0 + indent * 16, right: 12),
    child: ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: Theme.of(context).colorScheme.secondaryContainer,
      shape: const StadiumBorder(),
      leading: Icon(icon, size: 22),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: count == null ? null : Text('$count', style: Theme.of(context).textTheme.labelMedium),
      onTap: onTap,
    ),
  );
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = ref.watch(vaultFilterProvider);
    final c = ref.read(vaultFilterProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppTheme.space4, 0, AppTheme.space4, AppTheme.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Filter & sort', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: () => c.set(VaultFilter(section: f.section, query: f.query)),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.space3),
            Text('Item types', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppTheme.space2),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in ItemType.values)
                  FilterChip(
                    label: Text(t.template.label),
                    selected: f.types.contains(t),
                    onSelected: (on) =>
                        c.update((x) => x.copyWith(types: on ? {...x.types, t} : (x.types.toSet()..remove(t)))),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.space4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Favorites only'),
              value: f.favoritesOnly,
              onChanged: (v) => c.update((x) => x.copyWith(favoritesOnly: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('With authenticator (TOTP)'),
              value: f.withTotpOnly,
              onChanged: (v) => c.update((x) => x.copyWith(withTotpOnly: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Modified in the last 30 days'),
              value: f.modifiedWithinDays == 30,
              onChanged: (v) => c.update((x) => x.copyWith(modifiedWithinDays: () => v ? 30 : null)),
            ),
            const SizedBox(height: AppTheme.space2),
            Text('Sort by', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppTheme.space2),
            SegmentedButton<SortOrder>(
              segments: const [
                ButtonSegment(value: SortOrder.name, label: Text('Name')),
                ButtonSegment(value: SortOrder.recentlyModified, label: Text('Modified')),
                ButtonSegment(value: SortOrder.recentlyCreated, label: Text('Created')),
              ],
              selected: {f.sort},
              onSelectionChanged: (s) => c.update((x) => x.copyWith(sort: s.first)),
            ),
          ],
        ),
      ),
    );
  }
}
