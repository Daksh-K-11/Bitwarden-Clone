import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/common_widgets.dart';
import '../../../app/lock_guard.dart';
import '../../../app/theme.dart';
import '../../attachments/attachment_service.dart';
import '../../generator/presentation/generator_screen.dart';
import '../../settings/settings_controller.dart';
import '../../totp/domain/totp.dart';
import '../../totp/presentation/totp_widgets.dart';
import '../application/vault_controller.dart';
import '../domain/item_type.dart';
import '../domain/vault_models.dart';
import 'item_widgets.dart';
import 'vault_screen.dart' show folderPath;

class ItemEditScreen extends ConsumerStatefulWidget {
  const ItemEditScreen({super.key, this.itemId, this.newType, this.folderId, this.prefill = const {}});
  final String? itemId;
  final ItemType? newType;
  final String? folderId;

  /// Pre-filled values for new items: `totp` (from the QR scanner),
  /// `password` / `username` (from the generator).
  final Map<String, String> prefill;

  String? get totpUri => prefill['totp'];

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  late VaultItem _item;
  late final bool _isNew;
  final _name = TextEditingController();
  final _notes = TextEditingController();
  final _fields = <String, TextEditingController>{};
  final _uris = <TextEditingController>[];
  final _cfName = <String, TextEditingController>{};
  final _cfValue = <String, TextEditingController>{};
  final _obscured = <String>{};
  final _addedAttachments = <AttachmentMeta>[];
  final _removedAttachments = <AttachmentMeta>[];
  bool _dirty = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final vault = ref.read(vaultProvider);
    final existing = widget.itemId == null ? null : vault.items[widget.itemId];
    _isNew = existing == null;
    _item =
        existing ?? ref.read(vaultProvider.notifier).draft(widget.newType ?? ItemType.login, folderId: widget.folderId);
    if (widget.totpUri != null) {
      _item = _item.copyWith(totp: widget.totpUri);
      final cfg = TotpConfig.parse(widget.totpUri!);
      if (_item.name.isEmpty) _item = _item.copyWith(name: cfg.issuer ?? cfg.account ?? '');
      if (cfg.account != null && (_item.fields['username'] ?? '').isEmpty) {
        _item = _item.copyWith(fields: {..._item.fields, 'username': cfg.account!});
      }
    }
    if (_isNew) {
      final extra = {
        for (final k in ['password', 'username'])
          if (widget.prefill[k] != null) k: widget.prefill[k]!,
      };
      if (extra.isNotEmpty) _item = _item.copyWith(fields: {..._item.fields, ...extra});
    }
    _name.text = _item.name;
    _notes.text = _item.notes;
    for (final spec in _item.type.template.fields) {
      _fields[spec.key] = TextEditingController(text: _item.fields[spec.key] ?? '');
      if (spec.isSensitive) _obscured.add(spec.key);
    }
    for (final u in _item.uris) {
      _uris.add(TextEditingController(text: u));
    }
    if (_item.type.template.supportsUris && _uris.isEmpty) _uris.add(TextEditingController());
    for (final f in _item.customFields) {
      _cfName[f.id] = TextEditingController(text: f.name);
      _cfValue[f.id] = TextEditingController(text: f.value);
      if (f.isSensitive) _obscured.add(f.id);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _notes, ..._fields.values, ..._uris, ..._cfName.values, ..._cfValue.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _touch() {
    if (!_dirty) setState(() => _dirty = true);
  }

  VaultItem _collect() {
    final fields = <String, String>{};
    _fields.forEach((k, c) {
      var v = c.text;
      if (_item.type.template.spec(k)?.kind == FieldKind.cardNumber) v = v.replaceAll(RegExp(r'\D'), '');
      if (v.trim().isNotEmpty) fields[k] = v;
    });
    return _item.copyWith(
      name: _name.text.trim(),
      notes: _notes.text,
      fields: fields,
      uris: [
        for (final u in _uris)
          if (u.text.trim().isNotEmpty) u.text.trim(),
      ],
      customFields: [
        for (final f in _item.customFields)
          f.copyWith(
            name: _cfName[f.id]!.text.trim(),
            value: f.type == CustomFieldType.boolean ? f.value : _cfValue[f.id]!.text,
          ),
      ],
    );
  }

  Future<void> _save() async {
    final item = _collect();
    if (item.name.isEmpty) {
      showError(context, 'Give this item a name.');
      return;
    }
    if ((item.totp ?? '').isNotEmpty && !TotpConfig.isValid(item.totp!)) {
      showError(context, 'The authenticator key is invalid.');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref.read(vaultProvider.notifier).saveItem(item);
      final svc = ref.read(attachmentServiceProvider);
      for (final a in _removedAttachments) {
        await svc.delete(a);
      }
      _dirty = false;
      if (!mounted) return;
      if (_isNew) {
        context.pushReplacement('/item/${saved.id}');
      } else {
        context.pop();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discardAdded() async {
    final svc = ref.read(attachmentServiceProvider);
    for (final a in _addedAttachments) {
      await svc.delete(a);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _item.type.template;
    final settings = ref.watch(settingsProvider);
    final vault = ref.watch(vaultProvider);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) {
          await _discardAdded();
          return;
        }
        final leave = await confirmDialog(
          context,
          title: 'Discard changes?',
          message: 'Your edits will be lost.',
          confirm: 'Discard',
          destructive: true,
        );
        if (leave && context.mounted) {
          await _discardAdded();
          _dirty = false;
          if (context.mounted) context.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isNew ? 'New ${t.label.toLowerCase()}' : 'Edit ${t.label.toLowerCase()}'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(80, 40)),
                onPressed: _saving ? null : _save,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(AppTheme.space4, AppTheme.space3, AppTheme.space4, 120),
          children: [
            TextField(
              controller: _name,
              autofocus: _isNew && widget.totpUri == null,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => _touch(),
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: AppTheme.space3),
            for (final spec in t.fields)
              if (spec.requiresSetting == null ||
                  settings.isEnabled(spec.requiresSetting!) ||
                  _fields[spec.key]!.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space3),
                  child: _field(spec),
                ),
            if (_item.type == ItemType.card && !settings.allowCvvStorage)
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.space3),
                child: Text(
                  'Security code (CVV) storage is off. You can enable it in Settings > Security, after reading the risks.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (t.supportsUris) ..._uriEditors(),
            if (t.supportsTotp) _totpEditor(),
            const SizedBox(height: AppTheme.space2),
            TextField(
              controller: _notes,
              minLines: _item.type == ItemType.secureNote ? 8 : 3,
              maxLines: null,
              onChanged: (_) => _touch(),
              decoration: const InputDecoration(labelText: 'Notes', alignLabelWithHint: true),
            ),
            const SectionHeader('Custom fields'),
            _customFieldsEditor(),
            const SectionHeader('Organize'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_outlined),
              title: Text(_item.folderId == null ? 'No folder' : folderPath(_item.folderId!, vault)),
              trailing: const Icon(Icons.expand_more_rounded),
              onTap: _pickFolder,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.sell_outlined),
              title: _item.tagIds.isEmpty
                  ? const Text('No tags')
                  : Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final id in _item.tagIds)
                          if (vault.tags[id] case final tag?)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: CircleAvatar(backgroundColor: Color(tag.color), radius: 5),
                              label: Text(tag.name),
                            ),
                      ],
                    ),
              trailing: const Icon(Icons.expand_more_rounded),
              onTap: _pickTags,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.star_outline_rounded),
              title: const Text('Favorite'),
              value: _item.favorite,
              onChanged: (v) => setState(() {
                _item = _item.copyWith(favorite: v);
                _dirty = true;
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.verified_user_outlined),
              title: const Text('Re-authenticate to reveal'),
              subtitle: const Text('Require fingerprint or device PIN before showing or copying secrets'),
              value: _item.reprompt,
              onChanged: (v) => setState(() {
                _item = _item.copyWith(reprompt: v);
                _dirty = true;
              }),
            ),
            const SectionHeader('Attachments'),
            _attachmentsEditor(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ fields

  Widget _field(FieldSpec spec) {
    final c = _fields[spec.key]!;
    final obscured = _obscured.contains(spec.key);
    final helper = spec.warning;

    switch (spec.kind) {
      case FieldKind.select:
        final options = [...spec.options];
        if (c.text.isNotEmpty && !options.contains(c.text)) options.add(c.text);
        return DropdownButtonFormField<String>(
          initialValue: c.text.isEmpty ? null : c.text,
          isExpanded: true,
          decoration: InputDecoration(labelText: spec.label),
          items: [
            const DropdownMenuItem(value: '', child: Text('—')),
            for (final o in options) DropdownMenuItem(value: o, child: Text(o)),
          ],
          onChanged: (v) {
            c.text = v ?? '';
            _touch();
          },
        );
      case FieldKind.month:
        return DropdownButtonFormField<String>(
          initialValue: c.text.isEmpty ? null : c.text.padLeft(2, '0'),
          decoration: InputDecoration(labelText: spec.label),
          items: [
            for (var m = 1; m <= 12; m++)
              DropdownMenuItem(value: '$m'.padLeft(2, '0'), child: Text('$m'.padLeft(2, '0'))),
          ],
          onChanged: (v) {
            c.text = v ?? '';
            _touch();
          },
        );
      case FieldKind.year:
        final now = DateTime.now().year;
        final years = [for (var y = now - 10; y <= now + 20; y++) '$y'];
        if (c.text.isNotEmpty && !years.contains(c.text)) years.insert(0, c.text);
        return DropdownButtonFormField<String>(
          initialValue: c.text.isEmpty ? null : c.text,
          decoration: InputDecoration(labelText: spec.label),
          items: [for (final y in years) DropdownMenuItem(value: y, child: Text(y))],
          onChanged: (v) {
            c.text = v ?? '';
            _touch();
          },
        );
      case FieldKind.date:
        return TextField(
          controller: c,
          readOnly: true,
          decoration: InputDecoration(
            labelText: spec.label,
            suffixIcon: c.text.isEmpty
                ? const Icon(Icons.calendar_today_rounded)
                : IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => setState(() {
                      c.clear();
                      _dirty = true;
                    }),
                  ),
          ),
          onTap: () async {
            final initial = DateTime.tryParse(c.text) ?? DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (d != null) {
              setState(() {
                c.text = DateFormat('yyyy-MM-dd').format(d);
                _dirty = true;
              });
            }
          },
        );
      default:
        final isPassword = spec.kind == FieldKind.password;
        final multiline = spec.isMultiline;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: c,
              obscureText: obscured && !multiline,
              enableSuggestions: !spec.isSensitive,
              autocorrect: !spec.isSensitive,
              minLines: multiline ? (obscured ? 1 : 3) : 1,
              maxLines: multiline ? (obscured ? 1 : null) : 1,
              style: spec.isSensitive && !obscured ? const TextStyle(fontFamily: 'monospace') : null,
              keyboardType: switch (spec.kind) {
                FieldKind.email => TextInputType.emailAddress,
                FieldKind.url => TextInputType.url,
                FieldKind.phone => TextInputType.phone,
                FieldKind.number || FieldKind.cardNumber => TextInputType.number,
                _ => multiline ? TextInputType.multiline : TextInputType.text,
              },
              inputFormatters: spec.kind == FieldKind.cardNumber
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[\d ]')), LengthLimitingTextInputFormatter(23)]
                  : null,
              onChanged: (v) {
                if (spec.kind == FieldKind.cardNumber) {
                  final brand = detectCardBrand(v);
                  if (brand != null && (_fields['brand']?.text.isEmpty ?? false)) {
                    setState(() => _fields['brand']!.text = brand);
                  }
                }
                if (isPassword) setState(() {});
                _touch();
              },
              decoration: InputDecoration(
                labelText: spec.label,
                hintText: spec.hint,
                helperText: helper,
                helperMaxLines: 5,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (spec.isSensitive)
                      IconButton(
                        icon: Icon(obscured ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        onPressed: () =>
                            setState(() => obscured ? _obscured.remove(spec.key) : _obscured.add(spec.key)),
                      ),
                    if (isPassword)
                      IconButton(
                        tooltip: 'Generate',
                        icon: const Icon(Icons.auto_awesome_rounded),
                        onPressed: () async {
                          final v = await showGeneratorSheet(context);
                          if (v != null) {
                            setState(() {
                              c.text = v;
                              _dirty = true;
                            });
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),
            if (isPassword) StrengthMeter(password: c.text),
          ],
        );
    }
  }

  List<Widget> _uriEditors() => [
    for (var i = 0; i < _uris.length; i++)
      Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.space3),
        child: TextField(
          controller: _uris[i],
          keyboardType: TextInputType.url,
          autocorrect: false,
          onChanged: (_) => _touch(),
          decoration: InputDecoration(
            labelText: 'Website (URL)',
            hintText: 'https://example.com',
            suffixIcon: IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded),
              onPressed: () => setState(() {
                _uris.removeAt(i).dispose();
                _dirty = true;
              }),
            ),
          ),
        ),
      ),
    Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => setState(() => _uris.add(TextEditingController())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add website'),
      ),
    ),
  ];

  Widget _totpEditor() {
    final totp = _item.totp;
    final valid = totp != null && TotpConfig.isValid(totp);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: AppTheme.space2),
                Expanded(child: Text('Authenticator key (TOTP)', style: Theme.of(context).textTheme.titleSmall)),
                if (totp != null)
                  IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => setState(() {
                      _item = _item.copyWith(totp: null);
                      _dirty = true;
                    }),
                  ),
              ],
            ),
            if (valid) ...[
              TotpCodeView(config: TotpConfig.parse(totp), compact: true),
              Text(_describeTotp(TotpConfig.parse(totp)), style: Theme.of(context).textTheme.bodySmall),
            ] else
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan QR'),
                    onPressed: () async {
                      final uri = await LockGuard.run(ref, () async => context.push<String>('/scan', extra: 'return'));
                      if (uri != null) {
                        setState(() {
                          _item = _item.copyWith(totp: uri);
                          _dirty = true;
                        });
                      }
                    },
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                    icon: const Icon(Icons.keyboard_rounded),
                    label: const Text('Enter key'),
                    onPressed: () async {
                      final v = await showTotpEntryDialog(context);
                      if (v != null) {
                        setState(() {
                          _item = _item.copyWith(totp: v);
                          _dirty = true;
                        });
                      }
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  static String _describeTotp(TotpConfig c) => [
    c.algorithm.name.toUpperCase(),
    '${c.digits} digits',
    '${c.period}s',
    if (c.issuer != null) c.issuer!,
    if (c.account != null) c.account!,
  ].join(' · ');

  Widget _customFieldsEditor() {
    final fields = _item.customFields;
    return Column(
      children: [
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorderItem: (a, b) => setState(() {
            final list = [...fields];
            final f = list.removeAt(a);
            list.insert(b, f);
            _item = _item.copyWith(customFields: list);
            _dirty = true;
          }),
          children: [
            for (var i = 0; i < fields.length; i++)
              Padding(
                key: ValueKey(fields[i].id),
                padding: const EdgeInsets.only(bottom: AppTheme.space3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.only(top: 14, right: 4),
                        child: Icon(Icons.drag_indicator_rounded),
                      ),
                    ),
                    Expanded(child: _customFieldRow(fields[i])),
                  ],
                ),
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<CustomFieldType>(
            onSelected: (type) => setState(() {
              final f = CustomField(
                id: newId(),
                name: '',
                type: type,
                value: type == CustomFieldType.boolean ? 'false' : '',
              );
              _cfName[f.id] = TextEditingController();
              _cfValue[f.id] = TextEditingController(text: f.value);
              if (f.isSensitive) _obscured.add(f.id);
              _item = _item.copyWith(customFields: [...fields, f]);
              _dirty = true;
            }),
            itemBuilder: (_) => [
              for (final t in CustomFieldType.values) PopupMenuItem(value: t, child: Text(_cfLabel(t))),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Icon(Icons.add_rounded), SizedBox(width: 8), Text('Add field')],
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _cfLabel(CustomFieldType t) => switch (t) {
    CustomFieldType.text => 'Text',
    CustomFieldType.hidden => 'Hidden',
    CustomFieldType.boolean => 'Checkbox',
    CustomFieldType.url => 'URL',
    CustomFieldType.email => 'Email',
    CustomFieldType.date => 'Date',
    CustomFieldType.number => 'Number',
    CustomFieldType.multiline => 'Multiline text',
  };

  Widget _customFieldRow(CustomField f) {
    final obscured = _obscured.contains(f.id);
    void remove() => setState(() {
      _item = _item.copyWith(customFields: _item.customFields.where((x) => x.id != f.id).toList());
      _dirty = true;
    });
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space2),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cfName[f.id],
                    onChanged: (_) => _touch(),
                    decoration: InputDecoration(labelText: 'Field name', helperText: _cfLabel(f.type), isDense: true),
                  ),
                ),
                IconButton(icon: const Icon(Icons.delete_outline_rounded), onPressed: remove),
              ],
            ),
            const SizedBox(height: AppTheme.space2),
            if (f.type == CustomFieldType.boolean)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Value'),
                value: f.value == 'true',
                onChanged: (v) => setState(() {
                  _item = _item.copyWith(
                    customFields: [for (final x in _item.customFields) x.id == f.id ? x.copyWith(value: '$v') : x],
                  );
                  _dirty = true;
                }),
              )
            else
              TextField(
                controller: _cfValue[f.id],
                obscureText: obscured,
                enableSuggestions: f.type != CustomFieldType.hidden,
                autocorrect: f.type != CustomFieldType.hidden,
                minLines: f.type == CustomFieldType.multiline ? 3 : 1,
                maxLines: f.type == CustomFieldType.multiline ? null : 1,
                keyboardType: switch (f.type) {
                  CustomFieldType.email => TextInputType.emailAddress,
                  CustomFieldType.url => TextInputType.url,
                  CustomFieldType.number => TextInputType.number,
                  CustomFieldType.date => TextInputType.datetime,
                  CustomFieldType.multiline => TextInputType.multiline,
                  _ => TextInputType.text,
                },
                onChanged: (_) => _touch(),
                decoration: InputDecoration(
                  labelText: 'Value',
                  isDense: true,
                  suffixIcon: f.isSensitive
                      ? IconButton(
                          icon: Icon(obscured ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                          onPressed: () => setState(() => obscured ? _obscured.remove(f.id) : _obscured.add(f.id)),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentsEditor() {
    final max = ref.watch(settingsProvider).attachmentMaxMb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final a in _item.attachments)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(a.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${(a.size / 1024).toStringAsFixed(1)} KB'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => setState(() {
                _item = _item.copyWith(attachments: _item.attachments.where((x) => x.id != a.id).toList());
                if (_addedAttachments.remove(a)) {
                  ref.read(attachmentServiceProvider).delete(a);
                } else {
                  _removedAttachments.add(a);
                }
                _dirty = true;
              }),
            ),
          ),
        TextButton.icon(
          icon: const Icon(Icons.attach_file_rounded),
          label: Text('Add attachment (max $max MB)'),
          onPressed: () async {
            try {
              final files = await LockGuard.run(ref, () => FilePicker.pickFiles(dialogTitle: 'Attach file'));
              if (files.isEmpty) return;
              final f = files.first;
              final size = await f.length() ?? 0;
              if (size > max * 1024 * 1024) throw AttachmentException('File exceeds the $max MB limit');
              final bytes = await f.readAsBytes();
              final meta = await ref
                  .read(attachmentServiceProvider)
                  .add(itemId: _item.id, fileName: f.name, bytes: bytes);
              bytes.fillRange(0, bytes.length, 0);
              setState(() {
                _addedAttachments.add(meta);
                _item = _item.copyWith(attachments: [..._item.attachments, meta]);
                _dirty = true;
              });
            } catch (e) {
              if (mounted) showError(context, e);
            }
          },
        ),
        Text(
          'Files are encrypted on this device before being stored or uploaded. Files are never opened or executed automatically.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _pickFolder() async {
    final vault = ref.read(vaultProvider);
    final folders = vault.folders.values.toList()
      ..sort((a, b) => folderPath(a.id, vault).compareTo(folderPath(b.id, vault)));
    final r = await showModalBottomSheet<String>(
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
                title: Text(folderPath(f.id, vault)),
                selected: f.id == _item.folderId,
                onTap: () => Navigator.pop(c, f.id),
              ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder...'),
              onTap: () async {
                final name = await promptText(c, title: 'New folder');
                if (name == null || name.trim().isEmpty) return;
                final f = await ref.read(vaultProvider.notifier).saveFolder(name: name);
                if (c.mounted) Navigator.pop(c, f.id);
              },
            ),
          ],
        ),
      ),
    );
    if (r == null) return;
    setState(() {
      _item = _item.copyWith(folderId: r.isEmpty ? null : r);
      _dirty = true;
    });
  }

  Future<void> _pickTags() async {
    final selected = {..._item.tagIds};
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) {
          final tags = ref.read(vaultProvider).tags.values.toList()..sort((a, b) => a.name.compareTo(b.name));
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final t in tags)
                  CheckboxListTile(
                    secondary: CircleAvatar(backgroundColor: Color(t.color), radius: 8),
                    title: Text(t.name),
                    value: selected.contains(t.id),
                    onChanged: (v) => set(() => v == true ? selected.add(t.id) : selected.remove(t.id)),
                  ),
                ListTile(
                  leading: const Icon(Icons.add_rounded),
                  title: const Text('New tag...'),
                  onTap: () async {
                    final name = await promptText(c, title: 'New tag');
                    if (name == null || name.trim().isEmpty) return;
                    final t = await ref
                        .read(vaultProvider.notifier)
                        .saveTag(name: name, color: tagPalette[tags.length % tagPalette.length]);
                    set(() => selected.add(t.id));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
    setState(() {
      _item = _item.copyWith(tagIds: selected.toList());
      _dirty = true;
    });
  }
}

