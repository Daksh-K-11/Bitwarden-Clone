import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../crypto/kdf_params.dart';

/// User-configurable, non-secret settings (persisted in the encrypted DB).
@immutable
class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.vaultTimeoutSeconds = 300,
    this.lockOnBackground = false,
    this.clipboardClearSeconds = 30,
    this.blockScreenshots = !kDebugMode,
    this.breachCheckEnabled = false,
    this.searchNotes = false,
    this.allowCvvStorage = false,
    this.requireAuthForCards = true,
    this.passwordHistoryEnabled = true,
    this.passwordHistoryMax = 10,
    this.autoBackupEnabled = true,
    this.autoBackupKeep = 7,
    this.attachmentMaxMb = 25,
    this.kdfPreset = KdfPreset.standard,
  });

  /// Vault timeout choices in seconds. -1 = only on app restart.
  static const timeoutChoices = <int, String>{
    0: 'Immediately',
    60: '1 minute',
    300: '5 minutes',
    900: '15 minutes',
    1800: '30 minutes',
    3600: '1 hour',
    14400: '4 hours',
    -1: 'On app restart',
  };

  static const clipboardChoices = <int, String>{
    10: '10 seconds',
    20: '20 seconds',
    30: '30 seconds',
    60: '1 minute',
    120: '2 minutes',
    300: '5 minutes',
    0: 'Never',
  };

  final ThemeMode themeMode;
  final int vaultTimeoutSeconds;
  final bool lockOnBackground;
  final int clipboardClearSeconds;
  final bool blockScreenshots;
  final bool breachCheckEnabled;
  final bool searchNotes;
  final bool allowCvvStorage;
  final bool requireAuthForCards;
  final bool passwordHistoryEnabled;
  final int passwordHistoryMax;
  final bool autoBackupEnabled;
  final int autoBackupKeep;
  final int attachmentMaxMb;
  final KdfPreset kdfPreset;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? vaultTimeoutSeconds,
    bool? lockOnBackground,
    int? clipboardClearSeconds,
    bool? blockScreenshots,
    bool? breachCheckEnabled,
    bool? searchNotes,
    bool? allowCvvStorage,
    bool? requireAuthForCards,
    bool? passwordHistoryEnabled,
    int? passwordHistoryMax,
    bool? autoBackupEnabled,
    int? autoBackupKeep,
    int? attachmentMaxMb,
    KdfPreset? kdfPreset,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    vaultTimeoutSeconds: vaultTimeoutSeconds ?? this.vaultTimeoutSeconds,
    lockOnBackground: lockOnBackground ?? this.lockOnBackground,
    clipboardClearSeconds: clipboardClearSeconds ?? this.clipboardClearSeconds,
    blockScreenshots: blockScreenshots ?? this.blockScreenshots,
    breachCheckEnabled: breachCheckEnabled ?? this.breachCheckEnabled,
    searchNotes: searchNotes ?? this.searchNotes,
    allowCvvStorage: allowCvvStorage ?? this.allowCvvStorage,
    requireAuthForCards: requireAuthForCards ?? this.requireAuthForCards,
    passwordHistoryEnabled: passwordHistoryEnabled ?? this.passwordHistoryEnabled,
    passwordHistoryMax: passwordHistoryMax ?? this.passwordHistoryMax,
    autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
    autoBackupKeep: autoBackupKeep ?? this.autoBackupKeep,
    attachmentMaxMb: attachmentMaxMb ?? this.attachmentMaxMb,
    kdfPreset: kdfPreset ?? this.kdfPreset,
  );

  Map<String, Object> toJson() => {
    'themeMode': themeMode.name,
    'vaultTimeoutSeconds': vaultTimeoutSeconds,
    'lockOnBackground': lockOnBackground,
    'clipboardClearSeconds': clipboardClearSeconds,
    'blockScreenshots': blockScreenshots,
    'breachCheckEnabled': breachCheckEnabled,
    'searchNotes': searchNotes,
    'allowCvvStorage': allowCvvStorage,
    'requireAuthForCards': requireAuthForCards,
    'passwordHistoryEnabled': passwordHistoryEnabled,
    'passwordHistoryMax': passwordHistoryMax,
    'autoBackupEnabled': autoBackupEnabled,
    'autoBackupKeep': autoBackupKeep,
    'attachmentMaxMb': attachmentMaxMb,
    'kdfPreset': kdfPreset.name,
  };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    const d = AppSettings();
    T pick<T>(String k, T fallback) => j[k] is T ? j[k] as T : fallback;
    return AppSettings(
      themeMode: ThemeMode.values.asNameMap()[j['themeMode']] ?? d.themeMode,
      vaultTimeoutSeconds: pick('vaultTimeoutSeconds', d.vaultTimeoutSeconds),
      lockOnBackground: pick('lockOnBackground', d.lockOnBackground),
      clipboardClearSeconds: pick('clipboardClearSeconds', d.clipboardClearSeconds),
      blockScreenshots: pick('blockScreenshots', d.blockScreenshots),
      breachCheckEnabled: pick('breachCheckEnabled', d.breachCheckEnabled),
      searchNotes: pick('searchNotes', d.searchNotes),
      allowCvvStorage: pick('allowCvvStorage', d.allowCvvStorage),
      requireAuthForCards: pick('requireAuthForCards', d.requireAuthForCards),
      passwordHistoryEnabled: pick('passwordHistoryEnabled', d.passwordHistoryEnabled),
      passwordHistoryMax: pick('passwordHistoryMax', d.passwordHistoryMax),
      autoBackupEnabled: pick('autoBackupEnabled', d.autoBackupEnabled),
      autoBackupKeep: pick('autoBackupKeep', d.autoBackupKeep),
      attachmentMaxMb: pick('attachmentMaxMb', d.attachmentMaxMb),
      kdfPreset: KdfPreset.values.asNameMap()[j['kdfPreset']] ?? d.kdfPreset,
    );
  }

  String encode() => jsonEncode(toJson());
  static AppSettings decode(String? s) {
    if (s == null) return const AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
    } catch (_) {
      return const AppSettings();
    }
  }

  bool isEnabled(String settingKey) => switch (settingKey) {
    'allowCvvStorage' => allowCvvStorage,
    _ => true,
  };
}
