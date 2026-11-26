import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/common_widgets.dart';
import '../../../app/lock_guard.dart';
import '../../../app/theme.dart';
import '../../vault/application/vault_controller.dart';
import '../../vault/domain/vault_models.dart';
import '../attachment_service.dart';

/// In-memory preview. Decrypted bytes live only in this widget's state and
/// are zeroed on dispose. Images and text render inline; everything else
/// can be saved to a user-chosen location (never opened/executed).
class AttachmentPreviewScreen extends ConsumerStatefulWidget {
  const AttachmentPreviewScreen({super.key, required this.item, required this.meta});
  final VaultItem item;
  final AttachmentMeta meta;
  @override
  ConsumerState<AttachmentPreviewScreen> createState() => _AttachmentPreviewScreenState();
}

class _AttachmentPreviewScreenState extends ConsumerState<AttachmentPreviewScreen> {
  Uint8List? _bytes;
  Object? _error;
  double? _progress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final b = await ref
          .read(attachmentServiceProvider)
          .open(widget.meta, onProgress: (r, t) => setState(() => _progress = t > 0 ? r / t : null));
      if (mounted) setState(() => _bytes = b);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _bytes?.fillRange(0, _bytes!.length, 0);
    super.dispose();
  }

  bool get _isImage => widget.meta.mimeType.startsWith('image/') && !widget.meta.mimeType.contains('svg');
  bool get _isText =>
      widget.meta.mimeType.startsWith('text/') ||
      const ['application/json', 'application/xml', 'application/x-pem-file'].contains(widget.meta.mimeType) ||
      RegExp(
        r'\.(txt|md|pem|pub|key|crt|cer|csr|conf|ini|log|json|yaml|yml)$',
        caseSensitive: false,
      ).hasMatch(widget.meta.fileName);

  @override
  Widget build(BuildContext context) {
    final m = widget.meta;
    return Scaffold(
      appBar: AppBar(
        title: Text(m.fileName, overflow: TextOverflow.ellipsis),
        actions: [
          if (_bytes != null)
            IconButton(
              tooltip: 'Save to device',
              icon: const Icon(Icons.download_rounded),
              onPressed: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Save decrypted copy?',
                  message: 'The saved file will NOT be encrypted. Anyone with access to where you save it can read it.',
                  confirm: 'Save',
                );
                if (!ok) return;
                await LockGuard.run(
                  ref,
                  () => FilePicker.saveFile(fileName: m.fileName, bytes: _bytes!, mimeType: m.mimeType),
                );
              },
            ),
          IconButton(
            tooltip: 'Delete attachment',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await confirmDialog(
                context,
                title: 'Delete attachment?',
                message: m.fileName,
                confirm: 'Delete',
                destructive: true,
              );
              if (!ok) return;
              final item = ref.read(vaultProvider).items[widget.item.id];
              if (item != null) {
                await ref
                    .read(vaultProvider.notifier)
                    .saveItem(item.copyWith(attachments: item.attachments.where((a) => a.id != m.id).toList()));
              }
              await ref.read(attachmentServiceProvider).delete(m);
              if (context.mounted) context.pop();
            },
          ),
        ],
      ),
      body: _error != null
          ? EmptyState(icon: Icons.gpp_bad_outlined, title: 'Could not open attachment', message: '$_error')
          : _bytes == null
          ? Center(child: CircularProgressIndicator(value: _progress))
          : _isImage
          ? InteractiveViewer(child: Center(child: Image.memory(_bytes!, gaplessPlayback: true)))
          : _isText
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.space4),
              child: SelectableText(
                utf8.decode(_bytes!, allowMalformed: true),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            )
          : EmptyState(
              icon: Icons.insert_drive_file_outlined,
              title: m.fileName,
              message:
                  '${m.mimeType} · ${(m.size / 1024).toStringAsFixed(1)} KB\n\nNo in-app preview for this type. '
                  'Use "Save to device" to open it with another app.',
            ),
    );
  }
}
