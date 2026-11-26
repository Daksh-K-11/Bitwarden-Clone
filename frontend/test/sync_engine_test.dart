import 'dart:typed_data';

import 'package:citadel/core/cloud/cloud_interfaces.dart';
import 'package:citadel/core/crypto/crypto_service.dart';
import 'package:citadel/core/crypto/key_hierarchy.dart';
import 'package:citadel/core/db/database.dart';
import 'package:citadel/features/sync/sync_engine.dart';
import 'package:citadel/features/vault/data/record_codec.dart';
import 'package:citadel/features/vault/data/vault_repository.dart';
import 'package:citadel/features/vault/domain/item_type.dart';
import 'package:citadel/features/vault/domain/vault_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sodium/sodium_sumo.dart';

/// In-memory server with the same optimistic-concurrency contract as the
/// Firestore implementation + security rules (rev must be base+1).
class FakeRemote implements RemoteVaultStore {
  final records = <String, RemoteRecord>{};
  VaultKeyMaterial? material;
  final devices = <String, DeviceRecord>{};
  var _clock = DateTime.utc(2026);
  int pushes = 0;
  bool dropNextResponse = false;

  DateTime _tick() => _clock = _clock.add(const Duration(milliseconds: 1));

  @override
  Future<VaultKeyMaterial?> fetchKeyMaterial(String uid) async => material;
  @override
  Future<void> putKeyMaterial(String uid, VaultKeyMaterial m) async => material = m;

