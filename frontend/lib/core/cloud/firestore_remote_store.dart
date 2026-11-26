import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../crypto/key_hierarchy.dart';
import '../db/database.dart';
import 'cloud_interfaces.dart';

/// Cloud Firestore layout
/// ```
/// users/{uid}/meta/keys          VaultKeyMaterial (salt, KDF params, wrapped VEK)
/// users/{uid}/records/{id}       {kind, v, payload: bytes, rev, deleted, kg,
///                                 createdAt, updatedAt (server time), deviceId}
/// users/{uid}/devices/{deviceId} device registry (public keys, revoked flag)
/// users/{uid}/backups/{id}       index of encrypted backups stored in R2
/// ```
/// Items, folders and tags share one `records` collection so an incremental
/// sync is a single ordered query (fewer reads than one query per type).
/// Every `payload` is ciphertext produced on the client.
class FirestoreRemoteVaultStore implements RemoteVaultStore {
  FirestoreRemoteVaultStore(this._fs);

  final FirebaseFirestore _fs;

  DocumentReference<Map<String, dynamic>> _user(String uid) => _fs.collection('users').doc(uid);
  DocumentReference<Map<String, dynamic>> _keys(String uid) => _user(uid).collection('meta').doc('keys');
  CollectionReference<Map<String, dynamic>> _records(String uid) => _user(uid).collection('records');
  CollectionReference<Map<String, dynamic>> _devices(String uid) => _user(uid).collection('devices');
  CollectionReference<Map<String, dynamic>> _backups(String uid) => _user(uid).collection('backups');

  // ------------------------------------------------------------ key material

  @override
  Future<VaultKeyMaterial?> fetchKeyMaterial(String uid) async {
    final snap = await _keys(uid).get(const GetOptions(source: Source.server));
    final data = snap.data();
    if (data == null) return null;
    return VaultKeyMaterial.fromJson({
      'vaultId': data['vaultId'],
      'kdf': data['kdf'],
      'wrappedVek': data['wrappedVek'],
      'cryptoVersion': data['cryptoVersion'],
      'keyGeneration': data['keyGeneration'],
      'updatedAt': (data['updatedAt'] as String?) ?? DateTime.now().toUtc().toIso8601String(),
    });
  }

  @override
  Future<void> putKeyMaterial(String uid, VaultKeyMaterial material) =>
      _keys(uid).set({...material.toJson(), 'serverUpdatedAt': FieldValue.serverTimestamp()});

  // ----------------------------------------------------------------- records

  static RecordKind _kind(Object? s) => RecordKind.values.asNameMap()[s as String? ?? ''] ?? RecordKind.item;

