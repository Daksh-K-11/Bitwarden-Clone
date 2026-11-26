import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Number of in-flight external activities (file picker, camera, system
/// auth dialog, share sheet). While > 0, "lock on background" is suspended,
/// because these flows send the app to the background by design.
final lockGuardProvider = NotifierProvider<LockGuardCounter, int>(LockGuardCounter.new);

class LockGuardCounter extends Notifier<int> {
  @override
  int build() => 0;
  void enter() => state++;
  void exit() => state = state > 0 ? state - 1 : 0;
}

abstract final class LockGuard {
  static Future<T> run<T>(WidgetRef ref, Future<T> Function() action) async {
    final n = ref.read(lockGuardProvider.notifier)..enter();
    try {
      return await action();
    } finally {
      // Delay so the resume event is handled before the guard drops.
      Future<void>.delayed(const Duration(milliseconds: 800), n.exit);
    }
  }
}
