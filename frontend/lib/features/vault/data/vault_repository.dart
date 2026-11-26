import 'dart:async';

import 'package:drift/drift.dart';

import '../../../core/crypto/key_hierarchy.dart';
import '../../../core/db/database.dart';
import '../../../core/util/log.dart';
import '../domain/vault_models.dart';
import 'record_codec.dart';

/// Decrypted view of the whole vault, held in memory only while unlocked.
class VaultSnapshot {
  const VaultSnapshot({required this.items, required this.folders, required this.tags, this.undecryptable = const []});

  static const empty = VaultSnapshot(items: {}, folders: {}, tags: {});

  final Map<String, VaultItem> items;
  final Map<String, Folder> folders;
  final Map<String, Tag> tags;

  /// Record ids whose ciphertext failed authentication (corruption,
  /// tampering, or a key-generation mismatch awaiting re-sync).
  final List<String> undecryptable;
}

/// Local, encrypted persistence of vault records. Never talks to the network.
/// All writes mark the record dirty so the sync engine uploads it.
class VaultRepository {
  VaultRepository(this.db, this.codec);

  final AppDatabase db;
  final RecordCodec codec;

  final _changes = StreamController<void>.broadcast();

  /// Fires after every local write (used to schedule a sync).
  Stream<void> get changes => _changes.stream;

  Future<VaultSnapshot> loadAll(VaultKeys keys) async {
    final rows = await db.allRecords();
    final items = <String, VaultItem>{};
    final folders = <String, Folder>{};
    final tags = <String, Tag>{};
    final failed = <String>[];
    for (final r in rows) {
      if (r.deleted || r.payload == null) continue;
      try {
        switch (r.kind) {
          case RecordKind.item:
            items[r.id] = codec.decryptItem(keys, r.id, r.payload!);
          case RecordKind.folder:
            folders[r.id] = codec.decryptFolder(keys, r.id, r.payload!);
          case RecordKind.tag:
            tags[r.id] = codec.decryptTag(keys, r.id, r.payload!);
        }
      } catch (e) {
        // Never log the payload; the id is not sensitive.
        Log.w('vault', 'Record ${r.id} could not be decrypted (${e.runtimeType})');
        failed.add(r.id);
      }
    }
    return VaultSnapshot(items: items, folders: folders, tags: tags, undecryptable: failed);
  }

  Future<void> _write(RecordKind kind, String id, Uint8List payload, DateTime createdAt, int keyGeneration) async {
    final now = DateTime.now();
    await db.transaction(() async {
      final existing = await db.recordById(id);
      await db.upsertRecord(
        VaultRecordsCompanion(
          id: Value(id),
          kind: Value(kind),
          payload: Value(payload),
          revision: Value(existing?.revision ?? 0),
          dirty: const Value(true),
          deleted: const Value(false),
          keyGeneration: Value(keyGeneration),
          createdAt: Value(existing?.createdAt ?? createdAt),
          updatedAt: Value(now),
          serverUpdatedAt: Value(existing?.serverUpdatedAt),
          syncAttempts: const Value(0),
          lastSyncError: const Value(null),
        ),
      );
    });
    _changes.add(null);
  }

  Future<void> saveItem(VaultKeys keys, VaultItem item, {int keyGeneration = 1}) =>
      _write(RecordKind.item, item.id, codec.encryptItem(keys, item), item.createdAt, keyGeneration);

  Future<void> saveFolder(VaultKeys keys, Folder folder, {int keyGeneration = 1}) =>
      _write(RecordKind.folder, folder.id, codec.encryptFolder(keys, folder), folder.createdAt, keyGeneration);

  Future<void> saveTag(VaultKeys keys, Tag tag, {int keyGeneration = 1}) =>
      _write(RecordKind.tag, tag.id, codec.encryptTag(keys, tag), tag.createdAt, keyGeneration);

  /// Writes many records in one transaction (imports, restores, rotation).
  Future<void> saveBatch(
    VaultKeys keys, {
    Iterable<VaultItem> items = const [],
    Iterable<Folder> folders = const [],
    Iterable<Tag> tags = const [],
    int keyGeneration = 1,
  }) async {
    final now = DateTime.now();
    await db.transaction(() async {
      Future<void> put(RecordKind kind, String id, Uint8List payload, DateTime createdAt) async {
        final existing = await db.recordById(id);
        await db.upsertRecord(
          VaultRecordsCompanion(
            id: Value(id),
            kind: Value(kind),
            payload: Value(payload),
            revision: Value(existing?.revision ?? 0),
            dirty: const Value(true),
            deleted: const Value(false),
            keyGeneration: Value(keyGeneration),
            createdAt: Value(existing?.createdAt ?? createdAt),
            updatedAt: Value(now),
            serverUpdatedAt: Value(existing?.serverUpdatedAt),
          ),
        );
      }

      for (final f in folders) {
        await put(RecordKind.folder, f.id, codec.encryptFolder(keys, f), f.createdAt);
      }
      for (final t in tags) {
        await put(RecordKind.tag, t.id, codec.encryptTag(keys, t), t.createdAt);
      }
      for (final i in items) {
        await put(RecordKind.item, i.id, codec.encryptItem(keys, i), i.createdAt);
      }
    });
    _changes.add(null);
  }

  /// Permanent deletion. Never-synced records are removed outright; synced
  /// ones become tombstones (payload discarded) so other devices learn of it.
  Future<void> deletePermanently(Iterable<String> ids) async {
    await db.transaction(() async {
      for (final id in ids) {
        final existing = await db.recordById(id);
        if (existing == null) continue;
        if (existing.revision == 0) {
          await (db.delete(db.vaultRecords)..where((r) => r.id.equals(id))).go();
        } else {
          await (db.update(db.vaultRecords)..where((r) => r.id.equals(id))).write(
            VaultRecordsCompanion(
              payload: const Value(null),
              deleted: const Value(true),
              dirty: const Value(true),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
        await (db.delete(db.recentAccess)..where((r) => r.itemId.equals(id))).go();
      }
    });
    _changes.add(null);
  }

  Future<void> dispose() => _changes.close();
}
