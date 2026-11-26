import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/common_widgets.dart';
import '../../backup/backup_service.dart';
import '../../vault/application/vault_controller.dart';
import '../../vault/application/vault_search.dart';
import '../../vault/domain/vault_models.dart';
import '../../vault/presentation/vault_screen.dart';

class FoldersScreen extends ConsumerWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.watch(vaultProvider);
    final counts = ref.watch(folderCountsProvider);
    final ctrl = ref.read(vaultProvider.notifier);

    Future<void> create({String? parentId}) async {
      final name = await promptText(context, title: parentId == null ? 'New folder' : 'New sub-folder');
      if (name == null || name.trim().isEmpty) return;
      try {
        await ctrl.saveFolder(name: name, parentId: parentId);
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    Future<void> delete(Folder f) async {
      final n = counts[f.id] ?? 0;
      final subs = vault.folders.values.where((x) => x.parentId == f.id).length;
      String? target;
      if (n > 0) {
        final others = vault.folders.values
            .where((x) => !folderWithDescendants(f.id, vault.folders).contains(x.id))
            .toList();
        target = await showDialog<String>(
          context: context,
          builder: (c) => SimpleDialog(
            title: Text('Delete "${f.name}"?'),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '$n item(s) are in this folder. Items are never deleted with a folder - where should they go?',
                ),
              ),
              SimpleDialogOption(onPressed: () => Navigator.pop(c, ''), child: const Text('No folder')),
              for (final o in others)
                SimpleDialogOption(onPressed: () => Navigator.pop(c, o.id), child: Text(folderPath(o.id, vault))),
            ],
          ),
        );
        if (target == null) return;
      } else {
        final ok = await confirmDialog(
          context,
          title: 'Delete "${f.name}"?',
          message: subs > 0 ? 'Its $subs sub-folder(s) will move up one level.' : 'The folder is empty.',
          confirm: 'Delete',
          destructive: true,
        );
        if (!ok) return;
      }
      try {
        if (n > 0) await ref.read(backupServiceProvider).backupBeforeDestructive('delete-folder');
        await ctrl.deleteFolder(f.id, moveItemsTo: (target?.isEmpty ?? true) ? null : target);
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    Widget tile(Folder f, int depth) {
      final children = vault.folders.values.where((c) => c.parentId == f.id).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.only(left: 16.0 + depth * 20, right: 4),
            leading: Icon(children.isEmpty ? Icons.folder_outlined : Icons.folder_copy_outlined),
            title: Text(f.name),
            subtitle: Text('${counts[f.id] ?? 0} item(s)'),
            onTap: () {
              ref.read(vaultFilterProvider.notifier).set(VaultFilter(folderId: f.id));
              context.go('/vault');
            },
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                switch (v) {
                  case 'rename':
                    final name = await promptText(context, title: 'Rename folder', initial: f.name);
                    if (name != null && name.trim().isNotEmpty) {
                      await ctrl.saveFolder(id: f.id, name: name, parentId: f.parentId);
                    }
                  case 'sub':
                    await create(parentId: f.id);
                  case 'move':
                    final target = await pickFolder(context, ref);
                    if (target == null) return;
                    try {
                      await ctrl.saveFolder(id: f.id, name: f.name, parentId: target.isEmpty ? null : target);
                    } catch (e) {
                      if (context.mounted) showError(context, e);
                    }
                  case 'delete':
                    await delete(f);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: Text('Rename')),
                PopupMenuItem(value: 'sub', child: Text('New sub-folder')),
                PopupMenuItem(value: 'move', child: Text('Move')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
          for (final c in children) tile(c, depth + 1),
        ],
      );
    }

    final top = vault.folders.values.where((f) => f.parentId == null || !vault.folders.containsKey(f.parentId)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      appBar: AppBar(title: const Text('Folders')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: create,
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Folder'),
      ),
      body: top.isEmpty
          ? const EmptyState(
              icon: Icons.folder_outlined,
              title: 'No folders',
              message: 'Group items into folders and sub-folders.',
            )
          : ListView(padding: const EdgeInsets.only(bottom: 96), children: [for (final f in top) tile(f, 0)]),
    );
  }
}
