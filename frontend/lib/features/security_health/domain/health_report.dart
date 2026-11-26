import '../../vault/domain/item_type.dart';
import '../../vault/domain/vault_models.dart';
import 'password_strength.dart';

class HealthReport {
  const HealthReport({
    required this.weak,
    required this.reused,
    required this.old,
    required this.missingTotp,
    required this.totalWithPassword,
  });

  final List<VaultItem> weak;

  /// Groups of items sharing the same password (each group has >= 2 items).
  final List<List<VaultItem>> reused;
  final List<VaultItem> old;
  final List<VaultItem> missingTotp;
  final int totalWithPassword;

  int get reusedItemCount => reused.fold(0, (a, g) => a + g.length);

  /// 0-100 score; purely informational.
  int get score {
    if (totalWithPassword == 0) return 100;
    final bad = {...weak.map((e) => e.id), ...reused.expand((g) => g).map((e) => e.id)}.length;
    return (100 * (1 - bad / totalWithPassword)).round().clamp(0, 100);
  }
}

/// Computes health purely in memory from the decrypted snapshot. Passwords
/// are compared with an in-memory map that is dropped right after.
abstract final class HealthAnalyzer {
  static const oldAfter = Duration(days: 365);

  static HealthReport analyze(Iterable<VaultItem> items, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final active = items.where((i) => !i.isTrashed && !i.archived).toList();
    final withPassword = active.where((i) => _password(i).isNotEmpty).toList();

    final weak = <VaultItem>[];
    final byPassword = <String, List<VaultItem>>{};
    final old = <VaultItem>[];
    for (final item in withPassword) {
      final pw = _password(item);
      if (PasswordStrength.evaluate(pw).isWeak) weak.add(item);
      (byPassword[pw] ??= []).add(item);
      final changed = item.passwordUpdatedAt ?? item.createdAt;
      if (t.difference(changed) > oldAfter) old.add(item);
    }
    final reused = byPassword.values.where((g) => g.length > 1).toList();
    byPassword.clear();

    final missingTotp = active
        .where((i) => i.type == ItemType.login && _password(i).isNotEmpty && (i.totp ?? '').isEmpty)
        .toList();

    return HealthReport(
      weak: weak,
      reused: reused,
      old: old,
      missingTotp: missingTotp,
      totalWithPassword: withPassword.length,
    );
  }

  static String _password(VaultItem i) => i.fields['password'] ?? '';
}
