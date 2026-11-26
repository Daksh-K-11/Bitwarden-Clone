import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/backup/backup_service.dart';
import '../features/session/session_controller.dart';
import '../features/settings/settings_controller.dart';
import '../features/sync/sync_controller.dart';
import 'common_widgets.dart';
import 'lock_guard.dart';
import 'providers.dart';

/// Enforces the vault timeout:
///  * inactivity timer while in the foreground (reset on any touch/key),
///  * lock immediately when backgrounded (if enabled) or once the app has
///    been away longer than the timeout,
///  * clipboard and decrypted-preview cleanup on lock.
class AutoLockGuardian extends ConsumerStatefulWidget {
  const AutoLockGuardian({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AutoLockGuardian> createState() => _AutoLockGuardianState();
}

class _AutoLockGuardianState extends ConsumerState<AutoLockGuardian> {
  Timer? _idle;
  DateTime? _backgroundedAt;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
    // Register lock hooks once.
    final hooks = ref.read(lockHooksProvider);
    hooks
      ..add(() => ref.read(clipboardServiceProvider).clearNow())
      ..add(() => ref.read(appPathsProvider).wipePreviews())
      ..add(() => ref.read(hibpClientProvider).clearCache());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(platformSecurityProvider).setSecureScreen(ref.read(settingsProvider).blockScreenshots);
    });
  }

  @override
  void dispose() {
    _idle?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  bool get _unlocked => ref.read(sessionProvider) is SessionUnlocked;
  int get _timeout => ref.read(settingsProvider).vaultTimeoutSeconds;

  void _resetIdle() {
    _idle?.cancel();
    if (!_unlocked || _timeout <= 0) return;
    _idle = Timer(Duration(seconds: _timeout), () => ref.read(sessionProvider.notifier).lock());
  }

  void _onHide() {
    ref.read(clipboardServiceProvider).onBackgrounded();
    if (!_unlocked || ref.read(lockGuardProvider) > 0) return;
    _backgroundedAt = DateTime.now();
    final s = ref.read(settingsProvider);
    if (s.lockOnBackground || s.vaultTimeoutSeconds == 0) {
      ref.read(sessionProvider.notifier).lock();
    }
  }

  void _onShow() {
    ref.read(clipboardServiceProvider).onResumed();
    final away = _backgroundedAt;
    _backgroundedAt = null;
    if (_unlocked && away != null && _timeout > 0 && DateTime.now().difference(away).inSeconds >= _timeout) {
      ref.read(sessionProvider.notifier).lock();
      return;
    }
    if (_unlocked) {
      _resetIdle();
      ref.read(syncProvider.notifier).schedule(delay: const Duration(seconds: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (prev, next) {
      if (next is SessionUnlocked && prev is! SessionUnlocked) {
        _resetIdle();
        Future<void>.delayed(const Duration(seconds: 2), () async {
          try {
            await ref.read(backupServiceProvider).maybeAutoBackup();
          } catch (_) {}
        });
      }
      if (next is! SessionUnlocked) _idle?.cancel();
    });
    ref.listen(settingsProvider.select((s) => s.vaultTimeoutSeconds), (_, _) => _resetIdle());
    return Listener(behavior: HitTestBehavior.translucent, onPointerDown: (_) => _resetIdle(), child: widget.child);
  }
}
