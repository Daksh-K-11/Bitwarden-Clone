import 'dart:math' as math;

enum StrengthLevel { veryWeak, weak, fair, strong, veryStrong }

class StrengthResult {
  const StrengthResult(this.level, this.entropyBits, this.feedback);
  final StrengthLevel level;
  final double entropyBits;
  final List<String> feedback;

  bool get isWeak => level.index <= StrengthLevel.weak.index;
}

/// Offline heuristic strength estimator (no network, no logging).
///
/// Computes a conservative entropy estimate from length and character
/// classes, then applies penalties for patterns attackers try first: common
/// passwords, keyboard walks, sequences, repetition, dates and leetspeak.
abstract final class PasswordStrength {
  static const _common = {
    'password',
    'passw0rd',
    '123456',
    '12345678',
    '123456789',
    '1234567890',
    'qwerty',
    'qwertyuiop',
    'abc123',
    'letmein',
    'welcome',
    'monkey',
    'dragon',
    'football',
    'baseball',
    'iloveyou',
    'admin',
    'login',
    'master',
    'sunshine',
    'princess',
    'shadow',
    'superman',
    'trustno1',
    'michael',
    'secret',
    '111111',
    '000000',
    '654321',
    'asdfgh',
    'zxcvbn',
    'starwars',
    'whatever',
    'freedom',
    'hello',
    'charlie',
    'donald',
    'batman',
    'access',
    'flower',
    'mustang',
    'password1',
    'qwerty123',
    'india123',
    'changeme',
    'default',
    'root',
    'toor',
    'pass',
    'test',
    'guest',
    'p@ssw0rd',
    'q1w2e3r4',
    '1q2w3e4r',
  };

  static const _keyboardRows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm', '1234567890'];

  static String _unleet(String s) => s
      .replaceAll('@', 'a')
      .replaceAll('4', 'a')
      .replaceAll('3', 'e')
      .replaceAll('1', 'i')
      .replaceAll('!', 'i')
      .replaceAll('0', 'o')
      .replaceAll(r'$', 's')
      .replaceAll('5', 's')
      .replaceAll('7', 't');

  static StrengthResult evaluate(String password) {
    if (password.isEmpty) return const StrengthResult(StrengthLevel.veryWeak, 0, ['Empty password']);
    final feedback = <String>[];
    final lower = password.toLowerCase();

    var pool = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) pool += 26;
    if (RegExp(r'[A-Z]').hasMatch(password)) pool += 26;
    if (RegExp(r'[0-9]').hasMatch(password)) pool += 10;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) pool += 33;
    if (RegExp(r'[^\x00-\x7F]').hasMatch(password)) pool += 100;

    // Count only "novel" characters: repeated runs add little entropy.
    var effectiveLength = 0.0;
    for (var i = 0; i < password.length; i++) {
      final repeat = i > 0 && password[i] == password[i - 1];
      effectiveLength += repeat ? 0.25 : 1;
    }
    var bits = effectiveLength * (pool <= 1 ? 0 : math.log(pool) / math.ln2);

    final stripped = _unleet(lower).replaceAll(RegExp(r'[^a-z]'), '');
    if (_common.contains(lower) || _common.contains(_unleet(lower)) || _common.contains(stripped)) {
      bits = math.min(bits, 10);
      feedback.add('This is a very common password');
    }
    for (final row in _keyboardRows) {
      for (var len = 4; len <= row.length; len++) {
        for (var i = 0; i + len <= row.length; i++) {
          final walk = row.substring(i, i + len);
          if (lower.contains(walk) || lower.contains(walk.split('').reversed.join())) {
            bits -= len * 2.5;
            feedback.add('Avoid keyboard patterns');
            i = row.length;
            len = row.length + 1;
          }
        }
      }
    }
    if (RegExp(r'(abc|bcd|cde|def|efg|xyz|012|123|234|345|456|567|678|789|890)').hasMatch(lower)) {
      bits -= 6;
      feedback.add('Avoid sequences like "abc" or "123"');
    }
    if (RegExp(r'(19|20)\d{2}').hasMatch(password)) {
      bits -= 5;
      feedback.add('Avoid years and dates');
    }
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) {
      feedback.add('Avoid repeated characters');
    }
    if (password.length < 12) feedback.add('Use at least 12 characters (16+ is better)');

    bits = math.max(0, bits);
    final level = bits < 28
        ? StrengthLevel.veryWeak
        : bits < 40
        ? StrengthLevel.weak
        : bits < 60
        ? StrengthLevel.fair
        : bits < 80
        ? StrengthLevel.strong
        : StrengthLevel.veryStrong;
    return StrengthResult(level, bits, feedback.toSet().toList());
  }
}
