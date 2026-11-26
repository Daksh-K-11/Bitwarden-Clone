// Runs the unit-test suite on a real device (libsodium + SQLCipher as
// shipped). Usage: flutter test integration_test -d <device-id>
import 'package:integration_test/integration_test.dart';

import '../test/backup_format_test.dart' as backup;
import '../test/crypto_test.dart' as crypto;
import '../test/generator_test.dart' as generator;
import '../test/import_export_test.dart' as import_export;
import '../test/sync_engine_test.dart' as sync;
import '../test/totp_test.dart' as totp;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  crypto.main();
  totp.main();
  generator.main();
  import_export.main();
  backup.main();
  sync.main();
}
