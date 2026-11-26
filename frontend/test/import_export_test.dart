import 'dart:convert';

import 'package:citadel/features/backup/import_export.dart';
import 'package:citadel/features/vault/application/vault_search.dart';
import 'package:citadel/features/vault/domain/item_type.dart';
import 'package:citadel/features/vault/domain/vault_models.dart';
import 'package:flutter_test/flutter_test.dart';

VaultItem login(String id, {String name = 'Site', String pw = 'S3cret!pw', String notes = ''}) => VaultItem(
  id: id,
  type: ItemType.login,
  name: name,
  fields: {'username': 'bob', 'password': pw},
  uris: const ['https://example.com'],
  notes: notes,
  customFields: const [
    CustomField(id: 'c1', name: 'Recovery email', value: 'r@example.com'),
    CustomField(id: 'c2', name: 'API secret', value: 'tok_hidden_value', type: CustomFieldType.hidden),
  ],
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  test('CSV parser handles quotes, commas and newlines', () {
    final rows = parseCsv('a,b,c\n"x, y","he said ""hi""","multi\nline"\r\n');
    expect(rows, [
      ['a', 'b', 'c'],
      ['x, y', 'he said "hi"', 'multi\nline'],
    ]);
  });

  test('Bitwarden CSV export -> import round trip', () {
    final csv = Exporters.bitwardenCsv(
      items: [login('1', name: 'Mail, personal', notes: 'line1\nline2')],
      folders: const {},
    );
    final r = BitwardenCsvImporter().parse(csv);
    expect(r.items.single.name, 'Mail, personal');
    expect(r.items.single.field('password'), 'S3cret!pw');
    expect(r.items.single.notes, 'line1\nline2');
    expect(r.items.single.uris, ['https://example.com']);
  });

  test('CSV export neutralises spreadsheet formula injection', () {
    final csv = Exporters.bitwardenCsv(
      items: [login('1', name: '=HYPERLINK("http://evil")')],
      folders: const {},
    );
    expect(csv.contains('"=HYPERLINK(""http://evil"")"'), isTrue);
  });

  test('Bitwarden JSON import maps types, folders and fields', () {
    final json = jsonEncode({
      'encrypted': false,
      'folders': [
        {'id': 'f1', 'name': 'Work'},
      ],
      'items': [
        {
          'id': 'i1',
          'type': 1,
          'name': 'GitHub',
          'folderId': 'f1',
          'favorite': true,
          'login': {
            'username': 'octo',
            'password': 'pw',
            'totp': 'JBSWY3DPEHPK3PXP',
            'uris': [
              {'uri': 'https://github.com'},
            ],
          },
          'fields': [
            {'name': 'pin', 'value': '1234', 'type': 1},
          ],
        },
        {
          'id': 'i2',
          'type': 3,
          'name': 'Visa',
          'card': {
            'cardholderName': 'A B',
            'number': '4111111111111111',
            'expMonth': '12',
            'expYear': '2030',
            'code': '123',
          },
        },
      ],
    });
    final r = BitwardenJsonImporter().parse(json);
    expect(r.folders.single.name, 'Work');
    final gh = r.items.firstWhere((i) => i.name == 'GitHub');
    expect(gh.folderId, r.folders.single.id);
    expect(gh.favorite, isTrue);
    expect(gh.totp, 'JBSWY3DPEHPK3PXP');
    expect(gh.customFields.single.type, CustomFieldType.hidden);
    final card = r.items.firstWhere((i) => i.type == ItemType.card);
    expect(card.field('number'), '4111111111111111');
    expect(() => BitwardenJsonImporter().parse('{"encrypted": true, "items": []}'), throwsA(isA<ImportException>()));
  });

  test('Citadel JSON round trip', () {
    final json = Exporters.citadelJson(items: [login('1')], folders: const [], tags: const []);
    final r = Importers.parseAny(json);
    expect(r.items.single.customFields.length, 2);
  });

  group('search index never contains secrets', () {
    final item = login('1', pw: 'zebra-password-xyz', notes: 'the safe combination is 8812');
    test('passwords and hidden custom fields are not searchable', () {
      final idx = SearchIndex.build([item], folders: const {}, tags: const {}, includeNotes: false);
      expect(idx.matches('1', ['bob']), isTrue);
      expect(idx.matches('1', ['example.com']), isTrue);
      expect(idx.matches('1', ['recovery']), isTrue);
      expect(idx.matches('1', ['zebra']), isFalse);
      expect(idx.matches('1', ['tok_hidden']), isFalse);
      expect(idx.matches('1', ['8812']), isFalse);
    });
    test('notes only when enabled', () {
      final idx = SearchIndex.build([item], folders: const {}, tags: const {}, includeNotes: true);
      expect(idx.matches('1', ['combination']), isTrue);
      expect(idx.matches('1', ['zebra']), isFalse);
    });
  });
}
