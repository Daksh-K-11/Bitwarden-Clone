import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:drift/drift.dart';

import '../../core/cloud/cloud_interfaces.dart';
import '../../core/crypto/key_hierarchy.dart';
import '../../core/db/database.dart';
import '../../core/util/log.dart';
import '../vault/data/record_codec.dart';
import '../vault/domain/vault_models.dart';

class DeviceRevokedException implements Exception {
  const DeviceRevokedException();
  @override
  String toString() => 'This device has been signed out from another device.';
}

class VaultKeyRotatedException implements Exception {
  const VaultKeyRotatedException(this.material);
  final VaultKeyMaterial material;
  @override
  String toString() => 'The vault key was rotated on another device. Unlock with your master password.';
}

class SyncReport {
  SyncReport();
  int pulled = 0;
  int pushed = 0;
  int conflicts = 0;
  int failedRecords = 0;
  int rollbacksRejected = 0;
  bool remoteMaterialUpdated = false;
}

abstract final class SyncKeys {
  static const cursor = 'sync.cursor';
  static const lastSyncAt = 'sync.lastSyncAt';
  static const lastDeviceTouch = 'sync.lastDeviceTouch';
}

/// Bidirectional, conflict-aware synchronisation of *encrypted* records.
///
/// Protocol
/// --------
/// * Every record has a server revision `rev`. A device uploads a change as
///   "base rev N -> N+1" inside a Firestore transaction; the write only lands
///   if the server is still at N (optimistic concurrency, also enforced by the
///   security rules). This replaces Firestore's default last-write-wins.
/// * Pull is incremental: documents ordered by (server updatedAt, id) after
///   the last cursor, in pages - read cost is proportional to what changed.
/// * Deletions propagate as tombstones (payload removed, `deleted: true`).
/// * Retries are idempotent: if a commit succeeded but its response was lost,
///   the retry recognises its own ciphertext at N+1.
/// * Conflicts (both sides changed the same item since N): the remote version
///   wins in place and the local version is preserved, encrypted, in
///   `sync_conflicts` for the user to resolve. Nothing is silently dropped.
/// * Replay/rollback: each item payload carries an encrypted monotonic `seq`.
///   A remote "update" whose `seq` is lower than the local copy is rejected.
class SyncEngine {
  SyncEngine({
    required this.db,
    required this.remote,
    required this.codec,
    required this.deviceId,
    required this.onRemoteMaterial,
    this.onMissingDevice,
  });

  final AppDatabase db;
  final RemoteVaultStore remote;
  final RecordCodec codec;
  final String deviceId;

  /// Called when another device changed the master password (same VEK).
  final Future<void> Function(VaultKeyMaterial material) onRemoteMaterial;

  /// Registers this device when its record is missing. The security rules
  /// only accept record writes from registered, non-revoked devices.
  final Future<void> Function()? onMissingDevice;

  static const _pageSize = 300;

  Future<SyncReport> run({
    required String uid,
    required VaultKeys keys,
    required VaultKeyMaterial localMaterial,
  }) async {
    final report = SyncReport();

    // 1. Is this device still authorised?
    var me = await remote.getDevice(uid, deviceId);
    if (me != null && me.revoked) throw const DeviceRevokedException();
    if (me == null && onMissingDevice != null) {
      await onMissingDevice!();
      me = await remote.getDevice(uid, deviceId);
    }

    // 2. Key material changes made on other devices.
    final remoteMaterial = await remote.fetchKeyMaterial(uid);
    if (remoteMaterial != null) {
      if (remoteMaterial.vaultId != localMaterial.vaultId) {
        throw StateError('Remote vault does not match this device');
      }
      if (remoteMaterial.keyGeneration > localMaterial.keyGeneration) {
        throw VaultKeyRotatedException(remoteMaterial);
      }
      if (remoteMaterial.keyGeneration == localMaterial.keyGeneration &&
          remoteMaterial.wrappedVek.toBase64() != localMaterial.wrappedVek.toBase64() &&
          remoteMaterial.updatedAt.isAfter(localMaterial.updatedAt)) {
        await onRemoteMaterial(remoteMaterial);
        report.remoteMaterialUpdated = true;
      }
    } else {
      await remote.putKeyMaterial(uid, localMaterial);
    }

    // 3. Pull.
    var cursor = SyncCursor.decode(await db.getValue(SyncKeys.cursor));
    while (true) {
      final page = await remote.fetchChanges(uid, since: cursor, limit: _pageSize);
      for (final r in page.records) {
        try {
          await _applyRemote(r, keys, report);
        } catch (e) {
          report.failedRecords++;
          Log.w('sync', 'Could not apply remote ${r.id} (${e.runtimeType})');
        }
      }
      cursor = page.nextCursor ?? cursor;
      if (cursor != null) await db.setValue(SyncKeys.cursor, cursor.encode());
      if (!page.hasMore) break;
    }

    // 4. Push.
    for (final rec in await db.dirtyRecords()) {
      await _pushOne(uid, rec, keys, report, allowRetry: true);
    }

    // 5. Bookkeeping (device "last active" at most hourly to save writes).
    final now = DateTime.now().toUtc();
    await db.setValue(SyncKeys.lastSyncAt, now.toIso8601String());
    final lastTouch = DateTime.tryParse(await db.getValue(SyncKeys.lastDeviceTouch) ?? '');
    if (me != null && (lastTouch == null || now.difference(lastTouch) > const Duration(hours: 1))) {
      await remote.touchDevice(uid, deviceId);
      await db.setValue(SyncKeys.lastDeviceTouch, now.toIso8601String());
    }
    return report;
  }

