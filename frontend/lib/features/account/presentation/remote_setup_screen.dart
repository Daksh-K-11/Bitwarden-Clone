import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/common_widgets.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/crypto/crypto_exceptions.dart';
import '../../../core/crypto/key_hierarchy.dart';
import '../account_service.dart';

/// After cloud sign-in on a device without a local vault: either unlock the
/// account's existing vault (download key material) or create a new one.
class RemoteSetupScreen extends ConsumerStatefulWidget {
  const RemoteSetupScreen({super.key});
  @override
  ConsumerState<RemoteSetupScreen> createState() => _RemoteSetupScreenState();
}

class _RemoteSetupScreenState extends ConsumerState<RemoteSetupScreen> {
  late Future<VaultKeyMaterial?> _material;
  final _pw = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _material = ref.read(accountServiceProvider).fetchRemoteMaterial();
  }

  @override
  void dispose() {
    _pw.dispose();
    super.dispose();
  }

  Future<void> _unlock(VaultKeyMaterial m) async {
    setState(() => _busy = true);
    try {
      await ref.read(accountServiceProvider).unlockRemoteVault(m, _pw.text);
    } on DecryptionFailedException {
      if (mounted) showError(context, 'Incorrect master password.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(cloudUserProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your vault'),
        actions: [
          TextButton(onPressed: () => ref.read(authRepositoryProvider).signOut(), child: const Text('Sign out')),
        ],
      ),
      body: FutureBuilder<VaultKeyMaterial?>(
        future: _material,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could not reach the server',
              message: 'Check your connection and try again.',
              action: FilledButton(
                onPressed: () => setState(() => _material = ref.read(accountServiceProvider).fetchRemoteMaterial()),
                child: const Text('Retry'),
              ),
            );
          }
          final m = snap.data;
          if (m == null) {
            return EmptyState(
              icon: Icons.add_moderator_rounded,
              title: 'Set up your vault',
              message: '${user?.email ?? 'This account'} has no vault yet. Create a master password to start.',
              action: FilledButton(
                onPressed: () => context.push('/setup/create'),
                child: const Text('Create master password'),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppTheme.space5),
            children: [
              Text('Unlock your vault', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppTheme.space2),
              Text('Signed in as ${user?.email}. Enter your master password to decrypt your vault on this device.'),
              const SizedBox(height: AppTheme.space5),
              TextField(
                controller: _pw,
                obscureText: _obscure,
                autofocus: true,
                enableSuggestions: false,
                autocorrect: false,
                onSubmitted: (_) => _unlock(m),
                decoration: InputDecoration(
                  labelText: 'Master password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.space5),
              FilledButton(
                onPressed: _busy ? null : () => _unlock(m),
                child: _busy
                    ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Unlock'),
              ),
            ],
          );
        },
      ),
    );
  }
}
