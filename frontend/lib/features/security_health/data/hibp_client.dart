import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/crypto/crypto_service.dart';

class BreachCheckException implements Exception {
  const BreachCheckException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Have I Been Pwned "Pwned Passwords" range API (k-anonymity).
///
/// 1. SHA-1 the password locally.
/// 2. Send only the first 5 hex characters (20 bits) of the hash.
/// 3. The API returns ~800-1000 suffixes sharing that prefix (plus random
///    padding entries because we send `Add-Padding: true`, so response size
///    does not leak which prefix bucket is "interesting").
/// 4. Compare the remaining 35 characters locally.
///
/// The password, the full hash and the suffix never leave the device. No API
/// key is required for this endpoint. Results are cached in memory only.
class HibpClient {
  HibpClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.pwnedpasswords.com',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'Add-Padding': 'true', 'User-Agent': 'Citadel-Password-Manager'},
              responseType: ResponseType.plain,
            ),
          );

  final Dio _dio;
  final Map<String, Map<String, int>> _cache = {};

  /// Returns how many times the password appears in known breaches (0 = not found).
  Future<int> breachCount(String password) async {
    final hash = CryptoService.sha1HexUpper(utf8.encode(password));
    final prefix = hash.substring(0, 5);
    final suffix = hash.substring(5);
    final bucket = _cache[prefix] ?? await _fetch(prefix);
    return bucket[suffix] ?? 0;
  }

  Future<Map<String, int>> _fetch(String prefix) async {
    try {
      final res = await _dio.get<String>('/range/$prefix');
      final map = <String, int>{};
      for (final line in const LineSplitter().convert(res.data ?? '')) {
        final i = line.indexOf(':');
        if (i <= 0) continue;
        final count = int.tryParse(line.substring(i + 1).trim()) ?? 0;
        if (count > 0) map[line.substring(0, i).trim().toUpperCase()] = count; // 0 = padding
      }
      _cache[prefix] = map;
      return map;
    } on DioException catch (e) {
      // Deliberately generic: never include request details.
      throw BreachCheckException(
        e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout
            ? 'No connection to the breach database'
            : 'Breach check failed',
      );
    }
  }

  void clearCache() => _cache.clear();
}
