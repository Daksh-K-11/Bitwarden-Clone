import 'dart:async';
import 'dart:convert';

import '../crypto/crypto_service.dart';
import '../platform/platform_security.dart';

/// Copies single field values and clears them again after a timeout.
///
/// * Only the requested field is copied, never a whole record.
/// * Clipboard contents are never logged or persisted; we keep only a
///   SHA-256 of the copied value in memory to recognise it later.
/// * Before clearing we check that the clipboard still holds *our* value, so
///   something the user copied from another app is never wiped.
/// * Android 10+ forbids clipboard reads while the app lacks focus. If the
///   timer fires in the background we retry when the app returns; Android 13+
///   additionally auto-clears the clipboard after ~1 hour by itself.
/// * iOS: reading the pasteboard shows a system "pasted from" banner, so we
///   do not read it. We clear at the timeout only if the app never left the
///   foreground since copying (otherwise another app may own the clipboard).
class ClipboardService {
  ClipboardService(this._platform, {required this.timeoutSeconds});

  final PlatformSecurity _platform;
  int Function() timeoutSeconds;

  Timer? _timer;
  String? _hash;
  bool _leftForeground = false;
  bool _pendingClear = false;

  bool get hasPendingValue => _hash != null;

  Future<void> copy(String value, {bool sensitive = true}) async {
    await _platform.copyToClipboard(value, sensitive: sensitive);
    _hash = CryptoService.sha256Hex(utf8.encode(value));
    _leftForeground = false;
    _pendingClear = false;
    _timer?.cancel();
    final secs = timeoutSeconds();
    if (secs > 0) _timer = Timer(Duration(seconds: secs), _onTimeout);
  }

  Future<void> _onTimeout() async {
    _timer = null;
    await clearIfOurs();
  }

  /// Returns true if the clipboard was cleared (or nothing is left to do).
  Future<bool> clearIfOurs() async {
    final hash = _hash;
    if (hash == null) return true;
    if (_platform.isAndroid) {
      final r = await _platform.clearClipboardIfMatches(hash);
      if (r == ClipboardClearResult.unreadable) {
        _pendingClear = true;
        return false;
      }
    } else {
      if (_leftForeground) {
        _hash = null;
        return true;
      }
      await _platform.copyToClipboard('', sensitive: false);
    }
    _hash = null;
    _pendingClear = false;
    return true;
  }

  void onBackgrounded() => _leftForeground = true;

  Future<void> onResumed() async {
    if (_pendingClear || (_hash != null && _timer == null)) await clearIfOurs();
  }

  /// Called on manual lock.
  Future<void> clearNow() async {
    _timer?.cancel();
    _timer = null;
    await clearIfOurs();
  }

  void dispose() => _timer?.cancel();
}
