import 'dart:math' as math;

import 'word_lists.dart';

/// Source of unbiased cryptographically secure integers in [0, max).
abstract interface class SecureRandomSource {
  int nextInt(int max);
}

/// Fallback backed by the OS CSPRNG through `Random.secure()`.
class DartSecureRandom implements SecureRandomSource {
  final _r = math.Random.secure();
  @override
  int nextInt(int max) => _r.nextInt(max);
}

/// Fisher-Yates shuffle with a secure source.
void secureShuffle<T>(List<T> list, SecureRandomSource rng) {
  for (var i = list.length - 1; i > 0; i--) {
    final j = rng.nextInt(i + 1);
    final t = list[i];
    list[i] = list[j];
    list[j] = t;
  }
}

class PasswordOptions {
  const PasswordOptions({
    this.length = 20,
    this.uppercase = true,
    this.lowercase = true,
    this.digits = true,
    this.symbols = true,
    this.excludeAmbiguous = false,
    this.avoidSimilar = false,
    this.avoidRepeating = false,
    this.customCharset = '',
    this.minDigits = 1,
    this.minSymbols = 1,
  });

  final int length;
  final bool uppercase;
  final bool lowercase;
  final bool digits;
  final bool symbols;

  /// Drops characters that are hard to type or read in some fonts/contexts:
  /// brackets, quotes, slashes, punctuation.
  final bool excludeAmbiguous;

  /// Drops look-alike characters: i l 1 L o 0 O I.
  final bool avoidSimilar;

  /// Each character used at most once.
  final bool avoidRepeating;

  /// If non-empty, replaces all class toggles.
  final String customCharset;
  final int minDigits;
  final int minSymbols;

  PasswordOptions copyWith({
    int? length,
    bool? uppercase,
    bool? lowercase,
    bool? digits,
    bool? symbols,
    bool? excludeAmbiguous,
    bool? avoidSimilar,
    bool? avoidRepeating,
    String? customCharset,
    int? minDigits,
    int? minSymbols,
  }) => PasswordOptions(
    length: length ?? this.length,
    uppercase: uppercase ?? this.uppercase,
    lowercase: lowercase ?? this.lowercase,
    digits: digits ?? this.digits,
    symbols: symbols ?? this.symbols,
    excludeAmbiguous: excludeAmbiguous ?? this.excludeAmbiguous,
    avoidSimilar: avoidSimilar ?? this.avoidSimilar,
    avoidRepeating: avoidRepeating ?? this.avoidRepeating,
    customCharset: customCharset ?? this.customCharset,
    minDigits: minDigits ?? this.minDigits,
    minSymbols: minSymbols ?? this.minSymbols,
  );
}

class GeneratorException implements Exception {
  const GeneratorException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract final class CharSets {
  static const upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const lower = 'abcdefghijklmnopqrstuvwxyz';
  static const digits = '0123456789';
  static const symbols = r'!@#$%^&*()-_=+[]{};:,.<>/?~|';
  static const ambiguous =
      r'{}[]()/\'
      "\"'`~,;:.<>|";
  static const similar = 'il1Lo0OI';
}

class PasswordGenerator {
  PasswordGenerator(this.rng);
  final SecureRandomSource rng;

  static String _filter(String set, PasswordOptions o) {
    var s = set;
    if (o.excludeAmbiguous) {
      s = s.split('').where((c) => !CharSets.ambiguous.contains(c)).join();
    }
    if (o.avoidSimilar) {
      s = s.split('').where((c) => !CharSets.similar.contains(c)).join();
    }
    return s;
  }

  /// Character pools that are enabled, after filtering.
  static List<String> pools(PasswordOptions o) {
    if (o.customCharset.isNotEmpty) {
      final unique = o.customCharset.split('').toSet().join();
      return [_filter(unique, o)].where((p) => p.isNotEmpty).toList();
    }
    return [
      if (o.uppercase) _filter(CharSets.upper, o),
      if (o.lowercase) _filter(CharSets.lower, o),
      if (o.digits) _filter(CharSets.digits, o),
      if (o.symbols) _filter(CharSets.symbols, o),
    ].where((p) => p.isNotEmpty).toList();
  }

  String generate(PasswordOptions o) {
    if (o.length < 4 || o.length > 256) {
      throw const GeneratorException('Length must be between 4 and 256');
    }
    final ps = pools(o);
    if (ps.isEmpty) throw const GeneratorException('Select at least one character set');
    final all = ps.join().split('').toSet().toList();
    if (o.avoidRepeating && o.length > all.length) {
      throw GeneratorException('Only ${all.length} unique characters available');
    }

    final chars = <String>[];
    final used = <String>{};
    String pick(String pool) {
      final candidates = o.avoidRepeating ? pool.split('').where((c) => !used.contains(c)).toList() : pool.split('');
      if (candidates.isEmpty) throw const GeneratorException('Not enough unique characters');
      final c = candidates[rng.nextInt(candidates.length)];
      used.add(c);
      return c;
    }

    // Guarantee at least one of each enabled class (and the minimums).
    if (o.customCharset.isEmpty) {
      for (final p in ps) {
        final isDigits = p.split('').every(CharSets.digits.contains);
        final isSymbols = p.split('').every(CharSets.symbols.contains);
        final count = isDigits ? math.max(1, o.minDigits) : (isSymbols ? math.max(1, o.minSymbols) : 1);
        for (var i = 0; i < count && chars.length < o.length; i++) {
          chars.add(pick(p));
        }
      }
    }
    final union = all.join();
    while (chars.length < o.length) {
      chars.add(pick(union));
    }
    secureShuffle(chars, rng);
    return chars.join();
  }

