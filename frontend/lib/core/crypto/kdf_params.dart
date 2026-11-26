import 'dart:convert';
import 'dart:typed_data';

import 'crypto_exceptions.dart';

/// Argon2id strength presets.
///
/// OWASP (Password Storage Cheat Sheet) minimums for Argon2id are e.g.
/// m=19 MiB/t=2 or m=46 MiB/t=1 (p=1). libsodium's implementation is
/// single-lane (p=1). All presets exceed those minimums.
enum KdfPreset {
  /// 64 MiB, 3 passes - default; ~0.5-1.5 s on a mid-range phone.
  standard(opsLimit: 3, memLimitKiB: 64 * 1024),

  /// 128 MiB, 4 passes.
  high(opsLimit: 4, memLimitKiB: 128 * 1024),

  /// 256 MiB, 4 passes. May be slow or fail on low-memory devices.
  maximum(opsLimit: 4, memLimitKiB: 256 * 1024);

  const KdfPreset({required this.opsLimit, required this.memLimitKiB});
  final int opsLimit;
  final int memLimitKiB;
}

/// Parameters needed to re-derive the master key. Not secret, but integrity
/// matters: tampering only results in a failed unlock because the wrapped
/// vault key is authenticated under the derived KEK.
class KdfParams {
  const KdfParams({required this.algorithm, required this.opsLimit, required this.memLimitKiB, required this.salt});

  factory KdfParams.fromPreset(KdfPreset preset, Uint8List salt) =>
      KdfParams(algorithm: argon2id13, opsLimit: preset.opsLimit, memLimitKiB: preset.memLimitKiB, salt: salt);

  static const String argon2id13 = 'argon2id13';
  static const int saltLength = 16;

  // Hard bounds applied when *loading* params (e.g. from the cloud) so a
  // tampered profile cannot downgrade derivation or exhaust device memory.
  static const int minOps = 2;
  static const int maxOps = 10;
  static const int minMemKiB = 19 * 1024;
  static const int maxMemKiB = 1024 * 1024;

  final String algorithm;
  final int opsLimit;
  final int memLimitKiB;
  final Uint8List salt;

  int get memLimitBytes => memLimitKiB * 1024;

  void validate() {
    if (algorithm != argon2id13) {
      throw KdfParamsException('Unsupported KDF $algorithm');
    }
    if (opsLimit < minOps || opsLimit > maxOps) {
      throw KdfParamsException('KDF iterations out of range');
    }
    if (memLimitKiB < minMemKiB || memLimitKiB > maxMemKiB) {
      throw KdfParamsException('KDF memory out of range');
    }
    if (salt.length != saltLength) {
      throw KdfParamsException('Invalid salt length');
    }
  }

  Map<String, Object> toJson() => {
    'alg': algorithm,
    'ops': opsLimit,
    'memKiB': memLimitKiB,
    'salt': base64.encode(salt),
  };

  factory KdfParams.fromJson(Map<String, dynamic> json) {
    final params = KdfParams(
      algorithm: json['alg'] as String,
      opsLimit: json['ops'] as int,
      memLimitKiB: json['memKiB'] as int,
      salt: base64.decode(json['salt'] as String),
    );
    params.validate();
    return params;
  }

  String describe() => 'Argon2id, ${memLimitKiB ~/ 1024} MiB, $opsLimit iterations';
}
