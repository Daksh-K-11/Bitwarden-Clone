import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/common_widgets.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/db/database.dart';
import '../../account/account_service.dart';
import '../../session/session_controller.dart';
import '../../vault/application/vault_controller.dart';
import '../sync_engine.dart';

final _conflictsProvider = FutureProvider.autoDispose((ref) {
  ref.watch(vaultProvider);
  final db = ref.read(databaseProvider);
  return db.select(db.syncConflicts).get();
});

class ConflictsScreen extends ConsumerWidget {
  const ConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflicts = ref.watch(_conflictsProvider);
    final vault = ref.watch(vaultProvider);
    final keys = ref.watch(vaultKeysProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sync conflicts')),
      body: conflicts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty || keys == null) {
            return const EmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'No conflicts',
              message: 'Everything is in sync.',
            );
          }
          final codec = ref.read(recordCodecProvider);
          return ListView(
            padding: const EdgeInsets.all(AppTheme.space4),
            children: [
              const Text(
                'These items were edited on this device and another device at the same time. The other device\'s '
                'version is shown in your vault; your version from this device was kept safely here.',
              ),
              const SizedBox(height: AppTheme.space4),
              for (final SyncConflict c in list)
                Builder(
                  builder: (context) {
                    final mine = codec.decryptItem(
                      keys,
                      c.recordId,
                      codec.decryptConflict(keys, c.recordId, c.localPayload),
                    );
                    final theirs = vault.items[c.recordId];
                    Future<void> pick(ConflictChoice choice) async {
                      try {
                        await ref.read(accountServiceProvider).resolveConflict(c, choice);
                        ref.invalidate(_conflictsProvider);
                      } catch (e) {
                        if (context.mounted) showError(context, e);
                      }
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: AppTheme.space3),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.space4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(mine.name, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text('This device: edited ${DateFormat.yMMMd().add_jm().format(mine.updatedAt.toLocal())}'),
                            Text(
                              theirs == null
                                  ? 'Other device: deleted'
                                  : 'Other device: edited ${DateFormat.yMMMd().add_jm().format(theirs.updatedAt.toLocal())}',
                            ),
                            if (theirs != null) ..._diff(mine.toJson(), theirs.toJson()),
                            const SizedBox(height: AppTheme.space3),
                            Wrap(
                              spacing: 8,
                              children: [
                                FilledButton.tonal(
                                  onPressed: () => pick(ConflictChoice.keepMine),
                                  child: const Text('Keep mine'),
                                ),
                                FilledButton.tonal(
                                  onPressed: () => pick(ConflictChoice.keepTheirs),
                                  child: const Text('Keep theirs'),
                                ),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                                  onPressed: () => pick(ConflictChoice.keepBoth),
                                  child: const Text('Keep both'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  /// Names the changed top-level fields (never shows secret values).
  static List<Widget> _diff(Map<String, dynamic> a, Map<String, dynamic> b) {
    const ignore = {'updatedAt', 'seq', 'passwordHistory'};
    final changed = <String>[];
    for (final k in {...a.keys, ...b.keys}) {
      if (ignore.contains(k)) continue;
      if (k == 'fields') {
        final fa = (a[k] as Map?) ?? {};
        final fb = (b[k] as Map?) ?? {};
        for (final f in {...fa.keys, ...fb.keys}) {
          if (fa[f] != fb[f]) changed.add('$f');
        }
      } else if ('${a[k]}' != '${b[k]}') {
        changed.add(k);
      }
    }
    return changed.isEmpty ? [] : [const SizedBox(height: 6), Text('Differs in: ${changed.join(', ')}')];
  }
}
