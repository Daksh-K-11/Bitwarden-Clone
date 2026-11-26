import 'dart:convert';
import 'dart:typed_data';

import 'package:citadel/core/crypto/aad.dart';
import 'package:citadel/core/crypto/crypto_exceptions.dart';
import 'package:citadel/core/crypto/crypto_service.dart';
import 'package:citadel/core/crypto/enc_blob.dart';
import 'package:citadel/core/crypto/kdf_params.dart';
import 'package:citadel/core/crypto/key_hierarchy.dart';
import 'package:citadel/core/db/database.dart';
import 'package:citadel/features/vault/data/record_codec.dart';
import 'package:citadel/features/vault/domain/item_type.dart';
import 'package:citadel/features/vault/domain/vault_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';

late CryptoService crypto;

VaultItem sampleItem(String id) => VaultItem(
  id: id,
  type: ItemType.login,
  name: 'Example',
  fields: const {'username': 'alice', 'password': 'hunter2-correct-horse'},
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  setUpAll(() async {
    crypto = CryptoService(await SodiumSumoInit.init());
  });

  group('AEAD envelope', () {
    test('round-trips and binds AAD', () {
      final key = crypto.randomKey();
      final blob = crypto.seal(key, Uint8List.fromList(utf8.encode('secret')), Aad.record('v', 'item', 'a'));
      expect(utf8.decode(crypto.open(key, blob, Aad.record('v', 'item', 'a'))), 'secret');
      // Same ciphertext presented as another record id / kind / vault fails.
      expect(() => crypto.open(key, blob, Aad.record('v', 'item', 'b')), throwsA(isA<DecryptionFailedException>()));
      expect(() => crypto.open(key, blob, Aad.record('v', 'folder', 'a')), throwsA(isA<DecryptionFailedException>()));
      expect(() => crypto.open(key, blob, Aad.record('w', 'item', 'a')), throwsA(isA<DecryptionFailedException>()));
    });

    test('detects tampering anywhere in the envelope', () {
      final key = crypto.randomKey();
      final aad = Aad.record('v', 'item', 'a');
      final bytes = crypto.seal(key, Uint8List.fromList(List.filled(64, 7)), aad).toBytes();
      for (final i in [2, 10, 30, bytes.length - 1]) {
        final copy = Uint8List.fromList(bytes)..[i] ^= 0x01;
        expect(
          () => crypto.open(key, EncBlob.parse(copy), aad),
          throwsA(isA<DecryptionFailedException>()),
          reason: 'byte $i',
        );
      }
    });

    test('rejects unknown envelope versions (no downgrade)', () {
      final key = crypto.randomKey();
      final bytes = crypto.seal(key, Uint8List(4), Uint8List(0)).toBytes()..[0] = 9;
      expect(() => EncBlob.parse(bytes), throwsA(isA<CryptoFormatException>()));
    });

    test('nonces are unique per encryption', () {
      final key = crypto.randomKey();
      final nonces = {for (var i = 0; i < 2000; i++) base64.encode(crypto.seal(key, Uint8List(1), Uint8List(0)).nonce)};
      expect(nonces.length, 2000);
    });
  });

  group('KDF parameters', () {
    test('out-of-range parameters are rejected when loading', () {
      final salt = base64.encode(Uint8List(16));
      expect(
        () => KdfParams.fromJson({'alg': 'argon2id13', 'ops': 1, 'memKiB': 65536, 'salt': salt}),
        throwsA(isA<KdfParamsException>()),
      );
      expect(
        () => KdfParams.fromJson({'alg': 'argon2id13', 'ops': 3, 'memKiB': 1024, 'salt': salt}),
        throwsA(isA<KdfParamsException>()),
      );
      expect(
        () => KdfParams.fromJson({'alg': 'pbkdf2', 'ops': 3, 'memKiB': 65536, 'salt': salt}),
        throwsA(isA<KdfParamsException>()),
      );
    });
  });

  group('Key hierarchy', () {
    late KeyHierarchy h;
    setUp(() => h = KeyHierarchy(crypto));

    test('create -> unlock -> wrong password', () async {
      final (material, keys) = await h.createVault(vaultId: 'vault-1', masterPassword: 'correct horse battery staple');
      expect(material.kdf.salt.length, 16);
      final again = await h.unlock(material, 'correct horse battery staple');
      expect(again.vek == keys.vek, isTrue);
      await expectLater(h.unlock(material, 'wrong password!'), throwsA(isA<DecryptionFailedException>()));
    });

    test('salts are unique per vault', () async {
      final (a, _) = await h.createVault(vaultId: 'a', masterPassword: 'pw-aaaaaaaaaaaa');
      final (b, _) = await h.createVault(vaultId: 'b', masterPassword: 'pw-aaaaaaaaaaaa');
      expect(base64.encode(a.kdf.salt), isNot(base64.encode(b.kdf.salt)));
    });

    test('changing the master password keeps the VEK (no re-encryption)', () async {
      final (material, keys) = await h.createVault(vaultId: 'v', masterPassword: 'old password 123');
      final codec = RecordCodec(crypto);
      final payload = codec.encryptItem(keys, sampleItem('i1'));
      final changed = await h.changeMasterPassword(current: material, unlocked: keys, newPassword: 'new password 456');
      await expectLater(h.unlock(changed, 'old password 123'), throwsA(isA<DecryptionFailedException>()));
      final unlocked = await h.unlock(changed, 'new password 456');
      expect(codec.decryptItem(unlocked, 'i1', payload).name, 'Example');
    });

    test('wrapped VEK cannot be moved to another vault id', () async {
      final (material, _) = await h.createVault(vaultId: 'v1', masterPassword: 'some password 1');
      final moved = VaultKeyMaterial(
        vaultId: 'v2',
        kdf: material.kdf,
        wrappedVek: material.wrappedVek,
        cryptoVersion: 1,
        keyGeneration: 1,
        updatedAt: material.updatedAt,
      );
      await expectLater(h.unlock(moved, 'some password 1'), throwsA(isA<DecryptionFailedException>()));
    });

    test('rotation produces a new VEK and old ciphertext no longer opens', () async {
      final (material, keys) = await h.createVault(vaultId: 'v', masterPassword: 'rotate me please');
      final codec = RecordCodec(crypto);
      final old = codec.encryptItem(keys, sampleItem('x'));
      final (rotated, newKeys) = await h.rotateVaultKey(current: material, masterPassword: 'rotate me please');
      expect(rotated.keyGeneration, 2);
      expect(newKeys.vek == keys.vek, isFalse);
      expect(() => codec.decryptItem(newKeys, 'x', old), throwsA(isA<DecryptionFailedException>()));
      await expectLater(
        h.rotateVaultKey(current: material, masterPassword: 'nope nope nope'),
        throwsA(isA<DecryptionFailedException>()),
      );
    });

    test('subkeys are independent of each other and of the VEK', () async {
      final (_, k) = await h.createVault(vaultId: 'v', masterPassword: 'subkeys subkeys');
      final all = [
        k.vek,
        k.recordKey,
        k.attachmentKey,
        k.backupKey,
        k.conflictKey,
      ].map((s) => base64.encode(s.extractBytes())).toSet();
      expect(all.length, 5);
    });
  });

  group('Record codec', () {
    test('item payload is opaque and id-bound', () async {
      final (_, keys) = await KeyHierarchy(crypto).createVault(vaultId: 'v', masterPassword: 'codec codec codec');
      final codec = RecordCodec(crypto);
      final payload = codec.encryptItem(keys, sampleItem('abc'));
      final text = latin1.decode(payload);
      expect(text.contains('alice'), isFalse);
      expect(text.contains('hunter2'), isFalse);
      expect(() => codec.decryptItem(keys, 'other-id', payload), throwsA(isA<DecryptionFailedException>()));
      expect(() => codec.decrypt(keys, RecordKind.folder, 'abc', payload), throwsA(isA<DecryptionFailedException>()));
    });
  });

  group('Streaming (attachments)', () {
    test('round-trips multi-chunk data and detects truncation', () async {
      final key = crypto.randomKey();
      final data = Uint8List.fromList(List.generate(200 * 1024 + 17, (i) => i % 251));
      final ct = await crypto.encryptBytes(data, key);
      expect(await crypto.decryptBytes(ct, key), data);
      final truncated = Uint8List.sublistView(ct, 0, ct.length - (64 * 1024 + 17));
      await expectLater(crypto.decryptBytes(truncated, key), throwsA(isA<DecryptionFailedException>()));
      final flipped = Uint8List.fromList(ct)..[100] ^= 1;
      await expectLater(crypto.decryptBytes(flipped, key), throwsA(isA<DecryptionFailedException>()));
    });
  });

  group('Device identity', () {
    test('Ed25519 sign/verify and sealed boxes', () {
      final kp = crypto.signingKeyPair();
      final msg = Uint8List.fromList(utf8.encode('register'));
      final sig = crypto.signDetached(msg, kp.secretKey);
      expect(crypto.verifyDetached(msg, sig, kp.publicKey), isTrue);
      expect(crypto.verifyDetached(Uint8List.fromList(utf8.encode('other')), sig, kp.publicKey), isFalse);

      final box = crypto.keyAgreementKeyPair();
      final sealed = crypto.sealToPublicKey(Uint8List.fromList([1, 2, 3]), box.publicKey);
      expect(crypto.openSealed(sealed, box), [1, 2, 3]);
    });
  });
}
