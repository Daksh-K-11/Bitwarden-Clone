import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/common_widgets.dart';
import '../../../app/theme.dart';
import '../../attachments/attachment_service.dart';
import '../../settings/settings_controller.dart';
import '../../totp/domain/totp.dart';
import '../../totp/presentation/totp_widgets.dart';
import '../application/vault_controller.dart';
import '../domain/item_type.dart';
import '../domain/vault_models.dart';
import 'item_widgets.dart';
import 'vault_screen.dart' show folderPath;

class ItemDetailScreen extends ConsumerStatefulWidget {
  const ItemDetailScreen({super.key, required this.itemId});
  final String itemId;
  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  /// Re-authentication for this screen visit (re-prompt / card details).
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(vaultProvider.notifier).recordAccess(widget.itemId));
  }

  bool _needsAuth(VaultItem item, FieldSpec? spec) {
    if (_authorized) return false;
    if (item.reprompt) return true;
    if (item.type == ItemType.card && ref.read(settingsProvider).requireAuthForCards) {
      return spec?.key == 'number' || spec?.key == 'code' || spec?.key == 'pin';
    }
    return false;
  }

  Future<bool> _gate(VaultItem item, FieldSpec? spec) async {
    if (!_needsAuth(item, spec)) return true;
    final ok = await reauthenticate(ref, 'Confirm it is you to view this information');
    if (ok) setState(() => _authorized = true);
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(vaultProvider);
    final item = vault.items[widget.itemId];
    if (item == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.search_off_rounded, title: 'Item not found'),
      );
    }
    final t = item.type.template;
    final settings = ref.watch(settingsProvider);
    final s = Theme.of(context).colorScheme;
    final ctrl = ref.read(vaultProvider.notifier);
    final df = DateFormat.yMMMd().add_jm();

    final visibleFields = [
      for (final spec in t.fields)
        if ((item.fields[spec.key] ?? '').isNotEmpty) spec,
    ];

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!item.isTrashed)
            IconButton(
              tooltip: item.favorite ? 'Remove from favorites' : 'Add to favorites',
              icon: Icon(
                item.favorite ? Icons.star_rounded : Icons.star_outline_rounded,
                color: item.favorite ? Colors.amber.shade600 : null,
              ),
              onPressed: () => ctrl.toggleFavorite(item.id),
            ),
          PopupMenuButton<String>(
            onSelected: (v) => _menu(v, item),
            itemBuilder: (_) => [
              if (!item.isTrashed) ...[
                const PopupMenuItem(value: 'clone', child: Text('Clone')),
                PopupMenuItem(value: 'archive', child: Text(item.archived ? 'Unarchive' : 'Archive')),
                const PopupMenuItem(value: 'trash', child: Text('Move to trash')),
              ] else ...[
                const PopupMenuItem(value: 'restore', child: Text('Restore')),
                const PopupMenuItem(value: 'delete', child: Text('Delete permanently')),
              ],
            ],
          ),
        ],
      ),
      floatingActionButton: item.isTrashed
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/item/${item.id}/edit'),
              child: const Icon(Icons.edit_rounded),
            ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
            child: Row(
              children: [
                ItemAvatar(name: item.name, icon: t.icon, size: 56),
                const SizedBox(width: AppTheme.space4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name.isEmpty ? 'Untitled' : item.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [t.label, if (item.folderId != null) folderPath(item.folderId!, vault)].join(' · '),
                        style: TextStyle(color: s.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (item.tagIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppTheme.space4, AppTheme.space3, AppTheme.space4, 0),
              child: Wrap(
                spacing: 6,
                children: [
                  for (final id in item.tagIds)
                    if (vault.tags[id] case final tag?)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: CircleAvatar(backgroundColor: Color(tag.color), radius: 5),
                        label: Text(tag.name),
                      ),
                ],
              ),
            ),
          if (item.isTrashed)
            Padding(
              padding: const EdgeInsets.all(AppTheme.space4),
              child: Card(
                color: s.errorContainer.withValues(alpha: 0.5),
                child: ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('In trash'),
                  subtitle: Text(
                    'Deleted permanently in ${(trashRetention - DateTime.now().toUtc().difference(item.trashedAt!)).inDays.clamp(0, 30)} days',
                  ),
                ),
              ),
            ),
          if (visibleFields.isNotEmpty) ...[
            const SectionHeader('Details'),
            _Group(
              children: [
                for (final spec in visibleFields)
                  FieldRow(
                    label: spec.label,
                    value: item.fields[spec.key]!,
                    sensitive: spec.isSensitive,
                    multiline: spec.isMultiline,
                    copyable: spec.copyable,
                    isUrl: spec.kind == FieldKind.url,
                    display: spec.kind == FieldKind.cardNumber ? formatCardNumber : null,
                    gate: () => _gate(item, spec),
                    authorized: !_needsAuth(item, spec),
                  ),
              ],
            ),
          ],
          if ((item.totp ?? '').isNotEmpty) ...[
            const SectionHeader('Authenticator'),
            _Group(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppTheme.space4),
                  child: TotpConfig.isValid(item.totp!)
                      ? TotpCodeView(config: TotpConfig.parse(item.totp!))
                      : Text('Invalid TOTP configuration', style: TextStyle(color: s.error)),
                ),
              ],
            ),
          ],
          if (item.uris.isNotEmpty) ...[
            const SectionHeader('Websites'),
            _Group(
              children: [
                for (final u in item.uris)
                  FieldRow(label: 'Website', value: u, isUrl: true, gate: () async => true, authorized: true),
              ],
            ),
          ],
          if (item.notes.isNotEmpty) ...[
            const SectionHeader('Notes'),
            _Group(
              children: [
                FieldRow(
                  label: 'Notes',
                  value: item.notes,
                  multiline: true,
                  sensitive: item.type == ItemType.secureNote && item.reprompt,
                  gate: () => _gate(item, null),
                  authorized: !_needsAuth(item, null),
                ),
              ],
            ),
          ],
          if (item.customFields.isNotEmpty) ...[
            const SectionHeader('Custom fields'),
            _Group(
              children: [
                for (final f in item.customFields)
                  f.type == CustomFieldType.boolean
                      ? ListTile(
                          title: Text(f.name),
                          trailing: Icon(
                            f.value == 'true' ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          ),
                        )
                      : FieldRow(
                          label: f.name,
                          value: f.value,
                          sensitive: f.isSensitive,
                          multiline: f.type == CustomFieldType.multiline,
                          isUrl: f.type == CustomFieldType.url,
                          gate: () => _gate(item, null),
                          authorized: !_needsAuth(item, null),
                        ),
              ],
            ),
          ],
          if (item.attachments.isNotEmpty) ...[
            const SectionHeader('Attachments'),
            _Group(
              children: [
                for (final a in item.attachments)
                  ListTile(
                    leading: Icon(_iconFor(a.mimeType)),
                    title: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${_size(a.size)} · ${DateFormat.yMMMd().format(a.createdAt.toLocal())}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      if (await _gate(item, null) && context.mounted) context.push('/attachment', extra: (item, a));
                    },
                  ),
              ],
            ),
          ],
          if (item.passwordHistory.isNotEmpty && settings.passwordHistoryEnabled) ...[
            const SectionHeader('Password history'),
            _Group(
              children: [
                for (final h in item.passwordHistory)
                  FieldRow(
                    label: DateFormat.yMMMd().add_jm().format(h.changedAt.toLocal()),
                    value: h.password,
                    sensitive: true,
                    gate: () => _gate(item, null),
                    authorized: !_needsAuth(item, null),
                  ),
              ],
            ),
          ],
          const SectionHeader('Item information'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
            child: DefaultTextStyle(
              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: s.onSurfaceVariant),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Created ${df.format(item.createdAt.toLocal())}'),
                  Text('Updated ${df.format(item.updatedAt.toLocal())}'),
                  if (item.passwordUpdatedAt != null)
                    Text('Password updated ${df.format(item.passwordUpdatedAt!.toLocal())}'),
                  if (item.reprompt) const Text('Re-authentication required to reveal secrets'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _menu(String v, VaultItem item) async {
    final ctrl = ref.read(vaultProvider.notifier);
    switch (v) {
      case 'clone':
        final now = DateTime.now().toUtc();
        final copy = await ctrl.saveItem(
          item.copyWith(
            id: newId(),
            name: '${item.name} (copy)',
            createdAt: now,
            attachments: const [],
            passwordHistory: const [],
            seq: 0,
          ),
        );
        if (mounted) context.replace('/item/${copy.id}');
      case 'archive':
        await ctrl.setArchived([item.id], !item.archived);
      case 'trash':
        await ctrl.moveToTrash([item.id]);
        if (mounted) context.pop();
      case 'restore':
        await ctrl.restore([item.id]);
      case 'delete':
        final ok = await confirmDialog(
          context,
          title: 'Delete permanently?',
          message: '"${item.name}" will be deleted forever, including its attachments.',
          confirm: 'Delete',
          destructive: true,
        );
        if (!ok) return;
        await ctrl.deleteForever([item.id], deleteAttachments: ref.read(attachmentServiceProvider).deleteAllFor);
        if (mounted) context.pop();
    }
  }

  static IconData _iconFor(String mime) {
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mime.startsWith('text/')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  static String _size(int b) => b < 1024
      ? '$b B'
      : b < 1024 * 1024
      ? '${(b / 1024).toStringAsFixed(1)} KB'
      : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppTheme.space4),
    child: Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            children[i],
          ],
        ],
      ),
    ),
  );
}

