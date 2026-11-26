import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/common_widgets.dart';
import '../../../app/theme.dart';
import '../../totp/domain/totp.dart';
import '../domain/item_type.dart';
import '../domain/vault_models.dart';

/// Non-sensitive one-line description for lists (never a secret).
String itemSubtitle(VaultItem item) {
  final t = item.type.template;
  for (final k in t.subtitleKeys) {
    final v = item.fields[k];
    if (v != null && v.isNotEmpty) return v;
  }
  if (item.type == ItemType.card) {
    final n = item.fields['number'] ?? '';
    if (n.length >= 4) return '•••• ${n.substring(n.length - 4)}';
  }
  if (item.uris.isNotEmpty) return Uri.tryParse(item.uris.first)?.host ?? item.uris.first;
  return t.label;
}

String formatCardNumber(String n) {
  final digits = n.replaceAll(RegExp(r'\D'), '');
  final groups = <String>[];
  for (var i = 0; i < digits.length; i += 4) {
    groups.add(digits.substring(i, (i + 4).clamp(0, digits.length)));
  }
  return groups.join(' ');
}

String? detectCardBrand(String n) {
  final d = n.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return null;
  if (d.startsWith('4')) return 'Visa';
  if (RegExp(r'^(5[1-5]|2[2-7])').hasMatch(d)) return 'Mastercard';
  if (RegExp(r'^3[47]').hasMatch(d)) return 'American Express';
  if (RegExp(r'^(60|65|81|82|508)').hasMatch(d)) return 'RuPay';
  if (RegExp(r'^(6011|64[4-9])').hasMatch(d)) return 'Discover';
  if (RegExp(r'^35').hasMatch(d)) return 'JCB';
  if (RegExp(r'^3(0[0-5]|[68])').hasMatch(d)) return 'Diners Club';
  if (d.startsWith('62')) return 'UnionPay';
  return null;
}

class ItemTile extends ConsumerWidget {
  const ItemTile({super.key, required this.item, this.selected = false, this.onTap, this.onLongPress, this.trailing});
  final VaultItem item;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = Theme.of(context).colorScheme;
    return ListTile(
      selected: selected,
      selectedTileColor: s.primaryContainer.withValues(alpha: 0.35),
      onTap: onTap ?? () => context.push('/item/${item.id}'),
      onLongPress: onLongPress,
      leading: selected
          ? CircleAvatar(
              backgroundColor: s.primary,
              child: Icon(Icons.check_rounded, color: s.onPrimary),
            )
          : ItemAvatar(name: item.name, icon: item.type.template.icon),
      title: Row(
        children: [
          Flexible(
            child: Text(item.name.isEmpty ? 'Untitled' : item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (item.favorite) ...[
            const SizedBox(width: 6),
            Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade600),
          ],
          if (item.attachments.isNotEmpty) ...[
            const SizedBox(width: 4),
            Icon(Icons.attach_file_rounded, size: 14, color: s.onSurfaceVariant),
          ],
        ],
      ),
      subtitle: Text(itemSubtitle(item), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing ?? _QuickCopy(item: item),
    );
  }
}

class _QuickCopy extends ConsumerWidget {
  const _QuickCopy({required this.item});
  final VaultItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <(String, String, bool)>[];
    final username = item.fields['username'] ?? item.fields['email'] ?? '';
    if (username.isNotEmpty) actions.add(('Copy username', username, false));
    final pw = item.fields['password'] ?? '';
    if (pw.isNotEmpty && !item.reprompt) actions.add(('Copy password', pw, true));
    if ((item.totp ?? '').isNotEmpty && TotpConfig.isValid(item.totp!)) {
      actions.add(('Copy TOTP code', TotpConfig.parse(item.totp!).codeAt(DateTime.now()), true));
    }
    if (actions.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<(String, String, bool)>(
      icon: const Icon(Icons.more_vert_rounded),
      tooltip: 'Quick copy',
      itemBuilder: (_) => [for (final a in actions) PopupMenuItem(value: a, child: Text(a.$1))],
      onSelected: (a) {
        // Recompute TOTP at tap time so the code is current.
        final value = a.$1 == 'Copy TOTP code' ? TotpConfig.parse(item.totp!).codeAt(DateTime.now()) : a.$2;
        copySecret(context, ref, value, a.$1.replaceFirst('Copy ', ''), sensitive: a.$3);
      },
    );
  }
}

/// Type picker for the quick-add button.
Future<ItemType?> pickItemType(BuildContext context) => showModalBottomSheet<ItemType>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  builder: (c) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.space4, 0, AppTheme.space4, AppTheme.space4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New item', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: AppTheme.space3),
          Flexible(
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.1,
              children: [
                for (final t in ItemType.values)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.pop(c, t),
                    child: Ink(
                      decoration: BoxDecoration(
                        color: Theme.of(c).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(t.template.icon, color: Theme.of(c).colorScheme.primary),
                          const SizedBox(height: 8),
                          Text(t.template.label, textAlign: TextAlign.center, style: Theme.of(c).textTheme.labelMedium),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