  @override
  Future<RemoteChanges> fetchChanges(String uid, {SyncCursor? since, int limit = 300}) async {
    final sorted = records.values.toList()
      ..sort((a, b) {
        final c = a.serverUpdatedAt!.compareTo(b.serverUpdatedAt!);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
    final after = since == null
        ? sorted
        : sorted.where((r) {
            final c = r.serverUpdatedAt!.compareTo(since.updatedAt);
            return c > 0 || (c == 0 && r.id.compareTo(since.recordId) > 0);
          }).toList();
    final page = after.take(limit).toList();
    final cursor = page.isEmpty ? since : SyncCursor(page.last.serverUpdatedAt!, page.last.id);
    return RemoteChanges(page, cursor, hasMore: page.length == limit);
  }

  @override
  Future<PushResult> push(String uid, PushRequest req) async {
    pushes++;
    final cur = records[req.id];
    final rev = cur?.revision ?? 0;
    if (rev != req.baseRevision) {
      if (cur != null &&
          cur.revision == req.baseRevision + 1 &&
          cur.deviceId == req.deviceId &&
          _eq(cur.payload, req.payload)) {
        return PushResult(PushOutcome.alreadyApplied, newRevision: cur.revision, remote: cur);
      }
      return PushResult(PushOutcome.conflict, remote: cur);
    }
    records[req.id] = RemoteRecord(
      id: req.id,
      kind: req.kind,
      payload: req.payload,
      revision: rev + 1,
      deleted: req.deleted,
      keyGeneration: req.keyGeneration,
      serverUpdatedAt: _tick(),
      createdAt: req.createdAt,
      deviceId: req.deviceId,
    );
    if (dropNextResponse) {
      dropNextResponse = false;
      throw Exception('network: response lost');
    }
    return PushResult(PushOutcome.applied, newRevision: rev + 1);
  }

  static bool _eq(Uint8List? a, Uint8List? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Future<RemoteRecord?> fetchRecord(String uid, String id) async => records[id];
  @override
  Future<void> upsertDevice(String uid, DeviceRecord device) async => devices[device.deviceId] = device;
  @override
  Future<DeviceRecord?> getDevice(String uid, String deviceId) async => devices[deviceId];
  @override
  Future<List<DeviceRecord>> listDevices(String uid) async => devices.values.toList();
  @override
  Future<void> touchDevice(String uid, String deviceId) async {}
  @override
  Future<void> renameDevice(String uid, String deviceId, String name) async {}
  @override
  Future<void> revokeDevice(String uid, String deviceId) async {
    final d = devices[deviceId]!;
    devices[deviceId] = DeviceRecord(
      deviceId: d.deviceId,
      name: d.name,
      platform: d.platform,
      osVersion: d.osVersion,
      model: d.model,
      createdAt: d.createdAt,
      lastActiveAt: d.lastActiveAt,
      signPublicKey: d.signPublicKey,
      kxPublicKey: d.kxPublicKey,
      registrationSignature: d.registrationSignature,
      revoked: true,
    );
  }

  @override
  Future<void> putBackupIndex(String uid, BackupIndexEntry entry) async {}
  @override
  Future<List<BackupIndexEntry>> listBackups(String uid) async => [];
  @override
  Future<void> deleteBackupIndex(String uid, String backupId) async {}
  @override
  Future<void> deleteAllUserData(String uid) async => records.clear();
}

class Device {
  Device(this.name, this.crypto, this.remote, this.keys, this.material)
    : db = AppDatabase.memory(),
      codec = RecordCodec(crypto) {
    repo = VaultRepository(db, codec);
    engine = SyncEngine(
      db: db,
      remote: remote,
      codec: codec,
      deviceId: name,
      onRemoteMaterial: (m) async => material = m,
    );
  }
  final String name;
  final CryptoService crypto;
  final FakeRemote remote;
  final VaultKeys keys;
  VaultKeyMaterial material;
  final AppDatabase db;
  final RecordCodec codec;
  late final VaultRepository repo;
  late final SyncEngine engine;

  Future<SyncReport> sync() => engine.run(uid: 'u', keys: keys, localMaterial: material);
  Future<VaultSnapshot> load() => repo.loadAll(keys);

  Future<void> edit(String id, String name) async {
    final snap = await load();
    final cur = snap.items[id]!;
    await repo.saveItem(keys, cur.copyWith(name: name, seq: cur.seq + 1, updatedAt: DateTime.now().toUtc()));
  }
}

VaultItem item(String id, String name) =>
    VaultItem(id: id, type: ItemType.login, name: name, createdAt: DateTime.utc(2026), updatedAt: DateTime.utc(2026));

void main() {
  late CryptoService crypto;
  late FakeRemote remote;
  late Device a;
  late Device b;

  setUpAll(() async => crypto = CryptoService(await SodiumSumoInit.init()));

  setUp(() async {
    remote = FakeRemote();
    final (material, keys) = await KeyHierarchy(
      crypto,
    ).createVault(vaultId: 'vault', masterPassword: 'sync test password');
    remote.material = material;
    a = Device('A', crypto, remote, keys, material);
    b = Device('B', crypto, remote, keys, material);
  });

  test('changes propagate between devices and the server only stores ciphertext', () async {
    await a.repo.saveItem(a.keys, item('1', 'Bank'));
    await a.sync();
    expect(remote.records['1']!.revision, 1);
    expect(String.fromCharCodes(remote.records['1']!.payload!).contains('Bank'), isFalse);
    await b.sync();
    expect((await b.load()).items['1']!.name, 'Bank');
    expect(await b.db.dirtyCount(), 0);
  });

  test('offline edits coalesce and survive failed syncs', () async {
    await a.repo.saveItem(a.keys, item('1', 'v1'));
    await a.edit('1', 'v2');
    await a.edit('1', 'v3');
    expect(await a.db.dirtyCount(), 1);
    remote.dropNextResponse = true; // commit happens, response is lost
    await expectLater(a.sync(), throwsException);
    expect(await a.db.dirtyCount(), 1, reason: 'change still queued');
    await a.sync(); // retry recognises its own write (idempotent)
    expect(remote.records['1']!.revision, 1);
    expect(await a.db.dirtyCount(), 0);
  });

  test('concurrent edits keep both versions (no silent last-write-wins)', () async {
    await a.repo.saveItem(a.keys, item('1', 'original'));
    await a.sync();
    await b.sync();
    await a.edit('1', 'edited on A');
    await b.edit('1', 'edited on B');
    await a.sync(); // A wins the race -> rev 2
    final report = await b.sync(); // B detects conflict
    expect(report.conflicts, 1);
    expect((await b.load()).items['1']!.name, 'edited on A');
    final conflicts = await b.db.select(b.db.syncConflicts).get();
    final kept = b.codec.decryptItem(b.keys, '1', b.codec.decryptConflict(b.keys, '1', conflicts.single.localPayload));
    expect(kept.name, 'edited on B');
  });

  test('tombstones propagate deletions', () async {
    await a.repo.saveItem(a.keys, item('1', 'to delete'));
    await a.sync();
    await b.sync();
    await a.repo.deletePermanently(['1']);
    await a.sync();
    expect(remote.records['1']!.deleted, isTrue);
    expect(remote.records['1']!.payload, isNull);
    await b.sync();
    expect((await b.load()).items.containsKey('1'), isFalse);
  });

  test('edit beats a concurrent remote delete (data preserving)', () async {
    await a.repo.saveItem(a.keys, item('1', 'keep me'));
    await a.sync();
    await b.sync();
    await a.repo.deletePermanently(['1']);
    await a.sync();
    await b.edit('1', 'edited after delete');
    await b.sync();
    expect(remote.records['1']!.deleted, isFalse);
    await a.sync();
    expect((await a.load()).items['1']!.name, 'edited after delete');
  });

  test('server replaying an older ciphertext is rejected', () async {
    await a.repo.saveItem(a.keys, item('1', 'v1'));
    await a.sync();
    final old = remote.records['1']!;
    await a.edit('1', 'v2');
    await a.sync();
    await b.sync();
    // Malicious server: serve v1's ciphertext under a newer revision.
    remote.records['1'] = RemoteRecord(
      id: '1',
      kind: RecordKind.item,
      payload: old.payload,
      revision: 9,
      deleted: false,
      keyGeneration: 1,
      serverUpdatedAt: DateTime.utc(2030),
      deviceId: 'evil',
    );
    final report = await b.sync();
    expect(report.rollbacksRejected, 1);
    expect((await b.load()).items['1']!.name, 'v2');
  });

  test('tampered or misplaced ciphertext is not accepted', () async {
    await a.repo.saveItem(a.keys, item('1', 'genuine'));
    await a.sync();
    final r = remote.records['1']!;
    remote.records['2'] = RemoteRecord(
      id: '2', // ciphertext of item 1 moved under id 2
      kind: RecordKind.item,
      payload: r.payload,
      revision: 1,
      deleted: false,
      keyGeneration: 1,
      serverUpdatedAt: DateTime.utc(2031),
    );
    final report = await b.sync();
    expect(report.failedRecords, 1);
    expect((await b.load()).items.containsKey('2'), isFalse);
  });

  test('revoked device is refused', () async {
    remote.devices['B'] = DeviceRecord(
      deviceId: 'B',
      name: 'B',
      platform: 'android',
      osVersion: '',
      model: '',
      createdAt: DateTime.utc(2026),
      lastActiveAt: DateTime.utc(2026),
      signPublicKey: '',
      kxPublicKey: '',
      registrationSignature: '',
    );
    await remote.revokeDevice('u', 'B');
    await expectLater(b.sync(), throwsA(isA<DeviceRevokedException>()));
  });

  test('key rotation on another device forces re-unlock', () async {
    final (rotated, _) = await KeyHierarchy(
      crypto,
    ).rotateVaultKey(current: a.material, masterPassword: 'sync test password');
    remote.material = rotated;
    await expectLater(b.sync(), throwsA(isA<VaultKeyRotatedException>()));
  });

  test('incremental pulls only fetch what changed', () async {
    for (var i = 0; i < 5; i++) {
      await a.repo.saveItem(a.keys, item('$i', 'item $i'));
    }
    await a.sync();
    final first = await b.sync();
    expect(first.pulled, 5);
    final second = await b.sync();
    expect(second.pulled, 0);
  });
}