  // ------------------------------------------------------------------ push

  Future<void> _pushOne(
    String uid,
    VaultRecord rec,
    VaultKeys keys,
    SyncReport report, {
    required bool allowRetry,
  }) async {
    final req = PushRequest(
      id: rec.id,
      kind: rec.kind,
      payload: rec.deleted ? null : rec.payload,
      baseRevision: rec.revision,
      deleted: rec.deleted,
      keyGeneration: rec.keyGeneration,
      createdAt: rec.createdAt.toUtc(),
      deviceId: deviceId,
    );
    PushResult res;
    try {
      res = await remote.push(uid, req);
    } catch (e) {
      await (db.update(db.vaultRecords)..where((r) => r.id.equals(rec.id))).write(
        VaultRecordsCompanion(
          syncAttempts: Value(rec.syncAttempts + 1),
          lastSyncError: Value(e.runtimeType.toString()),
        ),
      );
      rethrow; // network failure: abort this run, dirty rows stay queued
    }

    switch (res.outcome) {
      case PushOutcome.applied:
      case PushOutcome.alreadyApplied:
        report.pushed++;
        await db.transaction(() async {
          final current = await db.recordById(rec.id);
          if (current == null) return;
          final editedMeanwhile = !current.updatedAt.isAtSameMomentAs(rec.updatedAt);
          if (rec.deleted && !editedMeanwhile) {
            await (db.delete(db.vaultRecords)..where((r) => r.id.equals(rec.id))).go();
            return;
          }
          await (db.update(db.vaultRecords)..where((r) => r.id.equals(rec.id))).write(
            VaultRecordsCompanion(
              revision: Value(res.newRevision!),
              dirty: Value(editedMeanwhile),
              syncAttempts: const Value(0),
              lastSyncError: const Value(null),
              serverUpdatedAt: Value(DateTime.now().toUtc()),
            ),
          );
        });
      case PushOutcome.conflict:
        await _resolveConflict(rec, res.remote!, keys, report);
        final after = await db.recordById(rec.id);
        if (allowRetry && after != null && after.dirty) {
          await _pushOne(uid, after, keys, report, allowRetry: false);
        }
    }
  }

  // ------------------------------------------------------------------ pull

  Future<void> _overwriteWithRemote(RemoteRecord r) => db.upsertRecord(
    VaultRecordsCompanion(
      id: Value(r.id),
      kind: Value(r.kind),
      payload: Value(r.payload),
      revision: Value(r.revision),
      dirty: const Value(false),
      deleted: Value(r.deleted),
      keyGeneration: Value(r.keyGeneration),
      createdAt: Value(r.createdAt ?? DateTime.now().toUtc()),
      updatedAt: Value(DateTime.now()),
      serverUpdatedAt: Value(r.serverUpdatedAt),
      syncAttempts: const Value(0),
      lastSyncError: const Value(null),
    ),
  );

  Future<void> _applyRemote(RemoteRecord r, VaultKeys keys, SyncReport report) async {
    final local = await db.recordById(r.id);
    if (local == null) {
      if (r.deleted || r.payload == null) return; // tombstone for something we never had
      // Authenticate before accepting: rejects tampered/misplaced ciphertext.
      _decryptAny(keys, r.kind, r.id, r.payload!);
      await _overwriteWithRemote(r);
      report.pulled++;
      return;
    }
    if (r.revision <= local.revision) return; // our own write echoing back, or stale

    if (!local.dirty) {
      if (r.deleted) {
        await (db.delete(db.vaultRecords)..where((x) => x.id.equals(r.id))).go();
        report.pulled++;
        return;
      }
      if (r.kind == RecordKind.item && local.payload != null && r.payload != null) {
        final mine = codec.decryptItem(keys, local.id, local.payload!);
        final theirs = codec.decryptItem(keys, r.id, r.payload!); // throws if tampered
        if (theirs.seq < mine.seq) {
          // Possible rollback/replay of an old ciphertext. Keep ours and
          // re-assert it on top of the server revision.
          report.rollbacksRejected++;
          Log.w('sync', 'Rejected older remote version of ${r.id}');
          await (db.update(db.vaultRecords)..where((x) => x.id.equals(r.id))).write(
            VaultRecordsCompanion(revision: Value(r.revision), dirty: const Value(true)),
          );
          return;
        }
      } else if (r.payload != null) {
        _decryptAny(keys, r.kind, r.id, r.payload!);
      }
      await _overwriteWithRemote(r);
      report.pulled++;
      return;
    }

    await _resolveConflict(local, r, keys, report);
  }

