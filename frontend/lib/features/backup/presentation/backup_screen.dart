import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/common_widgets.dart';
import '../../../app/lock_guard.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/crypto/crypto_exceptions.dart';
import '../../settings/settings_controller.dart';
import '../../vault/application/vault_controller.dart';
import '../../vault/domain/item_type.dart';
import '../backup_format.dart';
import '../backup_service.dart';
import '../import_export.dart';

final _localBackupsProvider = FutureProvider.autoDispose((ref) => ref.read(backupServiceProvider).listLocal());

class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(settingsProvider);
    final backups = ref.watch(_localBackupsProvider);
    final cloudReady = ref.watch(objectStorageProvider).available && ref.watch(cloudUserProvider).value != null;
    final svc = ref.read(backupServiceProvider);

    Future<void> busy(Future<void> Function() fn, String done) async {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      try {
        await fn();
        if (context.mounted) {
          Navigator.pop(context);
          showInfo(context, done);
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          showError(context, e);
        }
      }
      ref.invalidate(_localBackupsProvider);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Backup, export & import')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          const SectionHeader('Encrypted backups'),
          SwitchListTile(
            secondary: const Icon(Icons.schedule_rounded),
            title: const Text('Automatic daily backup'),
            subtitle: Text('Keeps the last ${st.autoBackupKeep}, encrypted with your vault key'),
            value: st.autoBackupEnabled,
            onChanged: (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(autoBackupEnabled: v)),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt_rounded),
            title: const Text('Back up now'),
            subtitle: const Text('Includes attachments. Restorable with your master password.'),
            onTap: () => busy(() async {
              final f = await svc.createLocalBackup();
              if (cloudReady) await svc.uploadToCloud(f);
            }, cloudReady ? 'Backup saved on this device and in the cloud' : 'Backup saved on this device'),
          ),
          ListTile(
            leading: const Icon(Icons.restore_rounded),
            title: const Text('Restore from a file'),
            subtitle: const Text('.citadel archives (backups or encrypted exports)'),
            onTap: () => _restoreFromPicker(context, ref),
          ),
          backups.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ListTile(title: Text('$e')),
            data: (list) => Column(
              children: [
                for (final b in list)
                  ListTile(
                    dense: true,
                    leading: Icon(b.name.contains('-auto') ? Icons.schedule_rounded : Icons.inventory_2_outlined),
                    title: Text(DateFormat.yMMMd().add_jm().format(b.modified)),
                    subtitle: Text(
                      '${b.name.split('-').skip(3).join('-').replaceAll('.citadel', '')} · ${(b.size / 1024).toStringAsFixed(0)} KB',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        switch (v) {
                          case 'verify':
                            final data = await b.file.readAsBytes();
                            if (context.mounted) await _verify(context, ref, data);
                          case 'restore':
                            final data = await b.file.readAsBytes();
                            if (context.mounted) await _restore(context, ref, data);
                          case 'save':
                            await LockGuard.run(
                              ref,
                              () => FilePicker.saveFile(fileName: b.name, bytes: b.file.readAsBytesSync()),
                            );
                          case 'delete':
                            await b.file.delete();
                            ref.invalidate(_localBackupsProvider);
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'verify', child: Text('Verify integrity')),
                        PopupMenuItem(value: 'restore', child: Text('Restore')),
                        PopupMenuItem(value: 'save', child: Text('Save a copy...')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SectionHeader('Export'),
          ListTile(
            leading: const Icon(Icons.enhanced_encryption_outlined),
            title: const Text('Encrypted export (recommended)'),
            subtitle: const Text('Password-protected .citadel archive, includes attachments'),
            onTap: () => _export(context, ref, 'encrypted'),
          ),
          ListTile(
            leading: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
            title: const Text('Unencrypted JSON'),
            subtitle: const Text('Plaintext - readable by anyone with the file'),
            onTap: () => _export(context, ref, 'json'),
          ),
          ListTile(
            leading: Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.error),
            title: const Text('Unencrypted CSV (Bitwarden format)'),
            subtitle: const Text('Plaintext, logins & notes'),
            onTap: () => _export(context, ref, 'csv'),
          ),
          const SectionHeader('Import'),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Import from file'),
            subtitle: const Text('Citadel (.citadel / JSON), Bitwarden JSON (unencrypted) or Bitwarden CSV'),
            onTap: () => _import(context, ref),
          ),
          const Padding(
            padding: EdgeInsets.all(AppTheme.space4),
            child: Text(
              'Backups and exports you save outside the app cannot be deleted remotely. '
              'A cloud replica is not a backup: if you delete something, sync deletes it everywhere - '
              'your encrypted backups are what let you go back in time.',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _verify(BuildContext context, WidgetRef ref, Uint8List data, {String? password}) async {
    try {
      final v = await ref.read(backupServiceProvider).verify(data, password: password);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.verified_rounded, color: Colors.green),
          title: const Text('Backup is intact'),
          content: Text(
            'Created ${DateFormat.yMMMd().add_jm().format(v.header.createdAt.toLocal())}\n'
            '${v.items} items · ${v.folders} folders · ${v.tags} tags · ${v.attachments} attachments'
            '${v.missingAttachments > 0 ? '\n${v.missingAttachments} attachment(s) were unavailable when backed up' : ''}',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
    } on PasswordRequiredException catch (e) {
      if (!context.mounted) return;
      final pw = await promptText(
        context,
        title: 'Password required',
        label: e.toString(),
        obscure: true,
        confirm: 'Verify',
      );
      if (pw != null && context.mounted) await _verify(context, ref, data, password: pw);
    } on DecryptionFailedException catch (e) {
      if (context.mounted) showError(context, 'Verification failed: ${e.message}');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _restore(BuildContext context, WidgetRef ref, Uint8List data, {String? password}) async {
    final mode = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text('Restore backup'),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text('A safety backup of your current vault is taken first.'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, 'merge'),
            child: const ListTile(
              title: Text('Merge'),
              subtitle: Text('Add/overwrite items from the backup, keep everything else'),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(c, 'replace'),
            child: const ListTile(
              title: Text('Replace'),
              subtitle: Text('Current items not in the backup move to Trash'),
            ),
          ),
        ],
      ),
    );
    if (mode == null || !context.mounted) return;
    try {
      final n = await ref.read(backupServiceProvider).restore(data, password: password, replace: mode == 'replace');
      if (context.mounted) showInfo(context, 'Restored $n items.');
    } on PasswordRequiredException catch (e) {
      if (!context.mounted) return;
      final pw = await promptText(
        context,
        title: 'Password required',
        label: e.toString(),
        obscure: true,
        confirm: 'Restore',
      );
      if (pw != null && context.mounted) await _restore(context, ref, data, password: pw);
    } on DecryptionFailedException catch (e) {
      if (context.mounted) showError(context, 'Restore failed: ${e.message}');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _restoreFromPicker(BuildContext context, WidgetRef ref) async {
    final files = await LockGuard.run(ref, () => FilePicker.pickFiles(dialogTitle: 'Choose a .citadel file'));
    if (files.isEmpty) return;
    final data = await files.first.readAsBytes();
    if (context.mounted) await _restore(context, ref, data);
  }

  Future<ExportSelection?> _chooseSelection(BuildContext context, WidgetRef ref) async {
    final vault = ref.read(vaultProvider);
    final types = <ItemType>{};
    final folders = <String>{};
    return showModalBottomSheet<ExportSelection>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppTheme.space4),
            children: [
              Text('What to export', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(c, const ExportSelection.all()),
                child: const Text('Entire vault'),
              ),
              const SectionHeader('Or only these types'),
              Wrap(
                spacing: 6,
                children: [
                  for (final t in ItemType.values)
                    FilterChip(
                      label: Text(t.template.label),
                      selected: types.contains(t),
                      onSelected: (v) => set(() => v ? types.add(t) : types.remove(t)),
                    ),
                ],
              ),
              if (vault.folders.isNotEmpty) ...[
                const SectionHeader('And/or these folders'),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final f in vault.folders.values)
                      FilterChip(
                        label: Text(f.name),
                        selected: folders.contains(f.id),
                        onSelected: (v) => set(() => v ? folders.add(f.id) : folders.remove(f.id)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: types.isEmpty && folders.isEmpty
                    ? null
                    : () => Navigator.pop(
                        c,
                        ExportSelection(
                          types: types.isEmpty ? null : types,
                          folderIds: folders.isEmpty ? null : folders,
                        ),
                      ),
                child: const Text('Export selection'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref, String kind) async {
    final selection = await _chooseSelection(context, ref);
    if (selection == null || !context.mounted) return;
    final stamp = DateFormat('yyyyMMdd').format(DateTime.now());
    final vault = ref.read(vaultProvider);
    final items = selection.apply(vault.items.values);
    try {
      if (kind == 'encrypted') {
        final pw = await promptText(
          context,
          title: 'Export password',
          label: 'At least 8 characters - you will need it to import',
          obscure: true,
          confirm: 'Next',
        );
        if (pw == null || !context.mounted) return;
        final again = await promptText(
          context,
          title: 'Confirm export password',
          label: 'Export password',
          obscure: true,
          confirm: 'Export',
        );
        if (again != pw) {
          if (context.mounted) showError(context, 'Passwords do not match.');
          return;
        }
        final bytes = await ref.read(backupServiceProvider).exportEncrypted(pw, selection);
        await LockGuard.run(ref, () => FilePicker.saveFile(fileName: 'citadel-export-$stamp.citadel', bytes: bytes));
        return;
      }
      if (!context.mounted) return;
      final ok = await typedConfirmDialog(
        context,
        title: 'Export unencrypted?',
        message:
            'This creates a plaintext file containing ${items.length} items, including passwords, card numbers and '
            'TOTP secrets. Anyone who gets the file - or any app or cloud service it is synced to - can read '
            'everything. Delete it as soon as you are done.',
        word: 'EXPORT',
      );
      if (!ok) return;
      final text = kind == 'json'
          ? Exporters.citadelJson(
              items: items,
              folders: vault.folders.values.toList(),
              tags: vault.tags.values.toList(),
            )
          : Exporters.bitwardenCsv(items: items, folders: vault.folders);
      // Written straight to the user's chosen location via the system file
      // dialog - never staged in a temporary file.
      await LockGuard.run(
        ref,
        () => FilePicker.saveFile(
          fileName: 'citadel-export-$stamp.${kind == 'json' ? 'json' : 'csv'}',
          bytes: Uint8List.fromList(utf8.encode(text)),
          mimeType: kind == 'json' ? 'application/json' : 'text/csv',
        ),
      );
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final files = await LockGuard.run(ref, () => FilePicker.pickFiles(dialogTitle: 'Choose a file to import'));
    if (files.isEmpty || !context.mounted) return;
    final bytes = await files.first.readAsBytes();
    if (!context.mounted) return;
    try {
      // Encrypted Citadel archives restore via the backup path.
      if (bytes.length > ArchiveFormat.magic.length &&
          utf8.decode(bytes.sublist(0, ArchiveFormat.magic.length), allowMalformed: true) ==
              utf8.decode(ArchiveFormat.magic)) {
        await _restore(context, ref, bytes);
        return;
      }
      final result = Importers.parseAny(utf8.decode(bytes));
      bytes.fillRange(0, bytes.length, 0);
      if (!context.mounted) return;
      final ok = await confirmDialog(
        context,
        title: 'Import ${result.items.length} items?',
        message:
            '${result.folders.length} folder(s) will be created.'
            '${result.warnings.isEmpty ? '' : '\n\n${result.warnings.take(5).join('\n')}'}'
            '\n\nAfterwards, securely delete the source file if it was unencrypted.',
        confirm: 'Import',
      );
      if (!ok) return;
      await ref.read(vaultProvider.notifier).importAll(items: result.items, folders: result.folders, tags: result.tags);
      if (context.mounted) showInfo(context, 'Imported ${result.items.length} items.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}
