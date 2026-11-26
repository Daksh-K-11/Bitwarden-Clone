// PLACEHOLDER - overwritten by `flutterfire configure`.
//
// Until Firebase is configured the app runs in offline (device-only) mode:
// every vault feature works, cloud sign-in/sync are hidden.
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=<your-firebase-project> --platforms=android,ios
//
// See docs/SETUP.md.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError('Firebase is not configured for this build.');
}
