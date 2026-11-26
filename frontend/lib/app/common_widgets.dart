import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../core/clipboard/clipboard_service.dart';
import '../features/security_health/domain/password_strength.dart';
import '../features/settings/settings_controller.dart';
import 'lock_guard.dart';
import 'providers.dart';
import 'theme.dart';

final clipboardServiceProvider = Provider<ClipboardService>((ref) {
  final svc = ClipboardService(
    ref.watch(platformSecurityProvider),
    timeoutSeconds: () => ref.read(settingsProvider).clipboardClearSeconds,
  );
  ref.onDispose(svc.dispose);
  return svc;
});

/// Copies one value with auto-clear and shows a small confirmation.
Future<void> copySecret(
  BuildContext context,
  WidgetRef ref,
  String value,
  String label, {
  bool sensitive = true,
}) async {
  if (value.isEmpty) return;
  HapticFeedback.selectionClick();
  await ref.read(clipboardServiceProvider).copy(value, sensitive: sensitive);
  if (!context.mounted) return;
  final secs = ref.read(settingsProvider).clipboardClearSeconds;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(secs > 0 ? '$label copied · clears in ${secs}s' : '$label copied'),
      ),
    );
}

final _localAuth = LocalAuthentication();

/// Device re-authentication (biometric or device PIN) before revealing or
/// copying especially sensitive values. This is a UX gate on top of an
/// already-unlocked vault - the cryptographic protection is the vault key.
Future<bool> reauthenticate(WidgetRef ref, String reason) async {
  try {
    final supported = await _localAuth.isDeviceSupported();
    if (!supported) return true; // no device credential configured
    return await LockGuard.run(
      ref,
      () => _localAuth.authenticate(localizedReason: reason, biometricOnly: false, persistAcrossBackgrounding: true),
    );
  } catch (_) {
    return false;
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Confirm',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Asks for typed confirmation for irreversible actions.
Future<bool> typedConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String word,
}) async {
  final ctrl = TextEditingController();
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Text('Type "$word" to confirm', style: Theme.of(c).textTheme.labelMedium),
            const SizedBox(height: 8),
            TextField(controller: ctrl, autofocus: true, onChanged: (_) => set(() {})),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: ctrl.text.trim().toUpperCase() == word.toUpperCase() ? () => Navigator.pop(c, true) : null,
            child: const Text('Delete'),
          ),
        ],
      ),
    ),
  );
  ctrl.dispose();
  return r ?? false;
}

Future<String?> promptText(
  BuildContext context, {
  required String title,
  String? initial,
  String label = 'Name',
  bool obscure = false,
  String confirm = 'Save',
  TextInputType? keyboard,
}) async {
  final ctrl = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        obscureText: obscure,
        keyboardType: keyboard,
        enableSuggestions: !obscure,
        autocorrect: false,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => Navigator.pop(c, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(confirm)),
      ],
    ),
  );
  ctrl.dispose();
  return r;
}

void showError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      content: Text('$error', style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
    ),
  );
}

void showInfo(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(AppTheme.space4, AppTheme.space5, AppTheme.space4, AppTheme.space2),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: s.primaryContainer.withValues(alpha: 0.5), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: s.primary),
            ),
            const SizedBox(height: AppTheme.space4),
            Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: AppTheme.space2),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: s.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[const SizedBox(height: AppTheme.space5), action!],
          ],
        ),
      ),
    );
  }
}

/// Letter avatar for items. No favicon fetching: requesting icons from a
/// third-party service would leak which sites are in the vault.
class ItemAvatar extends StatelessWidget {
  const ItemAvatar({super.key, required this.name, required this.icon, this.size = 40});
  final String name;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final palette = [s.primaryContainer, s.secondaryContainer, s.tertiaryContainer];
    final bg = palette[name.isEmpty ? 0 : name.codeUnitAt(0) % palette.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(size * 0.3)),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.5, color: s.onPrimaryContainer),
    );
  }
}

class StrengthMeter extends StatelessWidget {
  const StrengthMeter({super.key, required this.password, this.showFeedback = true});
  final String password;
  final bool showFeedback;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final r = PasswordStrength.evaluate(password);
    final s = Theme.of(context).colorScheme;
    final (label, color) = switch (r.level) {
      StrengthLevel.veryWeak => ('Very weak', s.error),
      StrengthLevel.weak => ('Weak', Colors.deepOrange),
      StrengthLevel.fair => ('Fair', Colors.amber.shade700),
      StrengthLevel.strong => ('Strong', Colors.green),
      StrengthLevel.veryStrong => ('Very strong', Colors.green.shade800),
    };
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.space2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (r.level.index + 1) / StrengthLevel.values.length,
                    color: color,
                    backgroundColor: s.surfaceContainerHighest,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.space3),
              Text(
                '$label · ${r.entropyBits.round()} bits',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
          if (showFeedback && r.feedback.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                r.feedback.first,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: s.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

/// Monospace, character-coloured rendering of a revealed secret.
class SecretText extends StatelessWidget {
  const SecretText(this.value, {super.key, this.maxLines});
  final String value;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final base = Theme.of(context).textTheme.bodyLarge?.copyWith(fontFamily: 'monospace', letterSpacing: 0.5);
    return Text.rich(
      TextSpan(
        children: [
          for (final ch in value.characters)
            TextSpan(
              text: ch,
              style: RegExp(r'[0-9]').hasMatch(ch)
                  ? base?.copyWith(color: s.primary)
                  : RegExp(r'[A-Za-z]').hasMatch(ch)
                  ? base
                  : base?.copyWith(color: s.tertiary),
            ),
        ],
      ),
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
