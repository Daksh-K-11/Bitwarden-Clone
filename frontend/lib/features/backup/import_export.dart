import 'dart:convert';

import '../vault/application/vault_controller.dart' show newId;
import '../vault/domain/item_type.dart';
import '../vault/domain/vault_models.dart';

class ImportResult {
  ImportResult({required this.items, required this.folders, this.tags = const [], this.warnings = const []});
  final List<VaultItem> items;
  final List<Folder> folders;
  final List<Tag> tags;
  final List<String> warnings;
}

class ImportException implements Exception {
  const ImportException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Extensible import: add an implementation and register it in [Importers].
abstract interface class VaultImporter {
  String get name;
  bool canParse(String content);
  ImportResult parse(String content);
}

abstract final class Importers {
  static final List<VaultImporter> all = [CitadelJsonImporter(), BitwardenJsonImporter(), BitwardenCsvImporter()];

  static ImportResult parseAny(String content) {
    for (final i in all) {
      if (i.canParse(content)) return i.parse(content);
    }
    throw const ImportException(
      'Unrecognised file. Supported: Citadel JSON/.citadel, Bitwarden JSON (unencrypted) and Bitwarden CSV.',
    );
  }
}

// ------------------------------------------------------------------ Citadel

class CitadelJsonImporter implements VaultImporter {
  @override
  String get name => 'Citadel JSON';

  @override
  bool canParse(String content) => content.trimLeft().startsWith('{') && content.contains('"citadel-export"');

  @override
  ImportResult parse(String content) {
    final j = jsonDecode(content) as Map<String, dynamic>;
    return ImportResult(
      folders: [for (final f in (j['folders'] as List? ?? [])) Folder.fromJson((f as Map).cast())],
      tags: [for (final t in (j['tags'] as List? ?? [])) Tag.fromJson((t as Map).cast())],
      items: [
        for (final i in (j['items'] as List? ?? []))
          VaultItem.fromJson((i as Map).cast()).copyWith(attachments: const []),
      ],
    );
  }
}

// ---------------------------------------------------------------- Bitwarden

class BitwardenJsonImporter implements VaultImporter {
  @override
  String get name => 'Bitwarden JSON';

  @override
  bool canParse(String content) {
    final t = content.trimLeft();
    return t.startsWith('{') && t.contains('"items"') && !t.contains('"citadel-export"');
  }

