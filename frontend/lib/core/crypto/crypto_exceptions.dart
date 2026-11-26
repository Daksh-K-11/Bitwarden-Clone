/// Crypto errors deliberately carry no key material, plaintext or ciphertext.
sealed class CryptoException implements Exception {
  const CryptoException(this.message);
  final String message;
  @override
  String toString() => '$runtimeType: $message';
}

/// Authentication tag did not verify: wrong key, tampered ciphertext, wrong
/// AAD (e.g. a record swapped under another id), or corruption.
class DecryptionFailedException extends CryptoException {
  const DecryptionFailedException([super.message = 'Decryption failed']);
}

class CryptoFormatException extends CryptoException {
  const CryptoFormatException(super.message);
}

class KdfParamsException extends CryptoException {
  const KdfParamsException(super.message);
}
