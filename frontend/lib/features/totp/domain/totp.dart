import 'dart:typed_data';

import 'package:crypto/crypto.dart';

enum TotpAlgorithm { sha1, sha256, sha512 }

class TotpFormatException implements Exception {
  const TotpFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// RFC 4648 base32 (case-insensitive, padding optional, whitespace ignored).
abstract final class Base32 {
  static const _alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  static Uint8List decode(String input) {
    final clean = input.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '').replaceAll('=', '');
    if (clean.isEmpty) throw const TotpFormatException('Secret is empty');
    final out = BytesBuilder();
    var buffer = 0;
    var bits = 0;
    for (final ch in clean.split('')) {
      final v = _alphabet.indexOf(ch);
      if (v < 0) throw const TotpFormatException('Secret is not valid base32');
      buffer = (buffer << 5) | v;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.addByte((buffer >> bits) & 0xFF);
      }
    }
    return out.takeBytes();
  }

  static String encode(Uint8List data) {
    final sb = StringBuffer();
    var buffer = 0;
    var bits = 0;
    for (final b in data) {
      buffer = (buffer << 8) | b;
      bits += 8;
      while (bits >= 5) {
        bits -= 5;
        sb.write(_alphabet[(buffer >> bits) & 31]);
      }
    }
    if (bits > 0) sb.write(_alphabet[(buffer << (5 - bits)) & 31]);
    return sb.toString();
  }
}

/// A TOTP configuration (RFC 6238). Also supports Steam Guard codes.
class TotpConfig {
  const TotpConfig({
    required this.secret,
    this.algorithm = TotpAlgorithm.sha1,
    this.digits = 6,
    this.period = 30,
    this.issuer,
    this.account,
    this.steam = false,
  });

  final Uint8List secret;
  final TotpAlgorithm algorithm;
  final int digits;
  final int period;
  final String? issuer;
  final String? account;
  final bool steam;

  static const _steamAlphabet = '23456789BCDFGHJKMNPQRTVWXY';

  /// Accepts `otpauth://totp/...`, `steam://SECRET`, or a bare base32 secret.
  static TotpConfig parse(String input) {
    final raw = input.trim();
    if (raw.isEmpty) throw const TotpFormatException('Empty TOTP value');
    final lower = raw.toLowerCase();

    if (lower.startsWith('steam://')) {
      return TotpConfig(secret: Base32.decode(raw.substring(8)), digits: 5, steam: true).._validate();
    }
    if (!lower.startsWith('otpauth://')) {
      return TotpConfig(secret: Base32.decode(raw)).._validate();
    }

    final Uri uri;
    try {
      uri = Uri.parse(raw);
    } on FormatException {
      throw const TotpFormatException('Malformed otpauth URI');
    }
    if (uri.host.toLowerCase() != 'totp') {
      throw const TotpFormatException('Only time-based (TOTP) codes are supported');
    }
    final q = uri.queryParameters.map((k, v) => MapEntry(k.toLowerCase(), v));
    final secret = q['secret'];
    if (secret == null) throw const TotpFormatException('URI has no secret');

    // Label: "Issuer:account" or "account".
    var label = Uri.decodeComponent(uri.path.replaceFirst('/', ''));
    String? labelIssuer;
    String? account = label.isEmpty ? null : label;
    final colon = label.indexOf(':');
    if (colon >= 0) {
      labelIssuer = label.substring(0, colon).trim();
      account = label.substring(colon + 1).trim();
    }

    final alg = switch ((q['algorithm'] ?? 'SHA1').toUpperCase()) {
      'SHA1' => TotpAlgorithm.sha1,
      'SHA256' => TotpAlgorithm.sha256,
      'SHA512' => TotpAlgorithm.sha512,
      final other => throw TotpFormatException('Unsupported algorithm $other'),
    };
    final digits = int.tryParse(q['digits'] ?? '6');
    final period = int.tryParse(q['period'] ?? '30');
    if (digits == null || period == null) {
      throw const TotpFormatException('Invalid digits or period');
    }
    final config = TotpConfig(
      secret: Base32.decode(secret),
      algorithm: alg,
      digits: digits,
      period: period,
      issuer: (q['issuer']?.isNotEmpty ?? false) ? q['issuer'] : labelIssuer,
      account: account,
    );
    config._validate();
    return config;
  }

  static bool isValid(String input) {
    try {
      parse(input);
      return true;
    } on TotpFormatException {
      return false;
    }
  }

  void _validate() {
    if (secret.length < 8) {
      throw const TotpFormatException('Secret is too short (needs at least 8 bytes)');
    }
    if (!steam && (digits < 6 || digits > 10)) {
      throw const TotpFormatException('Digits must be between 6 and 10');
    }
    if (period < 10 || period > 300) {
      throw const TotpFormatException('Period must be between 10 and 300 seconds');
    }
  }

  String toUri() {
    if (steam) return 'steam://${Base32.encode(secret)}';
    final label = [?issuer, ?account].join(':');
    final params = <String, String>{
      'secret': Base32.encode(secret),
      'issuer': ?issuer,
      if (algorithm != TotpAlgorithm.sha1) 'algorithm': algorithm.name.toUpperCase(),
      if (digits != 6) 'digits': '$digits',
      if (period != 30) 'period': '$period',
    };
    return Uri(scheme: 'otpauth', host: 'totp', path: '/$label', queryParameters: params).toString();
  }

  Hash get _hash => switch (algorithm) {
    TotpAlgorithm.sha1 => sha1,
    TotpAlgorithm.sha256 => sha256,
    TotpAlgorithm.sha512 => sha512,
  };

  /// HOTP (RFC 4226) for a given counter.
  String hotp(int counter) {
    final msg = ByteData(8)..setUint64(0, counter);
    final mac = Hmac(_hash, secret).convert(msg.buffer.asUint8List()).bytes;
    final offset = mac.last & 0x0f;
    final binary =
        ((mac[offset] & 0x7f) << 24) |
        ((mac[offset + 1] & 0xff) << 16) |
        ((mac[offset + 2] & 0xff) << 8) |
        (mac[offset + 3] & 0xff);
    if (steam) {
      var v = binary;
      final sb = StringBuffer();
      for (var i = 0; i < 5; i++) {
        sb.write(_steamAlphabet[v % _steamAlphabet.length]);
        v ~/= _steamAlphabet.length;
      }
      return sb.toString();
    }
    var mod = 1;
    for (var i = 0; i < digits; i++) {
      mod *= 10;
    }
    return (binary % mod).toString().padLeft(digits, '0');
  }

  /// TOTP (RFC 6238) at [time].
  String codeAt(DateTime time) => hotp(time.millisecondsSinceEpoch ~/ 1000 ~/ period);

  int secondsRemaining(DateTime time) => period - (time.millisecondsSinceEpoch ~/ 1000) % period;

  String get displayName => issuer?.isNotEmpty == true ? issuer! : (account ?? 'Authenticator');
}

/// Groups a code for readability: "123456" -> "123 456".
String formatTotpCode(String code) {
  if (code.length == 6) return '${code.substring(0, 3)} ${code.substring(3)}';
  if (code.length == 8) return '${code.substring(0, 4)} ${code.substring(4)}';
  return code;
}