/// One field: label, value (masked if sensitive), reveal + copy actions.
class FieldRow extends ConsumerStatefulWidget {
  const FieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.gate,
    required this.authorized,
    this.sensitive = false,
    this.multiline = false,
    this.copyable = true,
    this.isUrl = false,
    this.display,
  });

  final String label;
  final String value;
  final bool sensitive;
  final bool multiline;
  final bool copyable;
  final bool isUrl;
  final bool authorized;
  final String Function(String)? display;
  final Future<bool> Function() gate;

  @override
  ConsumerState<FieldRow> createState() => _FieldRowState();
}

class _FieldRowState extends ConsumerState<FieldRow> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final shown = widget.display?.call(widget.value) ?? widget.value;
    final masked = widget.sensitive && !_revealed;
    return ListTile(
      title: Text(widget.label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: s.onSurfaceVariant)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: masked
            ? Text(
                widget.multiline ? '•••••••• •••••• ••••••••' : '••••••••••••',
                style: Theme.of(context).textTheme.bodyLarge,
              )
            : widget.sensitive
            ? SecretText(shown)
            : SelectableText(shown, style: Theme.of(context).textTheme.bodyLarge),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.sensitive)
            IconButton(
              tooltip: _revealed ? 'Hide' : 'Reveal',
              icon: Icon(_revealed ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              onPressed: () async {
                if (!_revealed && !await widget.gate()) return;
                setState(() => _revealed = !_revealed);
              },
            ),
          if (widget.isUrl)
            IconButton(
              tooltip: 'Open',
              icon: const Icon(Icons.open_in_new_rounded),
              onPressed: () {
                final raw = widget.value.contains('://') ? widget.value : 'https://${widget.value}';
                final uri = Uri.tryParse(raw);
                if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          if (widget.copyable)
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () async {
                if (widget.sensitive && !await widget.gate()) return;
                if (!context.mounted) return;
                await copySecret(context, ref, widget.value, widget.label, sensitive: widget.sensitive);
              },
            ),
        ],
      ),
    );
  }
}
