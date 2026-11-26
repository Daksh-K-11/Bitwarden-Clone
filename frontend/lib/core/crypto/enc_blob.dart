import 'dart:convert';
import 'dart:typed_data';

import 'crypto_exceptions.dart';

/// Versioned authenticated-encryption envelope.
///
/// Binary layout (v1):
/// ```
/// +---------+---------+----------------+------------------------------+
/// | version | alg id  | nonce (24 B)   | ciphertext || Poly1305 tag  |
/// | 1 byte  | 1 byte  |                | (plaintext len + 16 B)        |
/// +---------+---------+----------------+------------------------------+
/// ```
/// The two header bytes are always prepended to the caller-supplied AAD, so a
/// downgrade/algorithm-confusion attempt fails authentication.
class EncBlob {
  EncBlob({required this.version, required this.alg, required this.nonce, required this.cipherText});

  static const int formatV1 = 1;

  /// XChaCha20-Poly1305-IETF (libsodium `crypto_aead_xchacha20poly1305_ietf`).
  /// 192-bit random nonces make accidental reuse negligible even for
  /// billions of messages under one key.
  static const int algXChaCha20Poly1305 = 1;

  static const int nonceLength = 24;
  static const int tagLength = 16;
  static const int headerLength = 2;

  final int version;
  final int alg;
  final Uint8List nonce;
  final Uint8List cipherText;

  Uint8List get header => Uint8List.fromList([version, alg]);

  Uint8List toBytes() {
    final out = Uint8List(headerLength + nonce.length + cipherText.length);
    out[0] = version;
    out[1] = alg;
    out.setRange(headerLength, headerLength + nonce.length, nonce);
    out.setRange(headerLength + nonce.length, out.length, cipherText);
    return out;
  }

  String toBase64() => base64.encode(toBytes());

  static EncBlob parse(Uint8List bytes) {
    if (bytes.length < headerLength + nonceLength + tagLength) {
      throw const CryptoFormatException('Ciphertext too short');
    }
    final version = bytes[0];
    final alg = bytes[1];
    if (version != formatV1) {
      throw CryptoFormatException('Unsupported envelope version $version');
    }
    if (alg != algXChaCha20Poly1305) {
      throw CryptoFormatException('Unsupported algorithm $alg');
    }
    return EncBlob(
      version: version,
      alg: alg,
      nonce: Uint8List.sublistView(bytes, headerLength, headerLength + nonceLength),
      cipherText: Uint8List.sublistView(bytes, headerLength + nonceLength),
    );
  }

  static EncBlob fromBase64(String value) => parse(base64.decode(value));
}
