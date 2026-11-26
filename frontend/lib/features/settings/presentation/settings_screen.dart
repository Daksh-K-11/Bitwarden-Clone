import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/common_widgets.dart';
import '../../../app/lock_guard.dart';
import '../../../app/providers.dart';
import '../../../core/config/app_settings.dart';
import '../../../core/crypto/crypto_exceptions.dart';
import '../../../core/storage/secure_store.dart';
import '../../../core/platform/platform_security.dart';
import '../../account/account_service.dart';
import '../../security_health/domain/password_strength.dart';
import '../../session/session_controller.dart';
import '../../sync/sync_controller.dart';
import '../settings_controller.dart';

/// Firebase uid this local vault is connected to (null = not connected).
final boundUidProvider = FutureProvider.autoDispose((ref) {
  ref.watch(cloudUserProvider);
  return ref.read(secureStoreProvider).read(SecureKeys.boundUid);
});

final unlockOptionsProvider = FutureProvider.autoDispose((ref) async {
  ref.watch(sessionProvider);
  final unlock = ref.read(unlockServiceProvider);
  final platform = ref.read(platformSecurityProvider);
  return (await unlock.options(), await platform.biometricStatus());
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final session = ref.watch(sessionProvider);
    final user = ref.watch(cloudUserProvider).value;
    final cloud = ref.watch(cloudConfigProvider);
    final sync = ref.watch(syncProvider);
    final unlock = ref.watch(unlockOptionsProvider);
    final bound = ref.watch(boundUidProvider).value;

    Future<void> set(AppSettings Function(AppSettings) f) => ctrl.update(f);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [
          const SectionHeader('Unlock'),
          unlock.when(
            loading: () => const ListTile(title: Text('Checking device capabilities...')),
            error: (e, _) => ListTile(title: Text('$e')),
            data: (d) {
              final (opts, bio) = d;
              return Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint_rounded),
                    title: const Text('Unlock with biometrics'),
                    subtitle: Text(
                      bio.strongBiometric
                          ? 'Fingerprint / strong face unlock releases a hardware-protected key'
                          : bio.noneEnrolled
                          ? 'Enrol a fingerprint in system settings first'
                          : bio.deviceCredential
                          ? 'Device PIN/pattern can be used'
                          : 'Not available on this device',
                    ),
                    value: opts.biometric,
                    onChanged: !bio.canUseBiometricUnlock && !opts.biometric
                        ? null
                        : (v) => _toggleBiometric(context, ref, v, allowCredential: !bio.strongBiometric),
                  ),
                  if (bio.deviceCredential && opts.biometric)
                    SwitchListTile(
                      secondary: const Icon(Icons.pin_outlined),
                      title: const Text('Allow device PIN / pattern as fallback'),
                      value: opts.biometricWithDeviceCredential,
                      onChanged: (v) => _toggleBiometric(context, ref, true, allowCredential: v),
                    ),
                  SwitchListTile(
                    secondary: const Icon(Icons.dialpad_rounded),
                    title: const Text('Unlock with app PIN'),
                    subtitle: const Text('Disabled automatically after 5 wrong PINs'),
                    value: opts.pin,
                    onChanged: (v) => _togglePin(context, ref, v),
                  ),
                ],
              );
            },
          ),
          const SectionHeader('Vault timeout'),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: const Text('Lock after inactivity'),
            subtitle: Text(AppSettings.timeoutChoices[st.vaultTimeoutSeconds] ?? '${st.vaultTimeoutSeconds}s'),
            onTap: () async {
              final v = await _choose(context, 'Lock after', AppSettings.timeoutChoices, st.vaultTimeoutSeconds);
              if (v != null) await set((s) => s.copyWith(vaultTimeoutSeconds: v));
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.phonelink_lock_rounded),
            title: const Text('Lock when the app goes to background'),
            value: st.lockOnBackground,
            onChanged: (v) => set((s) => s.copyWith(lockOnBackground: v)),
          ),
          ListTile(
            leading: const Icon(Icons.lock_rounded),
            title: const Text('Lock now'),
            onTap: () => ref.read(sessionProvider.notifier).lock(),
          ),
          const SectionHeader('Privacy & clipboard'),
          ListTile(
            leading: const Icon(Icons.content_paste_off_rounded),
            title: const Text('Clear clipboard'),
            subtitle: Text(AppSettings.clipboardChoices[st.clipboardClearSeconds] ?? '${st.clipboardClearSeconds}s'),
            onTap: () async {
              final v = await _choose(
                context,
                'Clear copied values after',
                AppSettings.clipboardChoices,
                st.clipboardClearSeconds,
              );
              if (v != null) await set((s) => s.copyWith(clipboardClearSeconds: v));
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.screenshot_monitor_rounded),
            title: const Text('Block screenshots & recent-apps preview'),
            value: st.blockScreenshots,
            onChanged: (v) => set((s) => s.copyWith(blockScreenshots: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.manage_search_rounded),
            title: const Text('Include notes in search'),
            subtitle: const Text('Notes are indexed in memory only while unlocked'),
            value: st.searchNotes,
            onChanged: (v) => set((s) => s.copyWith(searchNotes: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.travel_explore_rounded),
            title: const Text('Password breach checks'),
            subtitle: const Text('Have I Been Pwned, k-anonymity (5-char hash prefix only)'),
            value: st.breachCheckEnabled,
            onChanged: (v) => set((s) => s.copyWith(breachCheckEnabled: v)),
          ),
          const SectionHeader('Cards'),
          SwitchListTile(
            secondary: const Icon(Icons.verified_user_outlined),
            title: const Text('Authenticate to reveal card details'),
            value: st.requireAuthForCards,
            onChanged: (v) => set((s) => s.copyWith(requireAuthForCards: v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.credit_score_outlined),
            title: const Text('Allow storing card security codes (CVV)'),
            subtitle: const Text('Off by default - see the warning before enabling'),
            value: st.allowCvvStorage,
            onChanged: (v) async {
              if (v) {
                final ok = await confirmDialog(
                  context,
                  title: 'Store card security codes?',
                  message:
                      'With the card number, expiry and CVV together, anyone who obtains your unlocked vault can '
                      'make online purchases. Card-industry rules (PCI DSS) prohibit merchants from storing CVVs at all. '
                      'Your vault is end-to-end encrypted, but storing CVVs increases the impact of a compromise.',
                  confirm: 'Allow',
                );
                if (!ok) return;
              }
              await set((s) => s.copyWith(allowCvvStorage: v));
            },
          ),
          const SectionHeader('Items'),
          SwitchListTile(
            secondary: const Icon(Icons.history_rounded),
            title: const Text('Keep password history'),
            subtitle: Text('Last ${st.passwordHistoryMax} passwords per item, encrypted'),
            value: st.passwordHistoryEnabled,
            onChanged: (v) => set((s) => s.copyWith(passwordHistoryEnabled: v)),
          ),
          ListTile(
            leading: const Icon(Icons.attach_file_rounded),
            title: const Text('Attachment size limit'),
            subtitle: Text('${st.attachmentMaxMb} MB'),
            onTap: () async {
              final v = await _choose(context, 'Maximum attachment size', {
                5: '5 MB',
                10: '10 MB',
                25: '25 MB',
                50: '50 MB',
                100: '100 MB',
              }, st.attachmentMaxMb);
              if (v != null) await set((s) => s.copyWith(attachmentMaxMb: v));
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Manage folders'),
            onTap: () => context.push('/folders'),
          ),
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: const Text('Manage tags'),
            onTap: () => context.push('/tags'),
          ),
          const SectionHeader('Sync'),
          if (!cloud.firebaseReady)
            const ListTile(
              leading: Icon(Icons.cloud_off_rounded),
              title: Text('Offline mode'),
              subtitle: Text('Cloud sync is not configured in this build (see docs/SETUP.md).'),
            )
          else if (user == null)
            ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Sync this vault to the cloud'),
              subtitle: const Text('Sign in or create an account to sync your encrypted vault'),
              onTap: () => _connectCloud(context, ref),
            )
          else if (bound != user.uid)
            ListTile(
              leading: const Icon(Icons.cloud_sync_outlined),
              title: Text('Connect this vault to ${user.email}'),
              subtitle: Text(
                user.emailVerified
                    ? 'Upload your encrypted vault and start syncing'
                    : 'Verify your email first, then tap here',
              ),
              onTap: () async {
                try {
                  final u = await ref.read(authRepositoryProvider).reload();
                  if (u?.emailVerified != true) {
                    if (context.mounted) showInfo(context, 'Email not verified yet - check your inbox.');
                    return;
                  }
                  await ref.read(accountServiceProvider).connectLocalVaultToCloud();
                  ref.invalidate(boundUidProvider);
                  if (context.mounted) showInfo(context, 'Vault connected. Encrypted sync started.');
                } catch (e) {
                  if (context.mounted) showError(context, e);
                }
              },
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(user.email ?? 'Signed in'),
              subtitle: Text(
                sync.lastSyncAt == null
                    ? 'Not synced yet'
                    : 'Last synced ${DateFormat.yMMMd().add_jm().format(sync.lastSyncAt!)}'
                          '${sync.pending > 0 ? ' · ${sync.pending} pending' : ''}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.sync_rounded),
                onPressed: () => ref.read(syncProvider.notifier).syncNow(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.devices_rounded),
              title: const Text('Devices'),
              onTap: () => context.push('/settings/devices'),
            ),
            ListTile(
              leading: const Icon(Icons.call_split_rounded),
              title: const Text('Sync conflicts'),
              onTap: () => context.push('/settings/conflicts'),
            ),
          ],
          const SectionHeader('Backup & data'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup, export & import'),
            subtitle: Text(st.autoBackupEnabled ? 'Automatic daily encrypted backup is on' : 'Automatic backup is off'),
            onTap: () => context.push('/settings/backups'),
          ),
          const SectionHeader('Account & keys'),
          if (session is SessionUnlocked)
            ListTile(
              leading: const Icon(Icons.memory_rounded),
              title: const Text('Key derivation'),
              subtitle: Text(session.material.kdf.describe()),
            ),
          ListTile(
            leading: const Icon(Icons.password_rounded),
            title: const Text('Change master password'),
            onTap: () => _changeMaster(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.autorenew_rounded),
            title: const Text('Rotate vault encryption key'),
            subtitle: const Text('Re-encrypts every item with a new key'),
            onTap: () => _rotate(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: Text(user == null ? 'Remove vault from this device' : 'Log out'),
            onTap: () => _logout(context, ref, user != null),
          ),
          if (user != null)
            ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: Theme.of(context).colorScheme.error),
              title: Text('Delete account', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () => _deleteAccount(context, ref),
            ),
          const SectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_rounded),
                ),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
              ],
              selected: {st.themeMode},
              onSelectionChanged: (v) => set((s) => s.copyWith(themeMode: v.first)),
            ),
          ),
          const SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('How Citadel protects your data'),
            onTap: () => context.push('/settings/about-security'),
          ),
        ],
      ),
    );
  }

  Future<int?> _choose(BuildContext context, String title, Map<int, String> choices, int current) => showDialog<int>(
    context: context,
    builder: (c) => SimpleDialog(
      title: Text(title),
      children: [
        RadioGroup<int>(
          groupValue: current,
          onChanged: (v) => Navigator.pop(c, v),
          child: Column(
            children: [for (final e in choices.entries) RadioListTile<int>(value: e.key, title: Text(e.value))],
          ),
        ),
      ],
    ),
  );

  Future<void> _toggleBiometric(BuildContext context, WidgetRef ref, bool on, {required bool allowCredential}) async {
    final unlock = ref.read(unlockServiceProvider);
    try {
      if (on) {
        final s = ref.read(sessionProvider);
        if (s is! SessionUnlocked) return;
        await LockGuard.run(ref, () => unlock.enableBiometric(s.keys, allowDeviceCredential: allowCredential));
      } else {
        await unlock.disableBiometric();
      }
    } on BiometricException catch (e) {
      if (e.code != BiometricErrorCode.cancelled && context.mounted) {
        showError(context, 'Could not enable biometric unlock.');
      }
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
    ref.invalidate(unlockOptionsProvider);
  }

  Future<void> _togglePin(BuildContext context, WidgetRef ref, bool on) async {
    final unlock = ref.read(unlockServiceProvider);
    if (!on) {
      await unlock.disablePin();
      ref.invalidate(unlockOptionsProvider);
      return;
    }
    final pin = await promptText(
      context,
      title: 'Choose a PIN (4-12 digits)',
      label: 'PIN',
      obscure: true,
      keyboard: TextInputType.number,
    );
    if (pin == null || !context.mounted) return;
    final again = await promptText(
      context,
      title: 'Confirm PIN',
      label: 'PIN',
      obscure: true,
      keyboard: TextInputType.number,
    );
    if (again != pin) {
      if (context.mounted) showError(context, 'PINs do not match.');
      return;
    }
    try {
      final s = ref.read(sessionProvider);
      if (s is SessionUnlocked) await unlock.enablePin(s.keys, pin);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
    ref.invalidate(unlockOptionsProvider);
  }

  Future<void> _changeMaster(BuildContext context, WidgetRef ref) async {
    final current = await promptText(
      context,
      title: 'Current master password',
      label: 'Current master password',
      obscure: true,
      confirm: 'Next',
    );
    if (current == null || !context.mounted) return;
    final next = await promptText(
      context,
      title: 'New master password',
      label: 'New master password (12+ characters)',
      obscure: true,
      confirm: 'Next',
    );
    if (next == null || !context.mounted) return;
    if (next.length < 12 || PasswordStrength.evaluate(next).isWeak) {
      showError(context, 'Choose a stronger master password (12+ characters, not easily guessed).');
      return;
    }
    final confirm = await promptText(
      context,
      title: 'Confirm new master password',
      label: 'New master password',
      obscure: true,
      confirm: 'Change',
    );
    if (confirm != next) {
      if (context.mounted) showError(context, 'Passwords do not match.');
      return;
    }
    try {
      await ref.read(accountServiceProvider).changeMasterPassword(current, next);
      if (context.mounted) {
        showInfo(context, 'Master password changed. Other devices will use it after their next sync.');
      }
    } on DecryptionFailedException {
      if (context.mounted) showError(context, 'Current master password is incorrect.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _rotate(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDialog(
      context,
      title: 'Rotate vault key?',
      message:
          'A new vault key is generated and every item is re-encrypted. Use this if you think your vault key may '
          'have been exposed. Biometric and PIN unlock will be turned off, and other devices will need your master '
          'password. Backups made before rotation still open with the master password of that time.',
      confirm: 'Continue',
    );
    if (!ok || !context.mounted) return;
    final pw = await promptText(
      context,
      title: 'Master password',
      label: 'Master password',
      obscure: true,
      confirm: 'Rotate',
    );
    if (pw == null) return;
    try {
      await ref.read(accountServiceProvider).rotateVaultKey(pw);
      if (context.mounted) showInfo(context, 'Vault key rotated.');
    } on DecryptionFailedException {
      if (context.mounted) showError(context, 'Incorrect master password.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _logout(BuildContext context, WidgetRef ref, bool cloud) async {
    final pending = await ref.read(accountServiceProvider).unsyncedChanges();
    if (!context.mounted) return;
    final ok = await confirmDialog(
      context,
      title: cloud ? 'Log out?' : 'Remove vault from this device?',
      message: cloud
          ? 'All vault data is removed from this device.${pending > 0 ? ' $pending change(s) have not synced yet and will be lost.' : ''}'
          : 'The vault exists only on this device. Removing it deletes it permanently unless you have an encrypted backup.',
      confirm: cloud ? 'Log out' : 'Delete vault',
      destructive: true,
    );
    if (ok) await ref.read(accountServiceProvider).logout();
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final ok = await typedConfirmDialog(
      context,
      title: 'Delete account permanently?',
      message:
          'This deletes your account, all encrypted vault data, devices, attachments and cloud backups from our '
          'servers, and removes the vault from this device. Backups or exports you saved elsewhere are not '
          'affected and cannot be deleted remotely. This cannot be undone.',
      word: 'DELETE',
    );
    if (!ok || !context.mounted) return;
    final pw = await promptText(
      context,
      title: 'Account password',
      label: 'Account (sign-in) password',
      obscure: true,
      confirm: 'Delete account',
    );
    if (pw == null) return;
    try {
      await ref.read(accountServiceProvider).deleteAccount(accountPassword: pw);
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _connectCloud(BuildContext context, WidgetRef ref) async {
    final email = await promptText(
      context,
      title: 'Account email',
      label: 'Email',
      keyboard: TextInputType.emailAddress,
      confirm: 'Next',
    );
    if (email == null || !context.mounted) return;
    final pw = await promptText(
      context,
      title: 'Account password',
      label: 'Account password (not your master password)',
      obscure: true,
      confirm: 'Continue',
    );
    if (pw == null || !context.mounted) return;
    final create = await confirmDialog(
      context,
      title: 'New or existing account?',
      message: 'Create a new account for this email, or sign in to an existing (empty) one?',
      confirm: 'Create new',
    );
    try {
      final auth = ref.read(authRepositoryProvider);
      final user = create ? await auth.signUp(email, pw) : await auth.signIn(email, pw);
      if (!user.emailVerified) {
        if (context.mounted) {
          showInfo(context, 'Verify your email (check your inbox), then tap "Sync this vault" again.');
        }
        return;
      }
      await ref.read(accountServiceProvider).connectLocalVaultToCloud();
      ref.invalidate(boundUidProvider);
      if (context.mounted) showInfo(context, 'Vault connected. Encrypted sync started.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }
}