  /// log2(pool^length) - an upper bound for a truly random password.
  static double entropyBits(PasswordOptions o) {
    final size = pools(o).join().split('').toSet().length;
    if (size <= 1) return 0;
    return o.length * math.log(size) / math.ln2;
  }
}

class PassphraseOptions {
  const PassphraseOptions({
    this.words = 5,
    this.separator = '-',
    this.capitalize = true,
    this.includeNumber = true,
    this.includeSymbol = false,
  });

  final int words;
  final String separator;
  final bool capitalize;
  final bool includeNumber;
  final bool includeSymbol;

  PassphraseOptions copyWith({
    int? words,
    String? separator,
    bool? capitalize,
    bool? includeNumber,
    bool? includeSymbol,
  }) => PassphraseOptions(
    words: words ?? this.words,
    separator: separator ?? this.separator,
    capitalize: capitalize ?? this.capitalize,
    includeNumber: includeNumber ?? this.includeNumber,
    includeSymbol: includeSymbol ?? this.includeSymbol,
  );
}

/// Diceware-style passphrases from the EFF large word list (7,776 words,
/// ~12.9 bits per word).
class PassphraseGenerator {
  PassphraseGenerator(this.rng, this.wordList);
  final SecureRandomSource rng;
  final List<String> wordList;

  String generate(PassphraseOptions o) {
    if (o.words < 3 || o.words > 20) {
      throw const GeneratorException('Use between 3 and 20 words');
    }
    if (wordList.length < 1000) throw const GeneratorException('Word list not loaded');
    final words = List.generate(o.words, (_) {
      final w = wordList[rng.nextInt(wordList.length)];
      return o.capitalize ? '${w[0].toUpperCase()}${w.substring(1)}' : w;
    });
    if (o.includeNumber) {
      final i = rng.nextInt(words.length);
      words[i] = '${words[i]}${rng.nextInt(10)}';
    }
    if (o.includeSymbol) {
      const syms = r'!@#$%^&*';
      final i = rng.nextInt(words.length);
      words[i] = '${words[i]}${syms[rng.nextInt(syms.length)]}';
    }
    return words.join(o.separator);
  }

  double entropyBits(PassphraseOptions o) {
    var bits = o.words * math.log(wordList.length) / math.ln2;
    if (o.includeNumber) bits += math.log(10 * o.words) / math.ln2;
    if (o.includeSymbol) bits += math.log(8 * o.words) / math.ln2;
    return bits;
  }
}

enum UsernameStyle { adjectiveNoun, randomWord, randomCharacters }

class UsernameOptions {
  const UsernameOptions({
    this.style = UsernameStyle.adjectiveNoun,
    this.separator = '_',
    this.capitalize = false,
    this.appendDigits = 3,
    this.length = 10,
  });

  final UsernameStyle style;
  final String separator;
  final bool capitalize;

  /// Number of random digits appended (0 = none).
  final int appendDigits;

  /// For [UsernameStyle.randomCharacters].
  final int length;

  UsernameOptions copyWith({
    UsernameStyle? style,
    String? separator,
    bool? capitalize,
    int? appendDigits,
    int? length,
  }) => UsernameOptions(
    style: style ?? this.style,
    separator: separator ?? this.separator,
    capitalize: capitalize ?? this.capitalize,
    appendDigits: appendDigits ?? this.appendDigits,
    length: length ?? this.length,
  );
}

class UsernameGenerator {
  UsernameGenerator(this.rng, this.wordList);
  final SecureRandomSource rng;
  final List<String> wordList;

  String _cap(String w, bool cap) => cap && w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w;

  String generate(UsernameOptions o) {
    String base;
    switch (o.style) {
      case UsernameStyle.adjectiveNoun:
        final a = WordLists.adjectives[rng.nextInt(WordLists.adjectives.length)];
        final n = WordLists.nouns[rng.nextInt(WordLists.nouns.length)];
        base = '${_cap(a, o.capitalize)}${o.separator}${_cap(n, o.capitalize)}';
      case UsernameStyle.randomWord:
        final list = wordList.isNotEmpty ? wordList : WordLists.nouns;
        base = _cap(list[rng.nextInt(list.length)], o.capitalize);
      case UsernameStyle.randomCharacters:
        const set = 'abcdefghijkmnpqrstuvwxyz23456789';
        final len = o.length.clamp(4, 32);
        base = List.generate(len, (_) => set[rng.nextInt(set.length)]).join();
    }
    if (o.appendDigits > 0 && o.style != UsernameStyle.randomCharacters) {
      final digits = List.generate(o.appendDigits.clamp(0, 8), (_) => rng.nextInt(10)).join();
      base = '$base${o.separator}$digits';
    }
    return base;
  }
}