  @override
  ImportResult parse(String content) {
    final j = jsonDecode(content) as Map<String, dynamic>;
    if (j['encrypted'] == true) {
      throw const ImportException(
        'Encrypted Bitwarden exports cannot be imported. Export as unencrypted JSON (then delete that file).',
      );
    }
    final now = DateTime.now().toUtc();
    final warnings = <String>[];
    final folderMap = <String, String>{};
    final folders = <Folder>[];
    for (final f in (j['folders'] as List? ?? [])) {
      final m = (f as Map).cast<String, dynamic>();
      final id = newId();
      folderMap[m['id'] as String] = id;
      folders.add(Folder(id: id, name: m['name'] as String? ?? 'Folder', createdAt: now, updatedAt: now));
    }
    final items = <VaultItem>[];
    for (final raw in (j['items'] as List? ?? [])) {
      final m = (raw as Map).cast<String, dynamic>();
      if (m['organizationId'] != null) warnings.add('Organization item "${m['name']}" imported as personal');
      DateTime? d(Object? s) => s is String ? DateTime.tryParse(s)?.toUtc() : null;
      final fields = <String, String>{};
      var type = ItemType.secureNote;
      var uris = <String>[];
      String? totp;
      void put(String k, Object? v) {
        if (v != null && '$v'.isNotEmpty) fields[k] = '$v';
      }

      switch (m['type']) {
        case 1:
          type = ItemType.login;
          final l = (m['login'] as Map?)?.cast<String, dynamic>() ?? {};
          put('username', l['username']);
          put('password', l['password']);
          totp = l['totp'] as String?;
          uris = [for (final u in (l['uris'] as List? ?? [])) ?((u as Map)['uri'] as String?)];
        case 3:
          type = ItemType.card;
          final c = (m['card'] as Map?)?.cast<String, dynamic>() ?? {};
          for (final k in ['cardholderName', 'brand', 'number', 'expMonth', 'expYear', 'code']) {
            put(k, c[k]);
          }
        case 4:
          type = ItemType.identity;
          final i = (m['identity'] as Map?)?.cast<String, dynamic>() ?? {};
          for (final k in [
            'title',
            'firstName',
            'middleName',
            'lastName',
            'address1',
            'address2',
            'city',
            'state',
            'postalCode',
            'country',
            'company',
            'email',
            'phone',
            'username',
          ]) {
            put(k, i[k]);
          }
          put('taxId', i['ssn']);
          if (i['passportNumber'] != null) {
            put('idType', 'Passport');
            put('idNumber', i['passportNumber']);
          } else if (i['licenseNumber'] != null) {
            put('idType', 'Driving licence');
            put('idNumber', i['licenseNumber']);
          }
          final full = [i['firstName'], i['middleName'], i['lastName']].whereType<String>().join(' ');
          put('fullName', full);
        case 5:
          type = ItemType.sshKey;
          final s = (m['sshKey'] as Map?)?.cast<String, dynamic>() ?? {};
          put('privateKey', s['privateKey']);
          put('publicKey', s['publicKey']);
          put('fingerprint', s['keyFingerprint']);
        default:
          type = ItemType.secureNote;
      }
      final custom = <CustomField>[];
      for (final f in (m['fields'] as List? ?? [])) {
        final fm = (f as Map).cast<String, dynamic>();
        custom.add(
          CustomField(
            id: newId(),
            name: fm['name'] as String? ?? '',
            value: '${fm['value'] ?? ''}',
            type: switch (fm['type']) {
              1 => CustomFieldType.hidden,
              2 => CustomFieldType.boolean,
              _ => CustomFieldType.text,
            },
          ),
        );
      }
      final history = [
        for (final h in (m['passwordHistory'] as List? ?? []))
          PasswordHistoryEntry(
            password: (h as Map)['password'] as String? ?? '',
            changedAt: d(h['lastUsedDate']) ?? now,
          ),
      ];
      items.add(
        VaultItem(
          id: newId(),
          type: type,
          name: m['name'] as String? ?? 'Untitled',
          fields: fields,
          uris: uris,
          totp: (totp?.isEmpty ?? true) ? null : totp,
          notes: m['notes'] as String? ?? '',
          customFields: custom,
          passwordHistory: history,
          folderId: folderMap[m['folderId']],
          favorite: m['favorite'] == true,
          reprompt: m['reprompt'] == 1,
          trashedAt: d(m['deletedDate']),
          createdAt: d(m['creationDate']) ?? now,
          updatedAt: d(m['revisionDate']) ?? now,
        ),
      );
    }
    return ImportResult(items: items, folders: folders, warnings: warnings);
  }
}

/// Minimal RFC 4180 CSV parser (quoted fields, escaped quotes, embedded newlines).
List<List<String>> parseCsv(String input) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  final s = input.startsWith('﻿') ? input.substring(1) : input;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < s.length && s[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      row.add(field.toString());
      field.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < s.length && s[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      if (row.any((f) => f.isNotEmpty)) rows.add(row);
      row = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    if (row.any((f) => f.isNotEmpty)) rows.add(row);
  }
  return rows;
}

String _csvEscape(String v) =>
    RegExp(r'[",\r\n]').hasMatch(v) || v.startsWith(RegExp(r'[=+\-@]')) ? '"${v.replaceAll('"', '""')}"' : v;

class BitwardenCsvImporter implements VaultImporter {
  static const headers = [
    'folder',
    'favorite',
    'type',
    'name',
    'notes',
    'fields',
    'reprompt',
    'login_uri',
    'login_username',
    'login_password',
    'login_totp',
  ];

  @override
  String get name => 'Bitwarden CSV';

