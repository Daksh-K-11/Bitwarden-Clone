import 'dart:io';

import 'package:flutter/services.dart';

enum ClipboardClearResult { cleared, changed, empty, unreadable, unsupported }

class BiometricStatus {
  const BiometricStatus({
    required this.strongBiometric,
    required this.deviceCredential,
    required this.noneEnrolled,
    required this.keyExists,
  });

  static const unsupported = BiometricStatus(
    strongBiometric: false,
    deviceCredential: false,
    noneEnrolled: false,
    keyExists: false,
  );

  /// Class 3 ("strong") biometrics that can release Keystore keys.
  final bool strongBiometric;

  /// Device PIN/pattern/password can release the key (Android 11+).
  final bool deviceCredential;
  final bool noneEnrolled;
  final bool keyExists;

  bool get canUseBiometricUnlock => strongBiometric || deviceCredential;
}

enum BiometricErrorCode { cancelled, lockout, invalidated, noKey, failed }

class BiometricException implements Exception {
  const BiometricException(this.code, [this.message]);
  final BiometricErrorCode code;
  final String? message;
  @override
  String toString() => 'BiometricException($code)';
}

/// Dart side of `SecurityChannel.kt`. Every method degrades gracefully on
/// platforms without a native implementation.
class PlatformSecurity {
  static const _channel = MethodChannel('app.citadel.vault/security');

  bool get isAndroid => Platform.isAndroid;

  Future<void> setSecureScreen(bool enabled) async {
    if (!isAndroid) return;
    await _channel.invokeMethod('setSecureScreen', {'enabled': enabled});
  }

  /// Copies text, flagged as sensitive on Android 13+ so the system preview
  /// overlay and clipboard history suggestions hide it.
  Future<void> copyToClipboard(String text, {bool sensitive = true}) async {
    if (isAndroid) {
      await _channel.invokeMethod('copyToClipboard', {'text': text, 'sensitive': sensitive});
    } else {
      await Clipboard.setData(ClipboardData(text: text));
    }
  }

  Future<ClipboardClearResult> clearClipboardIfMatches(String sha256Hex) async {
    if (!isAndroid) return ClipboardClearResult.unsupported;
    final result = await _channel.invokeMethod<String>('clearClipboardIfMatches', {'sha256': sha256Hex});
    return switch (result) {
      'cleared' => ClipboardClearResult.cleared,
      'changed' => ClipboardClearResult.changed,
      'empty' => ClipboardClearResult.empty,
      _ => ClipboardClearResult.unreadable,
    };
  }

  Future<BiometricStatus> biometricStatus() async {
    if (!isAndroid) return BiometricStatus.unsupported;
    final map = await _channel.invokeMapMethod<String, Object?>('biometricStatus');
    if (map == null) return BiometricStatus.unsupported;
    return BiometricStatus(
      strongBiometric: map['strongBiometric'] == true,
      deviceCredential: map['deviceCredential'] == true,
      noneEnrolled: map['noneEnrolled'] == true,
      keyExists: map['keyExists'] == true,
    );
  }

  /// Creates a fresh Keystore key and encrypts [data] with it after the user
  /// authenticates. Returns (iv, ciphertext).
  Future<(Uint8List, Uint8List)> biometricEncrypt(
    Uint8List data, {
    required String title,
    String? subtitle,
    bool allowDeviceCredential = false,
  }) async {
    try {
      final map = await _channel.invokeMapMethod<String, Object?>('biometricEncrypt', {
        'data': data,
        'title': title,
        'subtitle': ?subtitle,
        'allowDeviceCredential': allowDeviceCredential,
      });
      return (map!['iv']! as Uint8List, map['ct']! as Uint8List);
    } on PlatformException catch (e) {
      throw _map(e);
    }
  }

  Future<Uint8List> biometricDecrypt(
    Uint8List iv,
    Uint8List cipherText, {
    required String title,
    String? subtitle,
    bool allowDeviceCredential = false,
  }) async {
    try {
      final out = await _channel.invokeMethod<Uint8List>('biometricDecrypt', {
        'iv': iv,
        'ct': cipherText,
        'title': title,
        'subtitle': ?subtitle,
        'allowDeviceCredential': allowDeviceCredential,
      });
      return out!;
    } on PlatformException catch (e) {
      throw _map(e);
    }
  }

  Future<void> biometricDeleteKey() async {
    if (!isAndroid) return;
    await _channel.invokeMethod('biometricDeleteKey');
  }

  BiometricException _map(PlatformException e) => BiometricException(switch (e.code) {
    'cancelled' => BiometricErrorCode.cancelled,
    'lockout' => BiometricErrorCode.lockout,
    'invalidated' => BiometricErrorCode.invalidated,
    'no_key' => BiometricErrorCode.noKey,
    _ => BiometricErrorCode.failed,
  }, e.message);
}
