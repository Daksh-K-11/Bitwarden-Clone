import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/config/app_settings.dart';

const _settingsKey = 'settings.v1';

/// Loaded once in bootstrap so the first frame already has the theme etc.
final initialSettingsProvider = Provider<AppSettings>((_) => const AppSettings());

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  Future<void> update(AppSettings Function(AppSettings) change) async {
    final next = change(state);
    state = next;
    await ref.read(databaseProvider).setValue(_settingsKey, next.encode());
    await ref.read(platformSecurityProvider).setSecureScreen(next.blockScreenshots);
  }

  static Future<AppSettings> load(Future<String?> Function(String) read) async =>
      AppSettings.decode(await read(_settingsKey));
}
