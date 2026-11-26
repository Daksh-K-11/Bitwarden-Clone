import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/common_widgets.dart';
import '../../../app/providers.dart';
import '../../../app/theme.dart';
import '../../../core/cloud/cloud_interfaces.dart';

final _devicesProvider = FutureProvider.autoDispose<(List<DeviceRecord>, String)>((ref) async {
  final user = ref.watch(cloudUserProvider).value;
  final remote = ref.read(remoteVaultStoreProvider);
  final me = await ref.read(deviceIdentityProvider).ensure();
  if (user == null || remote == null) return (<DeviceRecord>[], me.deviceId);
  return (await remote.listDevices(user.uid), me.deviceId);
});

/// Authorised devices. Revocation requires re-authentication and takes effect
/// on the revoked device's next sync (it wipes its local vault and signs out).
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(_devicesProvider);
    final user = ref.watch(cloudUserProvider).value;
    final identity = ref.read(deviceIdentityProvider);

    Future<void> revoke(List<DeviceRecord> targets) async {
      final ok = await confirmDialog(
        context,
        title: targets.length == 1 ? 'Revoke "${targets.first.name}"?' : 'Revoke ${targets.length} other devices?',
        message:
            'Revoked devices are signed out and wipe their local vault the next time they connect, and can no longer '
            'sync. Data already on a device that never reconnects cannot be erased remotely - if a device was lost '
            'or stolen, also change your master password and consider rotating your vault key.',
        confirm: 'Revoke',
        destructive: true,
      );
      if (!ok || !context.mounted) return;
      if (!await reauthenticate(ref, 'Confirm to revoke device access')) return;
      try {
        for (final d in targets) {
          await ref.read(remoteVaultStoreProvider)!.revokeDevice(user!.uid, d.deviceId);
        }
        ref.invalidate(_devicesProvider);
      } catch (e) {
        if (context.mounted) showError(context, e);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Devices')),
      body: devices.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(icon: Icons.cloud_off_rounded, title: 'Could not load devices', message: '$e'),
        data: (d) {
          final (list, myId) = d;
          if (user == null) {
            return EmptyState(
              icon: Icons.phone_android_rounded,
              title: 'This device only',
              message:
                  'Device ID ${myId.substring(0, 8)}…\n\nMulti-device management becomes available once cloud sync is enabled.',
            );
          }
          final others = list.where((x) => x.deviceId != myId && !x.revoked).toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_devicesProvider),
            child: ListView(
              padding: const EdgeInsets.all(AppTheme.space4),
              children: [
                for (final dev in list)
                  Card(
                    margin: const EdgeInsets.only(bottom: AppTheme.space3),
                    child: ListTile(
                      leading: Icon(
                        dev.platform == 'ios' ? Icons.phone_iphone_rounded : Icons.phone_android_rounded,
                        color: dev.revoked ? Theme.of(context).colorScheme.error : null,
                      ),
                      title: Row(
                        children: [
                          Flexible(child: Text(dev.name, overflow: TextOverflow.ellipsis)),
                          if (dev.deviceId == myId) ...[
                            const SizedBox(width: 6),
                            const Chip(label: Text('This device'), visualDensity: VisualDensity.compact),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        [
                          dev.osVersion,
                          'Added ${DateFormat.yMMMd().format(dev.createdAt.toLocal())}',
                          'Last active ${DateFormat.yMMMd().add_jm().format(dev.lastActiveAt.toLocal())}',
                          if (dev.revoked) 'REVOKED',
                          identity.verify(user.uid, dev) ? 'Identity key verified' : 'Identity signature invalid',
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'rename') {
                            final name = await promptText(context, title: 'Rename device', initial: dev.name);
                            if (name != null && name.trim().isNotEmpty) {
                              await ref
                                  .read(remoteVaultStoreProvider)!
                                  .renameDevice(user.uid, dev.deviceId, name.trim());
                              ref.invalidate(_devicesProvider);
                            }
                          } else if (v == 'revoke') {
                            await revoke([dev]);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'rename', child: Text('Rename')),
                          if (dev.deviceId != myId && !dev.revoked)
                            const PopupMenuItem(value: 'revoke', child: Text('Revoke access')),
                        ],
                      ),
                    ),
                  ),
                if (others.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => revoke(others),
                    icon: const Icon(Icons.phonelink_erase_rounded),
                    label: const Text('Revoke all other devices'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
