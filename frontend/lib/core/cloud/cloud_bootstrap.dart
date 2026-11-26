import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../util/log.dart';

/// Broker API for R2 presigned URLs. Supplied at build time:
///   flutter run --dart-define=CITADEL_API_URL=http://192.168.29.10:8000
const String kApiBaseUrl = String.fromEnvironment('CITADEL_API_URL');

class CloudConfig {
  const CloudConfig({required this.firebaseReady, required this.apiBaseUrl});
  const CloudConfig.offline() : firebaseReady = false, apiBaseUrl = '';

  final bool firebaseReady;
  final String apiBaseUrl;

  bool get objectStorageReady => firebaseReady && apiBaseUrl.isNotEmpty;
}

/// Initialises Firebase if `firebase_options.dart` has been generated.
/// Any failure leaves the app in fully functional offline mode.
Future<CloudConfig> initCloud() async {
  final FirebaseOptions options;
  try {
    options = DefaultFirebaseOptions.currentPlatform;
  } on UnsupportedError {
    Log.d('cloud', 'Firebase not configured - offline mode');
    return const CloudConfig.offline();
  }
  try {
    await Firebase.initializeApp(options: options);
    // Our own encrypted SQLCipher cache is the offline store; Firestore's
    // cache would duplicate (ciphertext-only) data on disk for no benefit.
    FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: false);
    await FirebaseAuth.instance.setLanguageCode(null);
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode ? const AppleDebugProvider() : const AppleAppAttestProvider(),
      );
    } catch (e) {
      Log.w('cloud', 'App Check activation failed (${e.runtimeType})');
    }
    return CloudConfig(firebaseReady: true, apiBaseUrl: kApiBaseUrl);
  } catch (e) {
    Log.e('cloud', 'Firebase init failed', e);
    return const CloudConfig.offline();
  }
}
