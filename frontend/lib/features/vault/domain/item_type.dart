import 'package:material_ui/material_ui.dart';

enum FieldKind {
  text,
  multiline,

  /// Masked single-line secret.
  hidden,

  /// Masked multi-line secret (private keys, recovery phrases, codes).
  hiddenMultiline,

  /// Masked, with generator + strength meter.
  password,
  url,
  email,
  phone,
  number,
  date,
  month,
  year,
  cardNumber,
  select,
}

/// Declarative description of one field of an item template.
class FieldSpec {
  const FieldSpec(
    this.key,
    this.label, {
    this.kind = FieldKind.text,
    this.searchable = false,
    this.copyable = true,
    this.options = const [],
    this.hint,
    this.warning,
    this.requiresSetting,
  });

  final String key;
  final String label;
  final FieldKind kind;

  /// Included in the in-memory search index. Never true for secrets.
  final bool searchable;
  final bool copyable;
  final List<String> options;
  final String? hint;

  /// Shown under the field in the editor (e.g. CVV storage risk).
  final String? warning;

  /// Field only shown when the named setting is enabled.
  final String? requiresSetting;

  bool get isSensitive => switch (kind) {
    FieldKind.hidden || FieldKind.hiddenMultiline || FieldKind.password || FieldKind.cardNumber => true,
    _ => false,
  };

  bool get isMultiline => kind == FieldKind.multiline || kind == FieldKind.hiddenMultiline;
}

/// Item categories. Stored by name in the encrypted payload; add new values
/// freely, never rename existing ones.
enum ItemType {
  login,
  secureNote,
  card,
  identity,
  sshKey,
  apiKey,
  recoveryCodes,
  wifi,
  database,
  softwareLicense,
  passport,
  driversLicense,
  bankAccount,
  cryptoWallet,
  custom;

  ItemTemplate get template => ItemTemplates.of(this);
}

class ItemTemplate {
  const ItemTemplate({
    required this.type,
    required this.label,
    required this.icon,
    required this.fields,
    this.subtitleKeys = const [],
    this.supportsUris = false,
    this.supportsTotp = false,
    this.trackPasswordHistory = const [],
  });

  final ItemType type;
  final String label;
  final IconData icon;
  final List<FieldSpec> fields;

  /// First non-empty of these (non-sensitive) fields is shown in lists.
  final List<String> subtitleKeys;
  final bool supportsUris;
  final bool supportsTotp;

  /// Field keys whose previous values go to encrypted password history.
  final List<String> trackPasswordHistory;

  FieldSpec? spec(String key) {
    for (final f in fields) {
      if (f.key == key) return f;
    }
    return null;
  }
}

abstract final class SettingKeys {
  static const allowCvvStorage = 'allowCvvStorage';
}

abstract final class ItemTemplates {
  static const _cvvWarning =
      'Storing a card security code means anyone who obtains your unlocked '
      'vault can make card-not-present purchases. Payment-card rules (PCI DSS) '
      'forbid merchants from keeping it at all. Store only if you accept this risk.';

  static const _pinWarning =
      'A card PIN plus the card number enables ATM fraud if your vault is '
      'compromised. Consider not storing it.';