const tagPalette = [0xFF6366F1, 0xFF0EA5E9, 0xFF10B981, 0xFFF59E0B, 0xFFEF4444, 0xFFEC4899, 0xFF8B5CF6, 0xFF64748B];

/// Manual TOTP entry: accepts an otpauth:// URI or a base32 secret, with
/// algorithm/digits/period options and a live preview before saving.
Future<String?> showTotpEntryDialog(BuildContext context) => showDialog<String>(
  context: context,
  builder: (c) {
    final secret = TextEditingController();
    var alg = TotpAlgorithm.sha1;
    var digits = 6;
    var period = 30;
    String? error;
    TotpConfig? preview;
    return StatefulBuilder(
      builder: (c, set) {
        void validate() {
          try {
            final raw = secret.text.trim();
            final cfg = raw.toLowerCase().startsWith('otpauth://') || raw.toLowerCase().startsWith('steam://')
                ? TotpConfig.parse(raw)
                : TotpConfig(secret: Base32.decode(raw), algorithm: alg, digits: digits, period: period);
            TotpConfig.parse(cfg.toUri());
            preview = cfg;
            error = null;
          } catch (e) {
            preview = null;
            error = secret.text.isEmpty ? null : '$e';
          }
        }

        final isUri = secret.text.trim().contains('://');
        return AlertDialog(
          title: const Text('Authenticator key'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: secret,
                  autofocus: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'Secret key or otpauth:// URI',
                    errorText: error,
                    errorMaxLines: 3,
                  ),
                  onChanged: (_) => set(validate),
                ),
                if (!isUri) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<TotpAlgorithm>(
                    initialValue: alg,
                    decoration: const InputDecoration(labelText: 'Algorithm'),
                    items: [
                      for (final a in TotpAlgorithm.values)
                        DropdownMenuItem(value: a, child: Text(a.name.toUpperCase())),
                    ],
                    onChanged: (v) => set(() {
                      alg = v!;
                      validate();
                    }),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: digits,
                          decoration: const InputDecoration(labelText: 'Digits'),
                          items: [
                            for (final d in [6, 7, 8]) DropdownMenuItem(value: d, child: Text('$d')),
                          ],
                          onChanged: (v) => set(() {
                            digits = v!;
                            validate();
                          }),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: period,
                          decoration: const InputDecoration(labelText: 'Period'),
                          items: [
                            for (final p in [30, 60, 90]) DropdownMenuItem(value: p, child: Text('${p}s')),
                          ],
                          onChanged: (v) => set(() {
                            period = v!;
                            validate();
                          }),
                        ),
                      ),
                    ],
                  ),
                ],
                if (preview != null) ...[
                  const SizedBox(height: 16),
                  const Text('Preview - compare with the code shown by the service:'),
                  const SizedBox(height: 8),
                  TotpCodeView(config: preview!, compact: true),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            FilledButton(
              onPressed: preview == null ? null : () => Navigator.pop(c, preview!.toUri()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  },
);
