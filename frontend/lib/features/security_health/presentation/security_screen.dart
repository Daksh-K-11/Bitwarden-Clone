import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/common_widgets.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../settings/settings_controller.dart';
import '../../vault/application/vault_controller.dart';
import '../../vault/domain/vault_models.dart';
import '../../vault/presentation/item_widgets.dart';
import '../domain/health_report.dart';

final healthReportProvider = Provider<HealthReport>((ref) {
  final items = ref.watch(vaultProvider.select((v) => v.items));
  return HealthAnalyzer.analyze(items.values);
});

/// Breach results: item id -> times seen. Memory only; cleared on lock.
final breachResultsProvider = NotifierProvider<BreachResults, Map<String, int>?>(BreachResults.new);

class BreachResults extends Notifier<Map<String, int>?> {
  bool running = false;
  int done = 0;
  int total = 0;

  @override
  Map<String, int>? build() {
    ref.watch(vaultProvider.select((v) => v.snapshot)); // reset when vault changes/locks
    return null;
  }

  Future<void> run() async {
    if (running) return;
    final client = ref.read(hibpClientProvider);
    final items = ref
        .read(vaultProvider)
        .items
        .values
        .where((i) => !i.isTrashed && (i.fields['password'] ?? '').isNotEmpty)
        .toList();
    running = true;
    total = items.length;
    done = 0;
    final results = <String, int>{};
    state = {};
    try {
      for (final i in items) {
        results[i.id] = await client.breachCount(i.fields['password']!);
        done++;
        state = Map.of(results);
      }
    } finally {
      running = false;
      state = Map.of(results);
    }
  }
}

class SecurityScreen extends ConsumerWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(healthReportProvider);
    final breaches = ref.watch(breachResultsProvider);
    final breachCtrl = ref.read(breachResultsProvider.notifier);
    final settings = ref.watch(settingsProvider);
    final s = Theme.of(context).colorScheme;
    final items = ref.watch(vaultProvider.select((v) => v.items));
    final breached = [
      for (final e in (breaches ?? const <String, int>{}).entries)
        if (e.value > 0 && items[e.key] != null) (items[e.key]!, e.value),
    ];

    final score = report.score;
    final scoreColor = score >= 80 ? Colors.green : (score >= 50 ? Colors.amber.shade700 : s.error);

    return Scaffold(
      appBar: AppBar(title: const Text('Security')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.space4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space5),
                child: Row(
                  children: [
                    SizedBox.square(
                      dimension: 84,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: CircularProgressIndicator(
                              value: score / 100,
                              strokeWidth: 8,
                              color: scoreColor,
                              backgroundColor: s.surfaceContainerHighest,
                            ),
                          ),
                          Text(
                            '$score',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.space5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Password health', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            '${report.totalWithPassword} passwords analysed on this device. Nothing is changed automatically.',
                            style: TextStyle(color: s.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _Metric(icon: Icons.gpp_bad_outlined, color: s.error, title: 'Weak passwords', items: report.weak),
          _Metric(
            icon: Icons.copy_all_rounded,
            color: Colors.deepOrange,
            title: 'Reused passwords',
            items: report.reused.expand((g) => g).toList(),
            detail: report.reused.isEmpty
                ? null
                : '${report.reused.length} password(s) shared by ${report.reusedItemCount} items',
          ),
          _Metric(
            icon: Icons.history_toggle_off_rounded,
            color: Colors.amber.shade800,
            title: 'Not changed in over a year',
            items: report.old,
          ),
          _Metric(
            icon: Icons.phonelink_lock_outlined,
            color: s.tertiary,
            title: 'Logins without 2FA codes',
            items: report.missingTotp,
          ),
          const SectionHeader('Data breaches'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Checks your passwords against Have I Been Pwned using k-anonymity: each password is '
                      'hashed (SHA-1) on this device and only the first 5 characters of the hash are sent. '
                      'Your passwords and full hashes never leave the device.',
                    ),
                    const SizedBox(height: AppTheme.space3),
                    if (!settings.breachCheckEnabled)
                      FilledButton.tonal(
                        onPressed: () =>
                            ref.read(settingsProvider.notifier).update((x) => x.copyWith(breachCheckEnabled: true)),
                        child: const Text('Enable breach checks'),
                      )
                    else if (breachCtrl.running)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LinearProgressIndicator(
                            value: breachCtrl.total == 0 ? null : breachCtrl.done / breachCtrl.total,
                          ),
                          const SizedBox(height: 8),
                          Text('Checked ${breachCtrl.done} of ${breachCtrl.total}'),
                        ],
                      )
                    else
                      FilledButton.icon(
                        onPressed: () async {
                          try {
                            await breachCtrl.run();
                          } catch (e) {
                            if (context.mounted) showError(context, e);
                          }
                        },
                        icon: const Icon(Icons.travel_explore_rounded),
                        label: Text(breaches == null ? 'Check now' : 'Check again'),
                      ),
                    if (breaches != null && !breachCtrl.running) ...[
                      const SizedBox(height: AppTheme.space3),
                      Text(
                        breached.isEmpty
                            ? 'None of your passwords were found in known breaches.'
                            : '${breached.length} password(s) found in breaches - change them.',
                        style: TextStyle(color: breached.isEmpty ? Colors.green : s.error, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          for (final (item, count) in breached)
            ItemTile(
              item: item,
              trailing: Text(
                'Seen ${count}x',
                style: TextStyle(color: s.error, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.color, required this.title, required this.items, this.detail});
  final IconData icon;
  final Color color;
  final String title;
  final List<VaultItem> items;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4, vertical: 4),
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: detail == null ? null : Text(detail!),
        trailing: Text(
          '${items.length}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: items.isEmpty ? null : color),
        ),
        enabled: items.isNotEmpty,
        children: [
          for (final i in items)
            ListTile(
              dense: true,
              title: Text(i.name),
              subtitle: Text(itemSubtitle(i)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/item/${i.id}'),
            ),
        ],
      ),
    ),
  );
}
