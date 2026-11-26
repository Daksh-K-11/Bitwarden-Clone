import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';

/// Plain-language summary of the security model (full detail: docs/SECURITY.md).
class AboutSecurityScreen extends StatelessWidget {
  const AboutSecurityScreen({super.key});

  static const _sections = [
    (
      Icons.key_rounded,
      'Your master password never leaves this device',
      'It is stretched with Argon2id (memory-hard, unique random salt) into a key-encryption key. That key '
          'unwraps a random 256-bit vault key, which encrypts everything. Neither the password nor any key is '
          'ever stored in plaintext, logged, or sent to a server.',
    ),
    (
      Icons.lock_rounded,
      'Every item is sealed individually',
      'Each record is encrypted with XChaCha20-Poly1305 using a fresh random nonce, and authenticated together '
          'with its vault id and record id - so ciphertext cannot be swapped between items or accounts without '
          'detection. The local database is additionally encrypted with SQLCipher.',
    ),
    (
      Icons.cloud_rounded,
      'The cloud only ever sees ciphertext',
      'Firebase stores encrypted records and minimal sync metadata (ids, revision numbers, timestamps). '
          'Attachments and backups are encrypted on the device before they are uploaded to object storage. '
          'Your account password (sign-in) and your master password (encryption) are completely separate.',
    ),
    (
      Icons.fingerprint_rounded,
      'Biometrics release a key - they do not replace it',
      'With biometric unlock enabled, your vault key is wrapped by a hardware-backed Android Keystore key that '
          'the OS only uses after a successful fingerprint or device-credential check. Re-enrolling biometrics '
          'invalidates it. App PINs are stretched with Argon2id and disabled after 5 wrong attempts.',
    ),
    (
      Icons.content_paste_off_rounded,
      'Clipboard and screen protection',
      'Copied secrets are marked sensitive and cleared after a timeout - only if the clipboard still holds the '
          'value we copied. Screenshots and the recent-apps preview are blocked by default.',
    ),
    (
      Icons.report_problem_rounded,
      'If you forget your master password',
      'Nobody can recover your vault - not us, not the cloud provider. An unlocked device can still export '
          'your data or change the password. Otherwise the data is permanently inaccessible. Keep a written copy '
          'of your master password and use encrypted backups.',
    ),
    (
      Icons.devices_other_rounded,
      'Limits of revocation and deletion',
      'Revoking a device stops it syncing and makes it wipe its vault when it next connects, but a device that '
          'never reconnects keeps whatever it already decrypted. Deleting your account removes server-side data; '
          'backups or exports you saved elsewhere cannot be deleted remotely.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Security model')),
    body: ListView(
      padding: const EdgeInsets.all(AppTheme.space4),
      children: [
        for (final (icon, title, body) in _sections)
          Card(
            margin: const EdgeInsets.only(bottom: AppTheme.space3),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.space4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: AppTheme.space4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 6),
                        Text(body),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
