import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:sodium/sodium_sumo.dart';

import '../core/cloud/cloud_bootstrap.dart';
import '../core/config/app_paths.dart';
import '../core/crypto/crypto_service.dart';
import '../core/db/database.dart';
import '../core/storage/secure_store.dart';
import '../features/settings/settings_controller.dart';
import 'providers.dart';

/// Everything that must exist before the first frame.
Future<List<Override>> bootstrap() async {
  final sodium = await SodiumSumoInit.init();
  final crypto = CryptoService(sodium);
  final store = SecureStore();
  final paths = await AppPaths.resolve();

  // Random 256-bit SQLCipher key, generated once per install and kept in the
  // Keystore-backed secure storage. Independent of the vault key so encrypted
  // records can sync while the vault is locked; every sensitive record is
  // additionally encrypted with the VEK.
  var dbKey = await store.read(SecureKeys.databaseKey);
  if (dbKey == null) {
    if (await paths.database.exists()) {
      // Key lost (e.g. app data partially cleared): the DB is unreadable.
      // Move it aside rather than deleting user data.
      await paths.database.rename('${paths.database.path}.orphaned-${DateTime.now().millisecondsSinceEpoch}');
    }
    dbKey = sodium.bin2hex(crypto.randomBytes(32));
    await store.write(SecureKeys.databaseKey, dbKey);
  }
  final db = AppDatabase.open(paths.database, dbKey);
  final settings = await SettingsController.load(db.getValue);
  final words = (await rootBundle.loadString(
    'assets/wordlists/eff_large.txt',
  )).split('\n').map((w) => w.trim()).where((w) => w.isNotEmpty).toList(growable: false);
  final cloud = await initCloud();

  return [
    cryptoProvider.overrideWithValue(crypto),
    secureStoreProvider.overrideWithValue(store),
    databaseProvider.overrideWithValue(db),
    appPathsProvider.overrideWithValue(paths),
    cloudConfigProvider.overrideWithValue(cloud),
    initialSettingsProvider.overrideWithValue(settings),
    wordListProvider.overrideWithValue(words),
  ];
}