  static final Map<ItemType, ItemTemplate> _all = {
    ItemType.login: const ItemTemplate(
      type: ItemType.login,
      label: 'Login',
      icon: Icons.language_rounded,
      supportsUris: true,
      supportsTotp: true,
      subtitleKeys: ['username', 'email'],
      trackPasswordHistory: ['password'],
      fields: [
        FieldSpec('username', 'Username', searchable: true),
        FieldSpec('email', 'Email', kind: FieldKind.email, searchable: true),
        FieldSpec('password', 'Password', kind: FieldKind.password),
      ],
    ),
    ItemType.secureNote: const ItemTemplate(
      type: ItemType.secureNote,
      label: 'Secure note',
      icon: Icons.sticky_note_2_outlined,
      fields: [],
    ),
    ItemType.card: const ItemTemplate(
      type: ItemType.card,
      label: 'Payment card',
      icon: Icons.credit_card_rounded,
      subtitleKeys: ['brand', 'cardholderName'],
      fields: [
        FieldSpec('cardholderName', 'Cardholder name', searchable: true),
        FieldSpec('number', 'Card number', kind: FieldKind.cardNumber),
        FieldSpec(
          'brand',
          'Brand',
          kind: FieldKind.select,
          searchable: true,
          options: [
            'Visa',
            'Mastercard',
            'American Express',
            'RuPay',
            'Discover',
            'JCB',
            'Diners Club',
            'UnionPay',
            'Maestro',
            'Other',
          ],
        ),
        FieldSpec('expMonth', 'Expiry month', kind: FieldKind.month, copyable: true),
        FieldSpec('expYear', 'Expiry year', kind: FieldKind.year, copyable: true),
        FieldSpec(
          'code',
          'Security code (CVV)',
          kind: FieldKind.hidden,
          warning: _cvvWarning,
          requiresSetting: SettingKeys.allowCvvStorage,
        ),
        FieldSpec('pin', 'PIN (optional)', kind: FieldKind.hidden, warning: _pinWarning),
        FieldSpec('billingAddress', 'Billing address', kind: FieldKind.multiline),
      ],
    ),
    ItemType.identity: const ItemTemplate(
      type: ItemType.identity,
      label: 'Identity',
      icon: Icons.badge_outlined,
      subtitleKeys: ['fullName', 'email'],
      fields: [
        FieldSpec('title', 'Title', kind: FieldKind.select, options: ['Mr', 'Mrs', 'Ms', 'Mx', 'Dr', 'Prof']),
        FieldSpec('fullName', 'Full name', searchable: true),
        FieldSpec('firstName', 'First name', searchable: true),
        FieldSpec('middleName', 'Middle name'),
        FieldSpec('lastName', 'Last name', searchable: true),
        FieldSpec('username', 'Username', searchable: true),
        FieldSpec('email', 'Email', kind: FieldKind.email, searchable: true),
        FieldSpec('phone', 'Phone', kind: FieldKind.phone),
        FieldSpec('dateOfBirth', 'Date of birth', kind: FieldKind.date),
        FieldSpec('company', 'Company', searchable: true),
        FieldSpec('nationality', 'Nationality'),
        FieldSpec('address1', 'Address line 1'),
        FieldSpec('address2', 'Address line 2'),
        FieldSpec('city', 'City'),
        FieldSpec('state', 'State / Province'),
        FieldSpec('postalCode', 'Postal code'),
        FieldSpec('country', 'Country'),
        FieldSpec('idType', 'ID document type'),
        FieldSpec('idNumber', 'ID number', kind: FieldKind.hidden),
        FieldSpec('taxId', 'Tax / national ID', kind: FieldKind.hidden),
      ],
    ),
    ItemType.sshKey: const ItemTemplate(
      type: ItemType.sshKey,
      label: 'SSH key',
      icon: Icons.terminal_rounded,
      subtitleKeys: ['keyType', 'comment'],
      fields: [
        FieldSpec(
          'keyType',
          'Key type',
          kind: FieldKind.select,
          searchable: true,
          options: ['ed25519', 'ecdsa', 'rsa', 'other'],
        ),
        FieldSpec('publicKey', 'Public key', kind: FieldKind.multiline),
        FieldSpec('privateKey', 'Private key', kind: FieldKind.hiddenMultiline),
        FieldSpec('passphrase', 'Passphrase', kind: FieldKind.password),
        FieldSpec('fingerprint', 'Fingerprint'),
        FieldSpec('comment', 'Comment', searchable: true),
        FieldSpec('host', 'Host(s)', searchable: true),
      ],
    ),
    ItemType.apiKey: const ItemTemplate(
      type: ItemType.apiKey,
      label: 'API key',
      icon: Icons.key_rounded,
      subtitleKeys: ['service', 'keyId'],
      fields: [
        FieldSpec('service', 'Service', searchable: true),
        FieldSpec('keyId', 'Key ID / client ID', searchable: true),
        FieldSpec('secret', 'Secret', kind: FieldKind.hidden),
        FieldSpec('endpoint', 'Endpoint', kind: FieldKind.url, searchable: true),
        FieldSpec('expiresOn', 'Expires on', kind: FieldKind.date),
      ],
    ),
    ItemType.recoveryCodes: const ItemTemplate(
      type: ItemType.recoveryCodes,
      label: 'Recovery codes',
      icon: Icons.restore_rounded,
      subtitleKeys: ['service', 'account'],
      fields: [
        FieldSpec('service', 'Service', searchable: true),
        FieldSpec('account', 'Account', searchable: true),
        FieldSpec('codes', 'Codes', kind: FieldKind.hiddenMultiline, hint: 'One code per line'),
      ],
    ),
    ItemType.wifi: const ItemTemplate(
      type: ItemType.wifi,
      label: 'Wi-Fi',
      icon: Icons.wifi_rounded,
      subtitleKeys: ['ssid'],
      trackPasswordHistory: ['password'],
      fields: [
        FieldSpec('ssid', 'Network name (SSID)', searchable: true),
        FieldSpec('password', 'Password', kind: FieldKind.password),
        FieldSpec('security', 'Security', kind: FieldKind.select, options: ['WPA3', 'WPA2', 'WPA', 'WEP', 'Open']),
        FieldSpec('hiddenNetwork', 'Hidden network', kind: FieldKind.select, options: ['No', 'Yes']),
      ],
    ),
    ItemType.database: const ItemTemplate(
      type: ItemType.database,
      label: 'Database',
      icon: Icons.storage_rounded,
      subtitleKeys: ['host', 'databaseName'],
      trackPasswordHistory: ['password'],
      fields: [
        FieldSpec(
          'engine',
          'Engine',
          kind: FieldKind.select,
          searchable: true,
          options: ['PostgreSQL', 'MySQL', 'MariaDB', 'SQL Server', 'Oracle', 'MongoDB', 'Redis', 'SQLite', 'Other'],
        ),
        FieldSpec('host', 'Host', searchable: true),
        FieldSpec('port', 'Port', kind: FieldKind.number),
        FieldSpec('databaseName', 'Database', searchable: true),
        FieldSpec('username', 'Username', searchable: true),
        FieldSpec('password', 'Password', kind: FieldKind.password),
        FieldSpec('connectionString', 'Connection string', kind: FieldKind.hidden),
      ],
    ),
    ItemType.softwareLicense: const ItemTemplate(
      type: ItemType.softwareLicense,
      label: 'Software licence',
      icon: Icons.workspace_premium_outlined,
      subtitleKeys: ['product', 'licensee'],
      fields: [
        FieldSpec('product', 'Product', searchable: true),
        FieldSpec('version', 'Version'),
        FieldSpec('licensee', 'Licensed to', searchable: true),
        FieldSpec('email', 'Registered email', kind: FieldKind.email, searchable: true),
        FieldSpec('licenseKey', 'Licence key', kind: FieldKind.hiddenMultiline),
        FieldSpec('purchaseDate', 'Purchase date', kind: FieldKind.date),
        FieldSpec('expiresOn', 'Expires on', kind: FieldKind.date),
        FieldSpec('seats', 'Seats', kind: FieldKind.number),
      ],
    ),
    ItemType.passport: const ItemTemplate(
      type: ItemType.passport,
      label: 'Passport',
      icon: Icons.menu_book_rounded,
      subtitleKeys: ['fullName', 'issuingCountry'],
      fields: [
        FieldSpec('fullName', 'Full name', searchable: true),
        FieldSpec('number', 'Passport number', kind: FieldKind.hidden),
        FieldSpec('nationality', 'Nationality'),
        FieldSpec('issuingCountry', 'Issuing country', searchable: true),
        FieldSpec('dateOfBirth', 'Date of birth', kind: FieldKind.date),
        FieldSpec('placeOfBirth', 'Place of birth'),
        FieldSpec('issueDate', 'Issue date', kind: FieldKind.date),
        FieldSpec('expiryDate', 'Expiry date', kind: FieldKind.date),
        FieldSpec('authority', 'Issuing authority'),
      ],
    ),
    ItemType.driversLicense: const ItemTemplate(
      type: ItemType.driversLicense,
      label: 'Driving licence',
      icon: Icons.directions_car_outlined,
      subtitleKeys: ['fullName', 'issuingRegion'],
      fields: [
        FieldSpec('fullName', 'Full name', searchable: true),
        FieldSpec('number', 'Licence number', kind: FieldKind.hidden),
        FieldSpec('vehicleClass', 'Class(es)'),
        FieldSpec('issuingRegion', 'Issuing state / country', searchable: true),
        FieldSpec('dateOfBirth', 'Date of birth', kind: FieldKind.date),
        FieldSpec('issueDate', 'Issue date', kind: FieldKind.date),
        FieldSpec('expiryDate', 'Expiry date', kind: FieldKind.date),
      ],
    ),
    ItemType.bankAccount: const ItemTemplate(
      type: ItemType.bankAccount,
      label: 'Bank account',
      icon: Icons.account_balance_outlined,
      subtitleKeys: ['bankName', 'accountType'],
      fields: [
        FieldSpec('bankName', 'Bank', searchable: true),
        FieldSpec('accountHolder', 'Account holder', searchable: true),
        FieldSpec(
          'accountType',
          'Account type',
          kind: FieldKind.select,
          options: ['Savings', 'Current / Checking', 'Business', 'Other'],
        ),
        FieldSpec('accountNumber', 'Account number', kind: FieldKind.hidden),
        FieldSpec('routingCode', 'Routing / IFSC / sort code'),
        FieldSpec('iban', 'IBAN', kind: FieldKind.hidden),
        FieldSpec('swift', 'SWIFT / BIC'),
        FieldSpec('branch', 'Branch'),
        FieldSpec('pin', 'PIN / telephone banking code', kind: FieldKind.hidden),
      ],
    ),
    ItemType.cryptoWallet: const ItemTemplate(
      type: ItemType.cryptoWallet,
      label: 'Crypto wallet',
      icon: Icons.currency_bitcoin_rounded,
      subtitleKeys: ['walletName', 'network'],
      fields: [
        FieldSpec('walletName', 'Wallet', searchable: true),
        FieldSpec('network', 'Network / chain', searchable: true),
        FieldSpec('address', 'Public address'),
        FieldSpec('seedPhrase', 'Recovery phrase', kind: FieldKind.hiddenMultiline),
        FieldSpec('passphrase', 'Passphrase (25th word)', kind: FieldKind.hidden),
        FieldSpec('derivationPath', 'Derivation path'),
      ],
    ),
    ItemType.custom: const ItemTemplate(
      type: ItemType.custom,
      label: 'Custom record',
      icon: Icons.dashboard_customize_outlined,
      fields: [],
    ),
  };

  static ItemTemplate of(ItemType type) => _all[type]!;
}
