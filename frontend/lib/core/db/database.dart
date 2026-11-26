import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'database.g.dart';

/// Kinds of synchronised records. Stored as int; never reorder.
enum RecordKind { item, folder, tag }

/// Encrypted vault records (items, folders, tags).
///
/// Only the columns needed for storage and sync live in plaintext (and even
/// these are protected at rest by SQLCipher). Item type, name, folder,
/// favourite, tags and trash state all live *inside* the encrypted payload.
class VaultRecords extends Table {
  TextColumn get id => text()();
  IntColumn get kind => intEnum<RecordKind>()();

  /// [EncBlob] bytes; null for tombstones (permanently deleted records).
  BlobColumn get payload => blob().nullable()();

  /// Server revision this local payload is based on (0 = never uploaded).
  IntColumn get revision => integer().withDefault(const Constant(0))();

  /// Local modifications not yet uploaded. Dirty rows ARE the encrypted
  /// pending-operation queue: repeated offline edits coalesce into one upload
  /// and nothing is lost if a sync attempt fails.
  BoolColumn get dirty => boolean().withDefault(const Constant(false))();

  /// Tombstone: permanently deleted; kept so the deletion syncs.
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// VEK generation used to encrypt [payload].
  IntColumn get keyGeneration => integer().withDefault(const Constant(1))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get serverUpdatedAt => dateTime().nullable()();
  IntColumn get syncAttempts => integer().withDefault(const Constant(0))();
  TextColumn get lastSyncError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local copy of a record that lost a sync conflict, encrypted with the
/// conflict key so the user can choose which version to keep.
class SyncConflicts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get recordId => text()();
  IntColumn get kind => intEnum<RecordKind>()();
  BlobColumn get localPayload => blob()();
  IntColumn get remoteRevision => integer()();
  DateTimeColumn get detectedAt => dateTime()();
}

enum AttachmentSyncState { localOnly, pendingUpload, uploaded, pendingDelete }

/// Local bookkeeping for encrypted attachment blobs. File names, MIME types
/// and file keys live in the (encrypted) item payload, not here.
class LocalAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();

  /// Path of the *encrypted* blob inside the app sandbox, if present.
  TextColumn get localPath => text().nullable()();
  IntColumn get encryptedSize => integer()();

  /// SHA-256 of the encrypted blob - verified after download and before
  /// decryption (decryption itself also authenticates every chunk).
  TextColumn get cipherSha256 => text()();
  IntColumn get syncState => intEnum<AttachmentSyncState>()();
  IntColumn get uploadAttempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Recently used items: ids and timestamps only, no content.
class RecentAccess extends Table {
  TextColumn get itemId => text()();
  DateTimeColumn get accessedAt => dateTime()();
  IntColumn get accessCount => integer().withDefault(const Constant(1))();

  @override
  Set<Column> get primaryKey => {itemId};
}

/// Non-secret settings and sync bookkeeping.
class KeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [VaultRecords, SyncConflicts, LocalAttachments, RecentAccess, KeyValues])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens (or creates) the SQLCipher database with a raw 256-bit key.
  ///
  /// Using the `x'..'` raw-key form skips SQLCipher's internal PBKDF2 (the key
  /// is already uniformly random). SQLCipher encrypts the main file, the WAL
  /// and rollback journals page by page; temp tables are memory-only
  /// (SQLITE_TEMP_STORE=2 build option + `temp_store=MEMORY`).
  factory AppDatabase.open(File file, String hexKey) {
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(hexKey)) {
      throw ArgumentError('Database key must be 32 bytes hex');
    }
    final executor = NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute("PRAGMA key = \"x'$hexKey'\";");
        final version = db.select('PRAGMA cipher_version;');
        if (version.isEmpty) {
          // Refuse to run on a non-encrypting SQLite build.
          throw StateError('SQLCipher is not available');
        }
        db.execute('PRAGMA cipher_memory_security = ON;');
        db.execute('PRAGMA secure_delete = ON;');
        db.execute('PRAGMA temp_store = MEMORY;');
        db.execute('PRAGMA journal_mode = WAL;');
        db.execute('PRAGMA synchronous = FULL;');
        db.execute('PRAGMA foreign_keys = ON;');
        // Fails fast with "file is not a database" on a wrong key.
        db.select('SELECT count(*) FROM sqlite_master;');
      },
    );
    return AppDatabase(executor);
  }

  /// In-memory database for tests.
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('CREATE INDEX idx_records_kind ON vault_records (kind);');
      await customStatement('CREATE INDEX idx_records_dirty ON vault_records (dirty) WHERE dirty = 1;');
      await customStatement('CREATE INDEX idx_attachments_item ON local_attachments (item_id);');
    },
    onUpgrade: (m, from, to) async {
      // Future migrations go here, one `if (from < N)` block per version, each
      // inside the transaction drift opens for the upgrade. A pre-migration
      // encrypted backup is taken by the app before opening a newer schema.
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );

  // --------------------------------------------------------------- records

  Future<List<VaultRecord>> allRecords() => select(vaultRecords).get();

  Future<VaultRecord?> recordById(String id) => (select(vaultRecords)..where((r) => r.id.equals(id))).getSingleOrNull();

  Future<List<VaultRecord>> dirtyRecords() => (select(vaultRecords)..where((r) => r.dirty.equals(true))).get();

  Future<int> dirtyCount() async {
    final count = vaultRecords.id.count();
    final q = selectOnly(vaultRecords)
      ..addColumns([count])
      ..where(vaultRecords.dirty.equals(true));
    return (await q.getSingle()).read(count) ?? 0;
  }

  Future<void> upsertRecord(VaultRecordsCompanion row) => into(vaultRecords).insertOnConflictUpdate(row);

  // ------------------------------------------------------------ key/values

  Future<String?> getValue(String key) async =>
      (await (select(keyValues)..where((k) => k.key.equals(key))).getSingleOrNull())?.value;

  Future<void> setValue(String key, String value) =>
      into(keyValues).insertOnConflictUpdate(KeyValue(key: key, value: value));

  Future<void> deleteValue(String key) => (delete(keyValues)..where((k) => k.key.equals(key))).go();

  // ----------------------------------------------------------- recents

  Future<void> touchRecent(String itemId) => customStatement(
    'INSERT INTO recent_access (item_id, accessed_at, access_count) VALUES (?, ?, 1) '
    'ON CONFLICT(item_id) DO UPDATE SET accessed_at = excluded.accessed_at, '
    'access_count = access_count + 1',
    [itemId, DateTime.now().millisecondsSinceEpoch ~/ 1000],
  );

  Future<List<RecentAccessData>> recents({int limit = 20}) =>
      (select(recentAccess)
            ..orderBy([(r) => OrderingTerm.desc(r.accessedAt)])
            ..limit(limit))
          .get();

  // --------------------------------------------------------- integrity

  /// Runs SQLite's structural check plus SQLCipher's per-page HMAC check.
  /// Returns an empty list when healthy.
  Future<List<String>> integrityCheck() async {
    final problems = <String>[];
    final rows = await customSelect('PRAGMA integrity_check;').get();
    for (final r in rows) {
      final v = r.data.values.first?.toString() ?? '';
      if (v != 'ok') problems.add(v);
    }
    final cipherRows = await customSelect('PRAGMA cipher_integrity_check;').get();
    for (final r in cipherRows) {
      problems.add(r.data.values.first?.toString() ?? 'cipher page error');
    }
    return problems;
  }

  /// Wipes all rows (secure logout). `secure_delete` overwrites freed pages.
  Future<void> wipe() => transaction(() async {
    for (final t in allTables) {
      await delete(t).go();
    }
  });
}
