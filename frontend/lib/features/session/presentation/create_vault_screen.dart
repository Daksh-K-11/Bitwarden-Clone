import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/common_widgets.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/crypto/kdf_params.dart';
import '../../account/account_service.dart';
import '../../security_health/domain/password_strength.dart';
import '../../settings/settings_controller.dart';

class CreateVaultScreen extends ConsumerStatefulWidget {
  const CreateVaultScreen({super.key});
  @override
  ConsumerState<CreateVaultScreen> createState() => _CreateVaultScreenState();
}

class _CreateVaultScreenState extends ConsumerState<CreateVaultScreen> {
  final _pw = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _ack = false;
  bool _busy = false;

  @override
  void dispose() {
    _pw.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? get _problem {
    final pw = _pw.text;
    if (pw.length < 12) return 'Use at least 12 characters.';
    if (PasswordStrength.evaluate(pw).isWeak) return 'This master password is too easy to guess.';
    if (pw != _confirm.text) return 'Passwords do not match.';
    if (!_ack) return 'Please confirm you understand there is no recovery.';
    return null;
  }

  Future<void> _create() async {
    final problem = _problem;
    if (problem != null) {
      showError(context, problem);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(accountServiceProvider).createVault(_pw.text);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final preset = ref.watch(settingsProvider).kdfPreset;
    final cloudUser = ref.watch(cloudUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Create master password')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.space5),
          children: [
            Text(
              cloudUser == null
                  ? 'Your master password encrypts this vault on this device.'
                  : 'Your master password encrypts your vault before it is synced to ${cloudUser.email}.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppTheme.space4),
            TextField(
              controller: _pw,
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Master password',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            StrengthMeter(password: _pw.text),
            const SizedBox(height: AppTheme.space3),
            TextField(
              controller: _confirm,
              obscureText: _obscure,
              enableSuggestions: false,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Confirm master password'),
            ),
            const SizedBox(height: AppTheme.space4),
            Text(
              'Tip: a passphrase of 5-6 random words (try the generator later) is both strong and memorable.',
              style: TextStyle(color: s.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.space4),
            Card(
              color: s.errorContainer.withValues(alpha: 0.5),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: s.error),
                        const SizedBox(width: AppTheme.space2),
                        Text('There is no password recovery', style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                    const SizedBox(height: AppTheme.space2),
                    const Text(
                      'Your vault is encrypted with a key derived from this password. It is never stored '
                      'or sent anywhere, so nobody - not even the service operator - can reset it. '
                      'If you forget it and have no unlocked device, your data is permanently lost. '
                      'Keep a written copy somewhere physically safe.',
                    ),
                    CheckboxListTile(
                      value: _ack,
                      onChanged: (v) => setState(() => _ack = v ?? false),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('I understand my master password cannot be recovered'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppTheme.space3),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.memory_rounded),
              title: const Text('Key derivation strength'),
              subtitle: Text(KdfParams.fromPreset(preset, ref.read(cryptoProvider).randomBytes(16)).describe()),
              trailing: DropdownButton<KdfPreset>(
                value: preset,
                underline: const SizedBox.shrink(),
                items: [for (final p in KdfPreset.values) DropdownMenuItem(value: p, child: Text(p.name))],
                onChanged: (p) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(kdfPreset: p)),
              ),
            ),
            const SizedBox(height: AppTheme.space4),
            FilledButton(
              onPressed: _busy ? null : _create,
              child: _busy
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Deriving keys...'),
                      ],
                    )
                  : const Text('Create vault'),
            ),
          ],
        ),
      ),
    );
  }
}
