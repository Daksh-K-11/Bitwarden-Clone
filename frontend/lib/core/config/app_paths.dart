import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Filesystem layout. Everything lives inside the app sandbox, and only the
/// preview directory ever holds plaintext (decrypted attachment previews).
/// That directory is wiped on lock, on startup and after each use.
class AppPaths {
  AppPaths({required this.support, required this.temp});

  final Directory support;
  final Directory temp;

  File get database => File(p.join(support.path, 'citadel.db'));
  Directory get attachments => Directory(p.join(support.path, 'attachments'));
  Directory get backups => Directory(p.join(support.path, 'backups'));

  /// The only place decrypted files may be written (for "open with").
  Directory get previews => Directory(p.join(temp.path, 'citadel_previews'));

  static Future<AppPaths> resolve() async {
    final paths = AppPaths(support: await getApplicationSupportDirectory(), temp: await getTemporaryDirectory());
    for (final d in [paths.attachments, paths.backups]) {
      await d.create(recursive: true);
    }
    await paths.wipePreviews();
    return paths;
  }

  /// Overwrites then deletes every decrypted preview file.
  Future<void> wipePreviews() async {
    final dir = previews;
    if (!await dir.exists()) return;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        try {
          final len = await entity.length();
          // Best effort overwrite; flash storage may still retain old blocks.
          await entity.writeAsBytes(List<int>.filled(len.clamp(0, 64 * 1024 * 1024), 0), flush: true);
        } catch (_) {}
      }
    }
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  }
}