  /// [local] is dirty and [remote] advanced past local.revision.
  Future<void> _resolveConflict(VaultRecord local, RemoteRecord remote, VaultKeys keys, SyncReport report) async {
    Future<void> keepLocalOnTop() => (db.update(db.vaultRecords)..where((x) => x.id.equals(local.id))).write(
      VaultRecordsCompanion(revision: Value(remote.revision), dirty: const Value(true)),
    );

    if (remote.deleted) {
      if (local.deleted) {
        await (db.delete(db.vaultRecords)..where((x) => x.id.equals(local.id))).go();
      } else {
        // Edited here, deleted elsewhere: keep the edit (data-preserving).
        await keepLocalOnTop();
      }
      return;
    }
    if (local.deleted || local.payload == null) {
      // Deleted here, edited elsewhere: restore the edited version.
      await _overwriteWithRemote(remote);
      report.conflicts++;
      return;
    }

    switch (local.kind) {
      case RecordKind.item:
        final mine = codec.decryptItem(keys, local.id, local.payload!);
        final theirs = codec.decryptItem(keys, remote.id, remote.payload!);
        if (_sameContent(mine.toJson(), theirs.toJson())) {
          await _overwriteWithRemote(remote);
          return;
        }
        await db
            .into(db.syncConflicts)
            .insert(
              SyncConflictsCompanion.insert(
                recordId: local.id,
                kind: local.kind,
                localPayload: codec.encryptConflict(keys, local.id, local.payload!),
                remoteRevision: remote.revision,
                detectedAt: DateTime.now(),
              ),
            );
        await _overwriteWithRemote(remote);
        report.conflicts++;
      case RecordKind.folder:
      case RecordKind.tag:
        // Low-stakes metadata: last writer (by encrypted updatedAt) wins.
        final mine = codec.decrypt(keys, local.kind, local.id, local.payload!);
        final theirs = codec.decrypt(keys, remote.kind, remote.id, remote.payload!);
        final mineAt = DateTime.parse(mine['updatedAt'] as String);
        final theirsAt = DateTime.parse(theirs['updatedAt'] as String);
        if (mineAt.isAfter(theirsAt)) {
          await keepLocalOnTop();
        } else {
          await _overwriteWithRemote(remote);
        }
    }
  }

  Object _decryptAny(VaultKeys keys, RecordKind kind, String id, Uint8List payload) =>
      codec.decrypt(keys, kind, id, payload);

  static bool _sameContent(Map<String, dynamic> a, Map<String, dynamic> b) {
    Map<String, dynamic> strip(Map<String, dynamic> m) => jsonDecode(jsonEncode(m)) as Map<String, dynamic>
      ..remove('updatedAt')
      ..remove('seq');
    return const DeepCollectionEquality().equals(strip(a), strip(b));
  }

  /// Applies a user's conflict decision.
  static Future<void> resolve({
    required AppDatabase db,
    required RecordCodec codec,
    required VaultKeys keys,
    required SyncConflict conflict,
    required ConflictChoice choice,
    required Future<void> Function(VaultItem) saveItem,
    required String Function() newId,
  }) async {
    final payload = codec.decryptConflict(keys, conflict.recordId, conflict.localPayload);
    final mine = codec.decryptItem(keys, conflict.recordId, payload);
    final current = await db.recordById(conflict.recordId);
    final currentSeq = current?.payload == null ? 0 : codec.decryptItem(keys, conflict.recordId, current!.payload!).seq;
    switch (choice) {
      case ConflictChoice.keepMine:
        await saveItem(mine.copyWith(seq: currentSeq + 1, updatedAt: DateTime.now().toUtc()));
      case ConflictChoice.keepTheirs:
        break;
      case ConflictChoice.keepBoth:
        final now = DateTime.now().toUtc();
        await saveItem(
          mine.copyWith(id: newId(), name: '${mine.name} (conflict copy)', createdAt: now, updatedAt: now, seq: 1),
        );
    }
    await (db.delete(db.syncConflicts)..where((c) => c.id.equals(conflict.id))).go();
  }
}

enum ConflictChoice { keepMine, keepTheirs, keepBoth }
