import 'package:flutter/services.dart';
import 'package:citadel/features/generator/domain/generators.dart';
import 'package:citadel/features/security_health/domain/password_strength.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final rng = DartSecureRandom();
  final gen = PasswordGenerator(rng);

  test('respects length and always includes each enabled class', () {
    for (var i = 0; i < 200; i++) {
      final p = gen.generate(const PasswordOptions(length: 12));
      expect(p.length, 12);
      expect(RegExp('[A-Z]').hasMatch(p), isTrue);
      expect(RegExp('[a-z]').hasMatch(p), isTrue);
      expect(RegExp('[0-9]').hasMatch(p), isTrue);
      expect(RegExp(r'[^A-Za-z0-9]').hasMatch(p), isTrue);
    }
  });

  test('exclusions are honoured', () {
    for (var i = 0; i < 200; i++) {
      final p = gen.generate(const PasswordOptions(length: 40, excludeAmbiguous: true, avoidSimilar: true));
      for (final c in CharSets.similar.split('')) {
        expect(p.contains(c), isFalse, reason: 'similar $c');
      }
      for (final c in CharSets.ambiguous.split('')) {
        expect(p.contains(c), isFalse, reason: 'ambiguous $c');
      }
    }
  });

  test('no repeated characters when requested', () {
    for (var i = 0; i < 100; i++) {
      final p = gen.generate(const PasswordOptions(length: 50, avoidRepeating: true));
      expect(p.split('').toSet().length, 50);
    }
    expect(
      () => gen.generate(
        const PasswordOptions(length: 20, uppercase: false, lowercase: false, symbols: false, avoidRepeating: true),
      ),
      throwsA(isA<GeneratorException>()),
    );
  });

  test('custom charset', () {
    final p = gen.generate(const PasswordOptions(length: 30, customCharset: 'abc'));
    expect(RegExp(r'^[abc]{30}$').hasMatch(p), isTrue);
  });

  test('roughly uniform distribution (chi-square sanity)', () {
    const opts = PasswordOptions(length: 64, uppercase: false, symbols: false, digits: false);
    final counts = <String, int>{};
    for (var i = 0; i < 400; i++) {
      for (final c in gen.generate(opts).split('')) {
        counts[c] = (counts[c] ?? 0) + 1;
      }
    }
    final total = counts.values.reduce((a, b) => a + b);
    final expected = total / 26;
    final chi = counts.values.fold<double>(0, (a, o) => a + (o - expected) * (o - expected) / expected);
    // 25 degrees of freedom; p=0.0001 critical value ~ 59.
    expect(chi, lessThan(59));
  });

  test('passphrases use the EFF list', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString('assets/wordlists/eff_large.txt');
    final words = raw.split('\n').where((w) => w.isNotEmpty).toList();
    expect(words.length, 7776);
    final pg = PassphraseGenerator(rng, words);
    final p = pg.generate(const PassphraseOptions(words: 6, separator: '-', capitalize: false, includeNumber: false));
    final parts = p.split('-');
    expect(parts.length, 6);
    for (final w in parts) {
      expect(words.contains(w), isTrue);
    }
    expect(pg.entropyBits(const PassphraseOptions(words: 6, includeNumber: false)), closeTo(77.5, 0.1));
  });

  test('usernames', () {
    final u = UsernameGenerator(rng, const []).generate(const UsernameOptions(appendDigits: 4, separator: '.'));
    expect(RegExp(r'^[a-z]+\.[a-z]+\.\d{4}$').hasMatch(u), isTrue);
  });

  test('strength estimator flags weak passwords', () {
    expect(PasswordStrength.evaluate('password1').isWeak, isTrue);
    expect(PasswordStrength.evaluate('P@ssw0rd').isWeak, isTrue);
    expect(PasswordStrength.evaluate('qwertyuiop').isWeak, isTrue);
    expect(PasswordStrength.evaluate('aaaaaaaaaaaaaaaa').isWeak, isTrue);
    expect(PasswordStrength.evaluate(gen.generate(const PasswordOptions(length: 20))).level, StrengthLevel.veryStrong);
  });
}
