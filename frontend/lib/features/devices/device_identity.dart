import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:sodium/sodium_sumo.dart';
import 'package:uuid/uuid.dart';

import '../../core/cloud/cloud_interfaces.dart';
import '../../core/crypto/crypto_service.dart';
import '../../core/storage/secure_store.dart';

/// This device's cryptographic identity.
///
/// * Ed25519 signing key: device identity; signs its registration statement
///   (and, in the multi-device enrollment flow, approval messages).
/// * X25519 key: lets an already-trusted device seal the vault key directly to
///   this device (crypto_box_seal) so a new device can be enrolled without the
///   server ever seeing the VEK. (Master-password enrollment is the default.)
///
/// Secret keys live in OS secure storage; only public keys are uploaded.
class DeviceIdentity {
  DeviceIdentity({required this.deviceId, required this.signing, required this.keyAgreement, required this.createdAt});

  final String deviceId;
  final KeyPair signing;
  final KeyPair keyAgreement;
  final DateTime createdAt;

  String get signPublicKeyB64 => base64.encode(signing.publicKey);
  String get kxPublicKeyB64 => base64.encode(keyAgreement.publicKey);

  /// Canonical registration statement bound to the account.
  Uint8List registrationStatement(String uid) => Uint8List.fromList(
    utf8.encode('citadel-device-registration:v1|$uid|$deviceId|$signPublicKeyB64|$kxPublicKeyB64'),
  );
}

class DeviceIdentityService {
  DeviceIdentityService(this.crypto, this.store);

  final CryptoService crypto;
  final SecureStore store;
  DeviceIdentity? _cached;

  Future<DeviceIdentity> ensure() async {
    if (_cached != null) return _cached!;
    final raw = await store.read(SecureKeys.deviceIdentity);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final signSk = base64.decode(j['signSk'] as String);
      final kxSk = base64.decode(j['kxSk'] as String);
      final id = DeviceIdentity(
        deviceId: j['deviceId'] as String,
        signing: KeyPair(publicKey: base64.decode(j['signPk'] as String), secretKey: crypto.keyFromBytes(signSk)),
        keyAgreement: KeyPair(publicKey: base64.decode(j['kxPk'] as String), secretKey: crypto.keyFromBytes(kxSk)),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
      signSk.fillRange(0, signSk.length, 0);
      kxSk.fillRange(0, kxSk.length, 0);
      return _cached = id;
    }
    final sign = crypto.signingKeyPair();
    final kx = crypto.keyAgreementKeyPair();
    final identity = DeviceIdentity(
      deviceId: const Uuid().v4(),
      signing: sign,
      keyAgreement: kx,
      createdAt: DateTime.now().toUtc(),
    );
    await store.write(
      SecureKeys.deviceIdentity,
      jsonEncode({
        'deviceId': identity.deviceId,
        'signPk': base64.encode(sign.publicKey),
        'signSk': sign.secretKey.runUnlockedSync(base64.encode),
        'kxPk': base64.encode(kx.publicKey),
        'kxSk': kx.secretKey.runUnlockedSync(base64.encode),
        'createdAt': identity.createdAt.toIso8601String(),
      }),
    );
    return _cached = identity;
  }

  Future<DeviceRecord> describe(String uid) async {
    final id = await ensure();
    final info = DeviceInfoPlugin();
    var name = 'This device';
    var model = '';
    var os = Platform.operatingSystemVersion;
    var platform = Platform.operatingSystem;
    try {
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        model = '${a.manufacturer} ${a.model}';
        name = model;
        os = 'Android ${a.version.release} (API ${a.version.sdkInt})';
        platform = 'android';
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        model = i.utsname.machine;
        name = i.name;
        os = '${i.systemName} ${i.systemVersion}';
        platform = 'ios';
      }
    } catch (_) {}
    final signature = crypto.signDetached(id.registrationStatement(uid), id.signing.secretKey);
    return DeviceRecord(
      deviceId: id.deviceId,
      name: name,
      platform: platform,
      osVersion: os,
      model: model,
      createdAt: id.createdAt,
      lastActiveAt: DateTime.now(),
      signPublicKey: id.signPublicKeyB64,
      kxPublicKey: id.kxPublicKeyB64,
      registrationSignature: base64.encode(signature),
    );
  }

  /// Verifies a device's self-signature (shown as "verified" in the UI).
  bool verify(String uid, DeviceRecord d) {
    try {
      final stmt = utf8.encode('citadel-device-registration:v1|$uid|${d.deviceId}|${d.signPublicKey}|${d.kxPublicKey}');
      return crypto.verifyDetached(
        Uint8List.fromList(stmt),
        base64.decode(d.registrationSignature),
        base64.decode(d.signPublicKey),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> forget() async {
    _cached?.signing.dispose();
    _cached?.keyAgreement.dispose();
    _cached = null;
    await store.delete(SecureKeys.deviceIdentity);
  }
}
