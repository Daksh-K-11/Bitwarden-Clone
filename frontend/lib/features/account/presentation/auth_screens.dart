import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/common_widgets.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.space5),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppTheme.space2),
          Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppTheme.space5),
          ...children,
        ],
      ),
    ),
  );
}

class _AccountPasswordNote extends StatelessWidget {
  const _AccountPasswordNote();
  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.space3),
      decoration: BoxDecoration(
        color: s.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 20, color: s.onSecondaryContainer),
          const SizedBox(width: AppTheme.space3),
          Expanded(
            child: Text(
              'This is your account password - it only signs you in. You will create a separate '
              'master password next; that one encrypts your vault and is never sent anywhere.',
              style: TextStyle(color: s.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});
  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_email.text.contains('@') || _password.text.length < 8) {
      showError(context, 'Enter a valid email and an account password of at least 8 characters.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signUp(_email.text, _password.text);
      // Router moves to /auth/verify.
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Create account',
    subtitle: 'Used to sync your encrypted vault between devices.',
    children: [
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      const SizedBox(height: AppTheme.space3),
      TextField(
        controller: _password,
        obscureText: _obscure,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: 'Account password',
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      const SizedBox(height: AppTheme.space3),
      const _AccountPasswordNote(),
      const SizedBox(height: AppTheme.space5),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Create account'),
      ),
    ],
  );
}

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});
  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signIn(_email.text, _password.text);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Sign in',
    subtitle: 'Sign in to your account, then unlock your vault with your master password.',
    children: [
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      const SizedBox(height: AppTheme.space3),
      TextField(
        controller: _password,
        obscureText: _obscure,
        enableSuggestions: false,
        autocorrect: false,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Account password',
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(onPressed: () => context.push('/auth/reset'), child: const Text('Forgot account password?')),
      ),
      const SizedBox(height: AppTheme.space3),
      FilledButton(
        onPressed: _busy ? null : _submit,
        child: _busy
            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
            : const Text('Sign in'),
      ),
    ],
  );
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AuthScaffold(
    title: 'Reset account password',
    subtitle:
        'We will email you a link to reset your account (sign-in) password.\n\n'
        'This cannot recover your master password. Without your master password the vault '
        'cannot be decrypted by anyone - including us.',
    children: [
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Email'),
      ),
      const SizedBox(height: AppTheme.space5),
      FilledButton(
        onPressed: () async {
          try {
            await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
            if (context.mounted) {
              showInfo(context, 'If an account exists, a reset email is on its way.');
              context.pop();
            }
          } catch (e) {
            if (context.mounted) showError(context, e);
          }
        },
        child: const Text('Send reset link'),
      ),
    ],
  );
}

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Gentle polling while this screen is visible (stops once verified).
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => ref.read(authRepositoryProvider).reload());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(cloudUserProvider).value;
    return _AuthScaffold(
      title: 'Verify your email',
      subtitle: 'We sent a verification link to ${user?.email ?? 'your inbox'}. Open it, then come back here.',
      children: [
        FilledButton(
          onPressed: () async {
            await ref.read(authRepositoryProvider).reload();
            final u = ref.read(authRepositoryProvider).currentUser;
            if (context.mounted && u?.emailVerified != true) showInfo(context, 'Not verified yet.');
          },
          child: const Text("I've verified"),
        ),
        const SizedBox(height: AppTheme.space3),
        OutlinedButton(
          onPressed: () async {
            try {
              await ref.read(authRepositoryProvider).sendEmailVerification();
              if (context.mounted) showInfo(context, 'Verification email sent.');
            } catch (e) {
              if (context.mounted) showError(context, e);
            }
          },
          child: const Text('Resend email'),
        ),
        const SizedBox(height: AppTheme.space3),
        TextButton(
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
          child: const Text('Use a different account'),
        ),
      ],
    );
  }
}
