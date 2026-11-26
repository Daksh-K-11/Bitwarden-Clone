import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import 'cloud_interfaces.dart';

/// Cloudflare R2 access through the Citadel broker API (see /backend).
///
/// The app never holds R2 credentials. It asks the broker - authenticated
/// with a short-lived Firebase ID token - for a presigned URL scoped to one
/// object key under `users/{uid}/...`, valid for a few minutes, then talks to
/// R2 directly. Every byte uploaded is already encrypted on the device.
class R2ObjectStorage implements ObjectStorage {
  R2ObjectStorage({
    required this.apiBaseUrl,
    required Future<String?> Function() idToken,
    Future<String?> Function()? appCheckToken,
    Dio? dio,
  }) : _idToken = idToken, // ignore: prefer_initializing_formals
       _appCheckToken = appCheckToken, // ignore: prefer_initializing_formals
       _api = dio ?? Dio(BaseOptions(baseUrl: apiBaseUrl, connectTimeout: const Duration(seconds: 15))),
       _raw = Dio(BaseOptions(connectTimeout: const Duration(seconds: 20)));

  final String apiBaseUrl;
  final Future<String?> Function() _idToken;
  final Future<String?> Function()? _appCheckToken;
  final Dio _api;
  final Dio _raw;

  static const _maxAttempts = 4;

  @override
  bool get available => apiBaseUrl.isNotEmpty;

  Future<Map<String, String>> _headers() async {
    final token = await _idToken();
    if (token == null) throw const ObjectStorageException('Not signed in', retryable: false);
    final appCheck = await _appCheckToken?.call();
    return {'Authorization': 'Bearer $token', 'X-Firebase-AppCheck': ?appCheck};
  }

  Future<Map<String, dynamic>> _broker(String path, Map<String, Object> body) async {
    try {
      final res = await _api.post<Map<String, dynamic>>(
        path,
        data: body,
        options: Options(headers: await _headers()),
      );
      return res.data!;
    } on DioException catch (e) {
      final code = e.response?.statusCode ?? 0;
      throw ObjectStorageException('Storage broker error ($code)', retryable: code == 0 || code >= 500 || code == 429);
    }
  }

  Future<T> _retry<T>(Future<T> Function() fn) async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await fn();
      } on ObjectStorageException catch (e) {
        if (!e.retryable || attempt >= _maxAttempts) rethrow;
      } on DioException {
        if (attempt >= _maxAttempts) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 500 * (1 << attempt)));
    }
  }

  @override
  Future<void> upload(
    ObjectKind kind,
    String objectId,
    File encryptedFile, {
    required String sha256,
    void Function(int sent, int total)? onProgress,
  }) async {
    final size = await encryptedFile.length();
    await _retry(() async {
      // A fresh URL per attempt: interrupted uploads simply restart (single
      // PUT is idempotent; objects are capped well below R2's 5 GiB limit).
      final grant = await _broker('/v1/storage/upload-url', {
        'kind': kind.name,
        'objectId': objectId,
        'size': size,
        'sha256': sha256,
      });
      final headers = (grant['headers'] as Map?)?.cast<String, String>() ?? const {};
      await _raw.put<void>(
        grant['url'] as String,
        data: encryptedFile.openRead(),
        options: Options(headers: {...headers, Headers.contentLengthHeader: size}),
        onSendProgress: onProgress,
      );
    });
  }

  @override
  Future<void> download(
    ObjectKind kind,
    String objectId,
    File destination, {
    void Function(int received, int total)? onProgress,
  }) async {
    await _retry(() async {
      final grant = await _broker('/v1/storage/download-url', {'kind': kind.name, 'objectId': objectId});
      final tmp = File('${destination.path}.part');
      await _raw.download(grant['url'] as String, tmp.path, onReceiveProgress: onProgress);
      await tmp.rename(destination.path);
    });
  }

  @override
  Future<void> delete(ObjectKind kind, String objectId) =>
      _retry(() => _broker('/v1/storage/delete', {'kind': kind.name, 'objectId': objectId}));

  @override
  Future<void> deleteAll() => _retry(() => _broker('/v1/account/purge-objects', {'confirm': true}));

  static Future<String> sha256OfFile(File f) async => (await sha256.bind(f.openRead()).first).toString();
}

class UnavailableObjectStorage implements ObjectStorage {
  const UnavailableObjectStorage();
  Never _no() => throw const ObjectStorageException('Cloud storage is not configured', retryable: false);
  @override
  bool get available => false;
  @override
  Future<void> upload(
    ObjectKind kind,
    String objectId,
    File encryptedFile, {
    required String sha256,
    void Function(int, int)? onProgress,
  }) async => _no();
  @override
  Future<void> download(
    ObjectKind kind,
    String objectId,
    File destination, {
    void Function(int, int)? onProgress,
  }) async => _no();
  @override
  Future<void> delete(ObjectKind kind, String objectId) async => _no();
  @override
  Future<void> deleteAll() async {}
}
