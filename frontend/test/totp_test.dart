import 'dart:convert';
import 'dart:typed_data';

import 'package:citadel/features/totp/domain/totp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RFC 6238 test vectors (Appendix B)', () {
    final seeds = {
      TotpAlgorithm.sha1: '12345678901234567890',
      TotpAlgorithm.sha256: '12345678901234567890123456789012',
      TotpAlgorithm.sha512: '1234567890123456789012345678901234567890123456789012345678901234',
    };
    const vectors = <int, Map<TotpAlgorithm, String>>{
      59: {TotpAlgorithm.sha1: '94287082', TotpAlgorithm.sha256: '46119246', TotpAlgorithm.sha512: '90693936'},
      1111111109: {TotpAlgorithm.sha1: '07081804', TotpAlgorithm.sha256: '68084774', TotpAlgorithm.sha512: '25091201'},
      1111111111: {TotpAlgorithm.sha1: '14050471', TotpAlgorithm.sha256: '67062674', TotpAlgorithm.sha512: '99943326'},
      1234567890: {TotpAlgorithm.sha1: '89005924', TotpAlgorithm.sha256: '91819424', TotpAlgorithm.sha512: '93441116'},
      2000000000: {TotpAlgorithm.sha1: '69279037', TotpAlgorithm.sha256: '90698825', TotpAlgorithm.sha512: '38618901'},
      20000000000: {TotpAlgorithm.sha1: '65353130', TotpAlgorithm.sha256: '77737706', TotpAlgorithm.sha512: '47863826'},
    };
    vectors.forEach((t, expected) {
      expected.forEach((alg, code) {
        test('$alg @ $t', () {
          final cfg = TotpConfig(secret: Uint8List.fromList(utf8.encode(seeds[alg]!)), algorithm: alg, digits: 8);
          expect(cfg.codeAt(DateTime.fromMillisecondsSinceEpoch(t * 1000, isUtc: true)), code);
        });
      });
    });
  });

  test('base32 round trip and leniency', () {
    final data = Uint8List.fromList(utf8.encode('12345678901234567890'));
    final enc = Base32.encode(data);
    expect(enc, 'GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ');
    expect(Base32.decode(enc.toLowerCase()), data);
    expect(Base32.decode('gezd gnbv-gy3t qojq gezd gnbv gy3t qojq===='), data);
    expect(() => Base32.decode('not!base32'), throwsA(isA<TotpFormatException>()));
  });

  test('parses otpauth URIs', () {
    final c = TotpConfig.parse(
      'otpauth://totp/ACME%20Co:john@example.com?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&issuer=ACME%20Co&algorithm=SHA256&digits=8&period=60',
    );
    expect(c.issuer, 'ACME Co');
    expect(c.account, 'john@example.com');
    expect(c.algorithm, TotpAlgorithm.sha256);
    expect(c.digits, 8);
    expect(c.period, 60);
    // Round-trip.
    final back = TotpConfig.parse(c.toUri());
    expect(back.codeAt(DateTime.utc(2026)), c.codeAt(DateTime.utc(2026)));
  });

  test('accepts a bare secret and rejects invalid configs', () {
    expect(TotpConfig.parse('JBSWY3DPEHPK3PXP').digits, 6);
    expect(
      () => TotpConfig.parse('otpauth://hotp/x?secret=JBSWY3DPEHPK3PXP&counter=1'),
      throwsA(isA<TotpFormatException>()),
    );
    expect(
      () => TotpConfig.parse('otpauth://totp/x?secret=JBSWY3DPEHPK3PXP&digits=3'),
      throwsA(isA<TotpFormatException>()),
    );
    expect(
      () => TotpConfig.parse('otpauth://totp/x?secret=JBSWY3DPEHPK3PXP&algorithm=MD5'),
      throwsA(isA<TotpFormatException>()),
    );
    expect(() => TotpConfig.parse('otpauth://totp/x?secret=AB'), throwsA(isA<TotpFormatException>()));
    expect(TotpConfig.isValid('hello world'), isFalse);
  });

  test('remaining seconds and Steam codes', () {
    final c = TotpConfig.parse('JBSWY3DPEHPK3PXP');
    expect(c.secondsRemaining(DateTime.fromMillisecondsSinceEpoch(29 * 1000, isUtc: true)), 1);
    expect(c.secondsRemaining(DateTime.fromMillisecondsSinceEpoch(30 * 1000, isUtc: true)), 30);
    final steam = TotpConfig.parse('steam://JBSWY3DPEHPK3PXP');
    final code = steam.codeAt(DateTime.utc(2026));
    expect(code.length, 5);
    expect(RegExp(r'^[23456789BCDFGHJKMNPQRTVWXY]{5}$').hasMatch(code), isTrue);
  });
}