  static RemoteRecord _record(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    final payload = m['payload'];
    return RemoteRecord(
      id: d.id,
      kind: _kind(m['kind']),
      payload: payload is Blob ? payload.bytes : null,
      revision: (m['rev'] as num?)?.toInt() ?? 0,
      deleted: m['deleted'] == true,
      keyGeneration: (m['kg'] as num?)?.toInt() ?? 1,
      serverUpdatedAt: (m['updatedAt'] as Timestamp?)?.toDate().toUtc(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate().toUtc(),
      deviceId: m['deviceId'] as String?,
    );
  }

  @override
  Future<RemoteChanges> fetchChanges(String uid, {SyncCursor? since, int limit = 300}) async {
    Query<Map<String, dynamic>> q = _records(uid).orderBy('updatedAt').orderBy(FieldPath.documentId).limit(limit);
    if (since != null) {
      q = q.startAfter([Timestamp.fromDate(since.updatedAt), since.recordId]);
    }
    final snap = await q.get(const GetOptions(source: Source.server));
    final records = <RemoteRecord>[];
    SyncCursor? cursor = since;
    for (final d in snap.docs) {
      final r = _record(d);
      records.add(r);
      if (r.serverUpdatedAt != null) cursor = SyncCursor(r.serverUpdatedAt!, r.id);
    }
    return RemoteChanges(records, cursor, hasMore: snap.docs.length == limit);
  }

  @override
  Future<RemoteRecord?> fetchRecord(String uid, String id) async {
    final d = await _records(uid).doc(id).get(const GetOptions(source: Source.server));
    return d.exists ? _record(d) : null;
  }

  @override
  Future<PushResult> push(String uid, PushRequest req) async {
    final ref = _records(uid).doc(req.id);
    return _fs.runTransaction<PushResult>((tx) async {
      final snap = await tx.get(ref);
      final remoteRev = snap.exists ? ((snap.data()!['rev'] as num?)?.toInt() ?? 0) : 0;
      if (remoteRev != req.baseRevision) {
        final remote = _record(snap);
        // Idempotency: a previous attempt may have committed but the
        // response was lost. Same ciphertext => already applied.
        if (remote.revision == req.baseRevision + 1 &&
            remote.deviceId == req.deviceId &&
            remote.deleted == req.deleted &&
            _bytesEqual(remote.payload, req.payload)) {
          return PushResult(PushOutcome.alreadyApplied, newRevision: remote.revision, remote: remote);
        }
        return PushResult(PushOutcome.conflict, remote: remote);
      }
      final next = req.baseRevision + 1;
      tx.set(ref, {
        'kind': req.kind.name,
        'v': 1,
        'payload': req.payload == null ? null : Blob(req.payload!),
        'rev': next,
        'deleted': req.deleted,
        'kg': req.keyGeneration,
        'createdAt': Timestamp.fromDate(req.createdAt),
        'updatedAt': FieldValue.serverTimestamp(),
        'deviceId': req.deviceId,
      });
      return PushResult(PushOutcome.applied, newRevision: next);
    });
  }

  static bool _bytesEqual(Uint8List? a, Uint8List? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ----------------------------------------------------------------- devices

  static DeviceRecord _device(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    DateTime ts(Object? v) => v is Timestamp ? v.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
    return DeviceRecord(
      deviceId: d.id,
      name: m['name'] as String? ?? 'Unknown device',
      platform: m['platform'] as String? ?? '',
      osVersion: m['osVersion'] as String? ?? '',
      model: m['model'] as String? ?? '',
      createdAt: ts(m['createdAt']),
      lastActiveAt: ts(m['lastActiveAt']),
      signPublicKey: m['signPublicKey'] as String? ?? '',
      kxPublicKey: m['kxPublicKey'] as String? ?? '',
      registrationSignature: m['registrationSignature'] as String? ?? '',
      revoked: m['revoked'] == true,
      revokedAt: m['revokedAt'] is Timestamp ? (m['revokedAt'] as Timestamp).toDate() : null,
    );
  }

  @override
  Future<void> upsertDevice(String uid, DeviceRecord device) async {
    final ref = _devices(uid).doc(device.deviceId);
    final existing = await ref.get();
    if (existing.exists) {
      await ref.update({
        'name': device.name,
        'osVersion': device.osVersion,
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      return;
    }
    await ref.set({
      'name': device.name,
      'platform': device.platform,
      'osVersion': device.osVersion,
      'model': device.model,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActiveAt': FieldValue.serverTimestamp(),
      'signPublicKey': device.signPublicKey,
      'kxPublicKey': device.kxPublicKey,
      'registrationSignature': device.registrationSignature,
      'revoked': false,
    });
  }

  @override
  Future<DeviceRecord?> getDevice(String uid, String deviceId) async {
    final d = await _devices(uid).doc(deviceId).get(const GetOptions(source: Source.server));
    return d.exists ? _device(d) : null;
  }

  @override
  Future<List<DeviceRecord>> listDevices(String uid) async {
    final snap = await _devices(uid).orderBy('createdAt').get(const GetOptions(source: Source.server));
    return snap.docs.map(_device).toList();
  }

  @override
  Future<void> touchDevice(String uid, String deviceId) =>
      _devices(uid).doc(deviceId).update({'lastActiveAt': FieldValue.serverTimestamp()});

  @override
  Future<void> renameDevice(String uid, String deviceId, String name) =>
      _devices(uid).doc(deviceId).update({'name': name});

  @override
  Future<void> revokeDevice(String uid, String deviceId) =>
      _devices(uid).doc(deviceId).update({'revoked': true, 'revokedAt': FieldValue.serverTimestamp()});

  // ----------------------------------------------------------------- backups

  @override
  Future<void> putBackupIndex(String uid, BackupIndexEntry e) => _backups(uid).doc(e.id).set({
    'createdAt': Timestamp.fromDate(e.createdAt),
    'encryptedSize': e.encryptedSize,
    'cipherSha256': e.cipherSha256,
    'formatVersion': e.formatVersion,
    'deviceId': e.deviceId,
  });

  @override
  Future<List<BackupIndexEntry>> listBackups(String uid) async {
    final snap = await _backups(uid).orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) {
      final m = d.data();
      return BackupIndexEntry(
        id: d.id,
        createdAt: (m['createdAt'] as Timestamp).toDate(),
        encryptedSize: (m['encryptedSize'] as num).toInt(),
        cipherSha256: m['cipherSha256'] as String,
        formatVersion: (m['formatVersion'] as num).toInt(),
        deviceId: m['deviceId'] as String? ?? '',
      );
    }).toList();
  }

  @override
  Future<void> deleteBackupIndex(String uid, String backupId) => _backups(uid).doc(backupId).delete();

  // ---------------------------------------------------------------- deletion

  @override
  Future<void> deleteAllUserData(String uid) async {
    for (final col in [_records(uid), _devices(uid), _backups(uid), _user(uid).collection('meta')]) {
      while (true) {
        final page = await col.limit(400).get();
        if (page.docs.isEmpty) break;
        final batch = _fs.batch();
        for (final d in page.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    await _user(uid).delete();
  }
}