  @override
  bool canParse(String content) {
    final first = content.trimLeft().split(RegExp(r'\r?\n')).first.toLowerCase();
    return first.contains('login_password') && first.contains('name');
  }

  @override
  ImportResult parse(String content) {
    final rows = parseCsv(content);
    if (rows.isEmpty) throw const ImportException('CSV is empty');
    final h = rows.first.map((e) => e.trim().toLowerCase()).toList();
    int col(String n) => h.indexOf(n);
    String at(List<String> r, String n) {
      final i = col(n);
      return i >= 0 && i < r.length ? r[i] : '';
    }

    final now = DateTime.now().toUtc();
    final folders = <String, Folder>{};
    final items = <VaultItem>[];
    for (final r in rows.skip(1)) {
      final folderName = at(r, 'folder').trim();
      String? folderId;
      if (folderName.isNotEmpty) {
        folderId = (folders[folderName] ??= Folder(id: newId(), name: folderName, createdAt: now, updatedAt: now)).id;
      }
      final isLogin = at(r, 'type').toLowerCase() != 'note';
      final custom = <CustomField>[];
      for (final line in at(r, 'fields').split(RegExp(r'\r?\n'))) {
        final i = line.indexOf(': ');
        if (i > 0) custom.add(CustomField(id: newId(), name: line.substring(0, i), value: line.substring(i + 2)));
      }
      final totp = at(r, 'login_totp');
      items.add(
        VaultItem(
          id: newId(),
          type: isLogin ? ItemType.login : ItemType.secureNote,
          name: at(r, 'name').isEmpty ? 'Untitled' : at(r, 'name'),
          fields: {
            if (isLogin && at(r, 'login_username').isNotEmpty) 'username': at(r, 'login_username'),
            if (isLogin && at(r, 'login_password').isNotEmpty) 'password': at(r, 'login_password'),
          },
          uris: isLogin
              ? at(r, 'login_uri').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
              : const [],
          totp: totp.isEmpty ? null : totp,
          notes: at(r, 'notes'),
          customFields: custom,
          folderId: folderId,
          favorite: at(r, 'favorite') == '1',
          reprompt: at(r, 'reprompt') == '1',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    return ImportResult(items: items, folders: folders.values.toList());
  }
}

// ------------------------------------------------------------------ export

abstract final class Exporters {
  /// Citadel JSON (plaintext!). Attachment keys are stripped - attachments
  /// are only carried by encrypted archives.
  static String citadelJson({required List<VaultItem> items, required List<Folder> folders, required List<Tag> tags}) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'citadel-export',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'folders': folders.map((f) => f.toJson()).toList(),
      'tags': tags.map((t) => t.toJson()).toList(),
      'items': items.map((i) => i.copyWith(attachments: const []).toJson()).toList(),
    });
  }

  /// Bitwarden-compatible CSV (plaintext!). Non-login types are exported as
  /// notes with their fields in the `fields` column. Values starting with
  /// = + - @ are quoted to blunt CSV formula injection in spreadsheets.
  static String bitwardenCsv({required List<VaultItem> items, required Map<String, Folder> folders}) {
    final sb = StringBuffer()..writeln(BitwardenCsvImporter.headers.join(','));
    for (final i in items) {
      final isLogin = i.type == ItemType.login;
      final extra = <String>[
        if (!isLogin)
          for (final e in i.fields.entries) '${i.type.template.spec(e.key)?.label ?? e.key}: ${e.value}',
        for (final c in i.customFields) '${c.name}: ${c.value}',
      ];
      final cols = [
        folders[i.folderId]?.name ?? '',
        i.favorite ? '1' : '',
        isLogin ? 'login' : 'note',
        i.name,
        i.notes,
        extra.join('\n'),
        i.reprompt ? '1' : '0',
        isLogin ? i.uris.join(',') : '',
        isLogin ? i.field('username') : '',
        isLogin ? i.field('password') : '',
        isLogin ? (i.totp ?? '') : '',
      ];
      sb.writeln(cols.map(_csvEscape).join(','));
    }
    return sb.toString();
  }
}
