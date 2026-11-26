import 'package:flutter/foundation.dart';

/// Minimal logger with a strict policy:
///  * never pass passwords, keys, plaintext fields, TOTP secrets, clipboard
///    contents, tokens or ciphertext - only static text, ids and error types;
///  * compiled out of release builds (no logcat output at all).
abstract final class Log {
  static void d(String tag, String message) {
    if (kDebugMode) debugPrint('[$tag] $message');
  }

  static void w(String tag, String message) {
    if (kDebugMode) debugPrint('[$tag] WARN $message');
  }

  static void e(String tag, String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('[$tag] ERROR $message${error == null ? '' : ' (${error.runtimeType})'}');
    }
  }
}
