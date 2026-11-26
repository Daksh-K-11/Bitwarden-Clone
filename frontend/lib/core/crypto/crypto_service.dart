import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as dart_crypto;
import 'package:sodium/sodium_sumo.dart';

import 'crypto_exceptions.dart';
import 'enc_blob.dart';
import 'kdf_params.dart';

/// Thin, opinionated facade over libsodium (audited C library, via FFI).
///
/// Nothing in this file implements a primitive by hand:
///  * Argon2id          -> crypto_pwhash (ALG_ARGON2ID13)
///  * XChaCha20-Poly1305 -> crypto_aead_xchacha20poly1305_ietf
///  * HKDF-SHA-256      -> crypto_kdf_hkdf_sha256
///  * File streaming    -> crypto_secretstream_xchacha20poly1305
///  * Ed25519 / X25519  -> crypto_sign / crypto_box(_seal)
///  * CSPRNG            -> randombytes (OS entropy)
///
/// Keys are held as [SecureKey]: sodium_malloc'd, guard-paged, mlock'ed,
/// PROT_NOACCESS while not in use, and zeroed on dispose().
class CryptoService {
  CryptoService(this.sodium);

  final SodiumSumo sodium;

  static const int keyLength = 32;

  /// Plaintext chunk size for streamed (attachment/backup) encryption.
  static const int streamChunkSize = 64 * 1024;

  // ----------------------------------------------------------------- random

  Uint8List randomBytes(int length) => sodium.randombytes.buf(length);

  /// Unbiased uniform integer in [0, upperBound) from the CSPRNG
  /// (libsodium randombytes_uniform uses rejection sampling).
  int randomUniform(int upperBound) => sodium.randombytes.uniform(upperBound);

  SecureKey randomKey() => sodium.secureRandom(keyLength);

  SecureKey keyFromBytes(Uint8List bytes) => sodium.secureCopy(bytes);

  // -------------------------------------------------------------------- KDF

  /// Derives the 32-byte master key with Argon2id. Runs on a background
  /// isolate so the UI stays responsive while ~64-256 MiB are hashed.
  Future<SecureKey> deriveMasterKey(String password, KdfParams params) async {
    params.validate();
    final ops = params.opsLimit;
    final mem = params.memLimitBytes;
    final salt = Uint8List.fromList(params.salt);
    final s = sodium;
    return s.runIsolated((_, _) {
      return s.crypto.pwhash.callStr(
        outLen: keyLength,
        password: password,
        salt: salt,
        opsLimit: ops,
        memLimit: mem,
        alg: CryptoPwhashAlgorithm.argon2id13,
      );
    });
  }

  /// HKDF-SHA-256 expand. [prk] must be a uniformly random 32-byte key
  /// (Argon2id output or a CSPRNG key), so the extract step is unnecessary.
  /// [context] is the HKDF "info" and provides domain separation.
  SecureKey hkdf(SecureKey prk, String context, {int length = keyLength}) =>
      sodium.crypto.kdfHkdfSha256.expand(masterKey: prk, context: context, outLen: length);

  // ------------------------------------------------------------------- AEAD

  Aead get _aead => sodium.crypto.aeadXChaCha20Poly1305IETF;

  /// Encrypts with a fresh random 192-bit nonce. The envelope header
  /// (version, algorithm) is authenticated together with [aad].
  EncBlob seal(SecureKey key, Uint8List plaintext, Uint8List aad) {
    final nonce = randomBytes(_aead.nonceBytes);
    final header = Uint8List.fromList([EncBlob.formatV1, EncBlob.algXChaCha20Poly1305]);
    final ct = _aead.encrypt(message: plaintext, nonce: nonce, key: key, additionalData: _concat(header, aad));
    return EncBlob(version: EncBlob.formatV1, alg: EncBlob.algXChaCha20Poly1305, nonce: nonce, cipherText: ct);
  }

  Uint8List open(SecureKey key, EncBlob blob, Uint8List aad) {
    try {
      return _aead.decrypt(
        cipherText: blob.cipherText,
        nonce: blob.nonce,
        key: key,
        additionalData: _concat(blob.header, aad),
      );
    } on SodiumException {
      throw const DecryptionFailedException();
    }
  }

