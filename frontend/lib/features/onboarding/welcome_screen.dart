import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cloud = ref.watch(cloudConfigProvider).firebaseReady;
    final s = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [s.primary, s.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Icon(Icons.shield_rounded, size: 48, color: s.onPrimary),
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              Text('Citadel', style: t.headlineMedium),
              const SizedBox(height: AppTheme.space2),
              Text(
                'Your passwords, cards, keys and notes - end-to-end encrypted on this device before they go anywhere.',
                style: t.bodyLarge?.copyWith(color: s.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.space5),
              for (final (icon, text) in const [
                (Icons.key_rounded, 'Zero-knowledge: only your master password can decrypt your vault'),
                (Icons.cloud_off_rounded, 'Works fully offline; syncs encrypted data when online'),
                (Icons.fingerprint_rounded, 'Unlock with fingerprint, device PIN or an app PIN'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space3),
                  child: Row(
                    children: [
                      Icon(icon, size: 20, color: s.primary),
                      const SizedBox(width: AppTheme.space3),
                      Expanded(child: Text(text, style: t.bodyMedium)),
                    ],
                  ),
                ),
              const Spacer(flex: 2),
              if (cloud) ...[
                FilledButton(onPressed: () => context.push('/auth/sign-up'), child: const Text('Create account')),
                const SizedBox(height: AppTheme.space3),
                OutlinedButton(onPressed: () => context.push('/auth/sign-in'), child: const Text('Sign in')),
                const SizedBox(height: AppTheme.space2),
                TextButton(
                  onPressed: () => context.push('/setup/create'),
                  child: const Text('Use offline on this device only'),
                ),
              ] else ...[
                FilledButton(
                  onPressed: () => context.push('/setup/create'),
                  child: const Text('Create a vault on this device'),
                ),
                const SizedBox(height: AppTheme.space3),
                Text(
                  'Cloud sync is not configured in this build. Your vault stays on this device; '
                  'use encrypted backups to keep a copy elsewhere.',
                  textAlign: TextAlign.center,
                  style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
