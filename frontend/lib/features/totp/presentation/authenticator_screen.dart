import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/common_widgets.dart';
import '../../../app/theme.dart';
import '../../vault/application/vault_controller.dart';
import '../../vault/presentation/item_edit_screen.dart' show showTotpEntryDialog;
import '../../vault/presentation/item_widgets.dart';
import '../domain/totp.dart';
import 'totp_widgets.dart';

final _totpQueryProvider = NotifierProvider<_Query, String>(_Query.new);

class _Query extends Notifier<String> {
  @override
  String build() => '';
  void set(String q) => state = q;
}

class AuthenticatorScreen extends ConsumerWidget {
  const AuthenticatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vault = ref.watch(vaultProvider);
    final query = ref.watch(_totpQueryProvider).toLowerCase();
    final entries = [
      for (final i in vault.items.values)
        if (!i.isTrashed && (i.totp ?? '').isNotEmpty && TotpConfig.isValid(i.totp!))
          if (query.isEmpty ||
              i.name.toLowerCase().contains(query) ||
              itemSubtitle(i).toLowerCase().contains(query) ||
              (vault.folders[i.folderId]?.name.toLowerCase().contains(query) ?? false))
            (i, TotpConfig.parse(i.totp!)),
    ]..sort((a, b) => a.$1.name.toLowerCase().compareTo(b.$1.name.toLowerCase()));

    Future<void> add() async {
      final choice = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        builder: (c) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.qr_code_scanner_rounded),
                title: const Text('Scan a QR code'),
                onTap: () => Navigator.pop(c, 'scan'),
              ),
              ListTile(
                leading: const Icon(Icons.keyboard_rounded),
                title: const Text('Enter key manually or paste otpauth:// link'),
                onTap: () => Navigator.pop(c, 'manual'),
              ),
            ],
          ),
        ),
      );
      if (!context.mounted || choice == null) return;
      if (choice == 'scan') {
        context.push('/scan');
      } else {
        final uri = await showTotpEntryDialog(context);
        if (uri != null && context.mounted) context.push('/item/new?type=login', extra: {'totp': uri});
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Authenticator')),
      floatingActionButton: FloatingActionButton(onPressed: add, child: const Icon(Icons.add_rounded)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.space4, 0, AppTheme.space4, AppTheme.space2),
            child: SearchBar(
              hintText: 'Search accounts',
              elevation: const WidgetStatePropertyAll(0),
              leading: const Icon(Icons.search_rounded),
              onChanged: ref.read(_totpQueryProvider.notifier).set,
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? EmptyState(
                    icon: Icons.timer_outlined,
                    title: 'No authenticator codes yet',
                    message:
                        'Scan the QR code a website shows when you enable two-factor authentication. '
                        'Secrets are encrypted in your vault and never leave this device unencrypted.',
                    action: FilledButton.icon(
                      onPressed: add,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Add code'),
                    ),
                  )
                : TotpTicker(
                    builder: (context, now) => ListView.separated(
                      padding: const EdgeInsets.fromLTRB(AppTheme.space4, AppTheme.space2, AppTheme.space4, 96),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppTheme.space2),
                      itemBuilder: (_, i) {
                        final (item, cfg) = entries[i];
                        final remaining = cfg.secondsRemaining(now);
                        return Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppTheme.radius),
                            onTap: () => copySecret(context, ref, cfg.codeAt(DateTime.now()), 'Code for ${item.name}'),
                            onLongPress: () => context.push('/item/${item.id}'),
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.space4),
                              child: Row(
                                children: [
                                  ItemAvatar(name: item.name, icon: Icons.shield_outlined),
                                  const SizedBox(width: AppTheme.space3),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: Theme.of(context).textTheme.titleSmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          cfg.account ?? itemSubtitle(item),
                                          style: Theme.of(context).textTheme.bodySmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formatTotpCode(cfg.codeAt(now)),
                                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 2,
                                            color: remaining <= 5
                                                ? Theme.of(context).colorScheme.error
                                                : Theme.of(context).colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  CountdownRing(remaining: remaining, period: cfg.period, size: 34),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
