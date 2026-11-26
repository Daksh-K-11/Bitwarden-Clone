import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/cloud/cloud_interfaces.dart';
import '../features/account/presentation/auth_screens.dart';
import '../features/account/presentation/remote_setup_screen.dart';
import '../features/attachments/presentation/attachment_preview_screen.dart';
import '../features/backup/presentation/backup_screen.dart';
import '../features/devices/presentation/devices_screen.dart';
import '../features/folders/presentation/folders_screen.dart';
import '../features/folders/presentation/tags_screen.dart';
import '../features/generator/presentation/generator_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/security_health/presentation/security_screen.dart';
import '../features/session/presentation/create_vault_screen.dart';
import '../features/session/presentation/lock_screen.dart';
import '../features/session/session_controller.dart';
import '../features/settings/presentation/about_security_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/sync/presentation/conflicts_screen.dart';
import '../features/totp/presentation/authenticator_screen.dart';
import '../features/totp/presentation/qr_scan_screen.dart';
import '../features/vault/domain/item_type.dart';
import '../features/vault/domain/vault_models.dart';
import '../features/vault/presentation/item_detail_screen.dart';
import '../features/vault/presentation/item_edit_screen.dart';
import '../features/vault/presentation/vault_screen.dart';
import 'home_shell.dart';
import 'providers.dart';

class _RouterRefresh extends ChangeNotifier {
  void ping() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(sessionProvider, (_, _) => refresh.ping());
  ref.listen(cloudUserProvider, (_, _) => refresh.ping());
  ref.onDispose(refresh.dispose);

  const publicPaths = {'/welcome', '/auth/sign-in', '/auth/sign-up', '/auth/reset', '/setup/create'};

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final session = ref.read(sessionProvider);
      final CloudUser? user = ref.read(cloudUserProvider).value;
      switch (session) {
        case SessionLoading():
          return loc == '/splash' ? null : '/splash';
        case SessionNoVault():
          if (user != null && !user.emailVerified) return loc == '/auth/verify' ? null : '/auth/verify';
          if (user != null) return loc == '/setup/remote' || loc == '/setup/create' ? null : '/setup/remote';
          return publicPaths.contains(loc) ? null : '/welcome';
        case SessionLocked():
          return loc == '/lock' ? null : '/lock';
        case SessionUnlocked():
          if (loc == '/splash' ||
              loc == '/lock' ||
              publicPaths.contains(loc) ||
              loc.startsWith('/setup') ||
              loc.startsWith('/auth')) {
            return '/vault';
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/auth/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/auth/sign-up', builder: (_, _) => const SignUpScreen()),
      GoRoute(path: '/auth/verify', builder: (_, _) => const VerifyEmailScreen()),
      GoRoute(path: '/auth/reset', builder: (_, _) => const ResetPasswordScreen()),
      GoRoute(path: '/setup/create', builder: (_, _) => const CreateVaultScreen()),
      GoRoute(path: '/setup/remote', builder: (_, _) => const RemoteSetupScreen()),
      GoRoute(path: '/lock', builder: (_, _) => const LockScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/vault', builder: (_, _) => const VaultScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/authenticator', builder: (_, _) => const AuthenticatorScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/generator', builder: (_, _) => const GeneratorScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/security', builder: (_, _) => const SecurityScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/item/new',
        builder: (_, s) => ItemEditScreen(
          newType: ItemType.values.asNameMap()[s.uri.queryParameters['type']] ?? ItemType.login,
          folderId: s.uri.queryParameters['folder'],
          prefill: s.extra is Map ? (s.extra! as Map).cast<String, String>() : const {},
        ),
      ),
      GoRoute(
        path: '/item/:id',
        builder: (_, s) => ItemDetailScreen(itemId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/item/:id/edit',
        builder: (_, s) => ItemEditScreen(itemId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/attachment',
        builder: (_, s) {
          final (item, meta) = s.extra! as (VaultItem, AttachmentMeta);
          return AttachmentPreviewScreen(item: item, meta: meta);
        },
      ),
      GoRoute(path: '/folders', builder: (_, _) => const FoldersScreen()),
      GoRoute(path: '/tags', builder: (_, _) => const TagsScreen()),
      GoRoute(
        path: '/scan',
        builder: (_, s) => QrScanScreen(returnResult: s.extra == 'return'),
      ),
      GoRoute(path: '/settings/backups', builder: (_, _) => const BackupScreen()),
      GoRoute(path: '/settings/devices', builder: (_, _) => const DevicesScreen()),
      GoRoute(path: '/settings/conflicts', builder: (_, _) => const ConflictsScreen()),
      GoRoute(path: '/settings/about-security', builder: (_, _) => const AboutSecurityScreen()),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Icon(Icons.shield_rounded, size: 72, color: Theme.of(context).colorScheme.primary)),
  );
}
