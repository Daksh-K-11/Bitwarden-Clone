import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/common_widgets.dart';
import '../../vault/application/vault_controller.dart';
import '../../vault/application/vault_search.dart';
import '../../vault/domain/vault_models.dart';
import '../../vault/presentation/item_edit_screen.dart' show tagPalette;
import '../../vault/presentation/vault_screen.dart';

class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  Future<void> _edit(BuildContext context, WidgetRef ref, {Tag? tag}) async {
    final name = TextEditingController(text: tag?.name);
    var color = tag?.color ?? tagPalette.first;
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(tag == null ? 'New tag' : 'Edit tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final p in tagPalette)
                    GestureDetector(
                      onTap: () => set(() => color = p),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(p),
                        child: color == p ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (r == true && name.text.trim().isNotEmpty) {
      await ref.read(vaultProvider.notifier).saveTag(id: tag?.id, name: name.text, color: color);
    }
    name.dispose();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(vaultProvider.select((v) => v.tags)).values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final counts = ref.watch(tagCountsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tag'),
      ),
      body: tags.isEmpty
          ? const EmptyState(
              icon: Icons.sell_outlined,
              title: 'No tags',
              message: 'Tags work across folders and item types. An item can have many.',
            )
          : ListView(
              children: [
                for (final t in tags)
                  ListTile(
                    leading: CircleAvatar(backgroundColor: Color(t.color), radius: 10),
                    title: Text(t.name),
                    subtitle: Text('${counts[t.id] ?? 0} item(s)'),
                    onTap: () {
                      ref.read(vaultFilterProvider.notifier).set(VaultFilter(tagIds: {t.id}));
                      context.go('/vault');
                    },
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'edit') await _edit(context, ref, tag: t);
                        if (v == 'delete' && context.mounted) {
                          final ok = await confirmDialog(
                            context,
                            title: 'Delete tag "${t.name}"?',
                            message:
                                'The tag is removed from ${counts[t.id] ?? 0} item(s). The items themselves are kept.',
                            confirm: 'Delete',
                            destructive: true,
                          );
                          if (ok) await ref.read(vaultProvider.notifier).deleteTag(t.id);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
