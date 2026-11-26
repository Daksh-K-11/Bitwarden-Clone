import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/common_widgets.dart';
import '../../../app/lock_guard.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/crypto/crypto_exceptions.dart';
import '../../../core/platform/platform_security.dart';
import '../../account/account_service.dart';
import '../session_controller.dart';
import '../unlock_service.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});
  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _obscure = true;
  bool _busy = false;
  bool _pinMode = false;
  String? _error;
  bool _autoBioTried = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(sessionProvider);
    if (s is SessionLocked) _pinMode = s.options.pin;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoBiometric());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _maybeAutoBiometric() {
    final s = ref.read(sessionProvider);
    if (!_autoBioTried && s is SessionLocked && s.options.biometric && s.reason == null) {
      _autoBioTried = true;
      _biometric();
    }
  }

  Future<void> _run(Future<void> Function() fn) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await fn();
    } on DecryptionFailedException {
      final fails = await ref.read(unlockServiceProvider).failureCount();
      _error = _pinMode ? 'Incorrect PIN' : 'Incorrect master password${fails >= 3 ? ' ($fails failed attempts)' : ''}';
    } on UnlockThrottledException catch (e) {
      _error = e.toString();
    } on PinDisabledException catch (e) {
      _error = e.toString();
      _pinMode = false;
    } on BiometricException catch (e) {
      _error = switch (e.code) {
        BiometricErrorCode.cancelled => null,
        BiometricErrorCode.lockout => 'Too many biometric attempts. Use your master password.',
        BiometricErrorCode.invalidated =>
          'Biometrics changed on this device. Unlock with your master password, then re-enable biometric unlock.',
        _ => 'Biometric unlock failed.',
      };
    } catch (e) {
      _error = '$e';
    } finally {
      _ctrl.clear();
      if (mounted) {
        setState(() => _busy = false);
        if (_error != null) _focus.requestFocus();
      }
    }
  }

  Future<void> _submit() => _run(() async {
    final c = ref.read(sessionProvider.notifier);
    if (_pinMode) {
      await c.unlockWithPin(_ctrl.text);
    } else {
      await c.unlockWithPassword(_ctrl.text);
    }
  });

  Future<void> _biometric() =>
      _run(() => LockGuard.run(ref, () => ref.read(sessionProvider.notifier).unlockWithBiometric()));

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session is! SessionLocked) return const Scaffold();
    final s = Theme.of(context).colorScheme;
    final user = ref.watch(cloudUserProvider).value;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(AppTheme.space5),
              children: [
                Icon(Icons.lock_rounded, size: 56, color: s.primary),
                const SizedBox(height: AppTheme.space4),
                Text('Vault locked', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: AppTheme.space2),
                Text(
                  user?.email ?? 'This device',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: s.onSurfaceVariant),
                ),
                if (session.reason != null) ...[
                  const SizedBox(height: AppTheme.space3),
                  Text(
                    session.reason!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: s.tertiary),
                  ),
                ],
                const SizedBox(height: AppTheme.space5),
                TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  autofocus: !session.options.biometric,
                  obscureText: _obscure,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: _pinMode ? TextInputType.number : TextInputType.visiblePassword,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: _pinMode ? 'PIN' : 'Master password',
                    errorText: _error,
                    errorMaxLines: 3,
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.space4),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Unlock'),
                ),
                if (session.options.biometric) ...[
                  const SizedBox(height: AppTheme.space3),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _biometric,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: Text(
                      session.options.biometricWithDeviceCredential
                          ? 'Unlock with biometrics or device PIN'
                          : 'Unlock with biometrics',
                    ),
                  ),
                ],
                if (session.options.pin)
                  TextButton(
                    onPressed: () => setState(() {
                      _pinMode = !_pinMode;
                      _error = null;
                    }),
                    child: Text(_pinMode ? 'Use master password' : 'Use PIN'),
                  ),
                const SizedBox(height: AppTheme.space5),
                TextButton(
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      title: user == null ? 'Remove vault from this device?' : 'Log out?',
                      message: user == null
                          ? 'This permanently deletes the vault on this device. Without a backup it cannot be recovered.'
                          : 'This signs you out and removes all vault data from this device. Changes that have not synced yet will be lost.',
                      confirm: user == null ? 'Delete vault' : 'Log out',
                      destructive: true,
                    );
                    if (ok) await ref.read(accountServiceProvider).logout();
                  },
                  child: Text(user == null ? 'Remove vault from this device' : 'Log out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small helper so other screens can wait for an unlock.
Future<void> waitUnlocked(WidgetRef ref) async {
  final c = Completer<void>();
  final sub = ref.listenManual(sessionProvider, (_, s) {
    if (s is SessionUnlocked && !c.isCompleted) c.complete();
  });
  await c.future;
  sub.close();
}
