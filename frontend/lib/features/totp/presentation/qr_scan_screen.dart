import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../app/common_widgets.dart';
import '../../../app/theme.dart';
import '../../vault/application/vault_controller.dart';
import '../../vault/domain/item_type.dart';
import '../domain/totp.dart';
import 'totp_widgets.dart';

/// Scans `otpauth://` QR codes. Decoding happens on-device (ML Kit bundled
/// model on Android, Vision on iOS); frames are never stored or uploaded.
class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key, this.returnResult = false});

  /// Pop with the URI (used from the item editor) instead of creating an item.
  final bool returnResult;

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  TotpConfig? _found;
  String? _uri;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_found != null) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      if (!raw.toLowerCase().startsWith('otpauth://')) {
        setState(
          () => _error = raw.toLowerCase().startsWith('otpauth-migration://')
              ? 'Google Authenticator export codes are not supported yet. Add accounts individually.'
              : 'This QR code is not an authenticator setup code.',
        );
        continue;
      }
      try {
        final cfg = TotpConfig.parse(raw);
        _controller.stop();
        setState(() {
          _found = cfg;
          _uri = raw;
          _error = null;
        });
        return;
      } on TotpFormatException catch (e) {
        setState(() => _error = e.message);
      }
    }
  }

  Future<void> _attachToExisting() async {
    final logins = ref.read(vaultProvider).items.values.where((i) => i.type == ItemType.login && !i.isTrashed).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final id = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (c) => DraggableScrollableSheet(
        expand: false,
        builder: (c, scroll) => ListView(
          controller: scroll,
          children: [
            for (final l in logins)
              ListTile(title: Text(l.name), subtitle: Text(l.field('username')), onTap: () => Navigator.pop(c, l.id)),
          ],
        ),
      ),
    );
    if (id == null) return;
    final item = ref.read(vaultProvider).items[id]!;
    if ((item.totp ?? '').isNotEmpty && mounted) {
      final ok = await confirmDialog(
        context,
        title: 'Replace existing code?',
        message: '${item.name} already has an authenticator key.',
        confirm: 'Replace',
      );
      if (!ok) return;
    }
    await ref.read(vaultProvider.notifier).saveItem(item.copyWith(totp: _uri));
    if (mounted) context.pushReplacement('/item/$id');
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR code')),
      body: found == null
          ? Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => EmptyState(
                    icon: Icons.no_photography_outlined,
                    title: 'Camera unavailable',
                    message: error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? 'Allow camera access in system settings, or enter the key manually.'
                        : 'The camera could not be started.',
                  ),
                ),
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                if (_error != null)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 32,
                    child: Card(
                      child: Padding(padding: const EdgeInsets.all(AppTheme.space3), child: Text(_error!)),
                    ),
                  ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(AppTheme.space5),
              children: [
                Icon(Icons.check_circle_rounded, size: 56, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: AppTheme.space3),
                Text(found.displayName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                if (found.account != null) Text(found.account!, textAlign: TextAlign.center),
                const SizedBox(height: AppTheme.space4),
                const Text('Check that this code matches what the website expects:', textAlign: TextAlign.center),
                const SizedBox(height: AppTheme.space2),
                Center(child: TotpCodeView(config: found)),
                Text(
                  '${found.algorithm.name.toUpperCase()} · ${found.digits} digits · ${found.period}s',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppTheme.space5),
                if (widget.returnResult)
                  FilledButton(onPressed: () => context.pop(_uri), child: const Text('Use this key'))
                else ...[
                  FilledButton(
                    onPressed: () => context.pushReplacement('/item/new?type=login', extra: {'totp': _uri!}),
                    child: const Text('Save as new login'),
                  ),
                  const SizedBox(height: AppTheme.space3),
                  OutlinedButton(onPressed: _attachToExisting, child: const Text('Add to an existing login')),
                ],
                TextButton(
                  onPressed: () {
                    setState(() {
                      _found = null;
                      _uri = null;
                    });
                    _controller.start();
                  },
                  child: const Text('Scan again'),
                ),
              ],
            ),
    );
  }
}