  EncBlob sealJson(SecureKey key, Object json, Uint8List aad) =>
      seal(key, Uint8List.fromList(utf8.encode(jsonEncode(json))), aad);

  Map<String, dynamic> openJson(SecureKey key, EncBlob blob, Uint8List aad) {
    final bytes = open(key, blob, aad);
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  }

  /// Wraps (encrypts) one key under another.
  EncBlob wrapKey(SecureKey wrappingKey, SecureKey key, Uint8List aad) =>
      key.runUnlockedSync((bytes) => seal(wrappingKey, bytes, aad));

  SecureKey unwrapKey(SecureKey wrappingKey, EncBlob blob, Uint8List aad) {
    final raw = open(wrappingKey, blob, aad);
    try {
      if (raw.length != keyLength) {
        throw const CryptoFormatException('Wrapped key has wrong length');
      }
      return sodium.secureCopy(raw);
    } finally {
      raw.fillRange(0, raw.length, 0);
    }
  }

  // ------------------------------------------------------------ streaming

  /// Streams plaintext through secretstream. Output = 24-byte header followed
  /// by authenticated chunks; the final chunk carries the FINAL tag so
  /// truncation is detected on decryption.
  Stream<List<int>> encryptStream(Stream<List<int>> plaintext, SecureKey key) =>
      sodium.crypto.secretStream.pushChunked(messageStream: plaintext, key: key, chunkSize: streamChunkSize);

  Stream<List<int>> decryptStream(Stream<List<int>> cipherText, SecureKey key) =>
      sodium.crypto.secretStream.pullChunked(cipherStream: cipherText, key: key, chunkSize: streamChunkSize);

  Future<Uint8List> encryptBytes(Uint8List plaintext, SecureKey key) =>
      _collect(encryptStream(Stream.value(plaintext), key));

  Future<Uint8List> decryptBytes(Uint8List cipherText, SecureKey key) async {
    try {
      return await _collect(decryptStream(Stream.value(cipherText), key));
    } on SodiumException {
      throw const DecryptionFailedException('Encrypted file is corrupt or was modified');
    } on StreamClosedEarlyException {
      throw const DecryptionFailedException('Encrypted file is truncated');
    }
  }

  // ---------------------------------------------------- asymmetric (device)

  KeyPair signingKeyPair() => sodium.crypto.sign.keyPair();

  KeyPair keyAgreementKeyPair() => sodium.crypto.box.keyPair();

  Uint8List signDetached(Uint8List message, SecureKey secretKey) =>
      sodium.crypto.sign.detached(message: message, secretKey: secretKey);

  bool verifyDetached(Uint8List message, Uint8List signature, Uint8List publicKey) =>
      sodium.crypto.sign.verifyDetached(message: message, signature: signature, publicKey: publicKey);

  /// Anonymous public-key encryption (X25519 + XSalsa20-Poly1305). Used to
  /// hand the vault key to a newly enrolled device without the server or the
  /// master password being involved.
  Uint8List sealToPublicKey(Uint8List message, Uint8List publicKey) =>
      sodium.crypto.box.seal(message: message, publicKey: publicKey);

  Uint8List openSealed(Uint8List cipherText, KeyPair recipient) => sodium.crypto.box.sealOpen(
    cipherText: cipherText,
    publicKey: recipient.publicKey,
    secretKey: recipient.secretKey,
  );

  // ---------------------------------------------------------------- hashing

  static String sha256Hex(List<int> data) => dart_crypto.sha256.convert(data).toString();

  static String sha1HexUpper(List<int> data) => dart_crypto.sha1.convert(data).toString().toUpperCase();

  /// Constant-time comparison.
  bool constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    return sodium.memcmp(a, b);
  }

  // ---------------------------------------------------------------- helpers

  static Uint8List _concat(Uint8List a, Uint8List b) {
    final out = Uint8List(a.length + b.length);
    out.setRange(0, a.length, a);
    out.setRange(a.length, out.length, b);
    return out;
  }

  static Future<Uint8List> _collect(Stream<List<int>> stream) async {
    final builder = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }
}
