// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $VaultRecordsTable extends VaultRecords with TableInfo<$VaultRecordsTable, VaultRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VaultRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RecordKind, int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  ).withConverter<RecordKind>($VaultRecordsTable.$converterkind);
  static const VerificationMeta _payloadMeta = const VerificationMeta('payload');
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta('revision');
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("dirty" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _keyGenerationMeta = const VerificationMeta('keyGeneration');
  @override
  late final GeneratedColumn<int> keyGeneration = GeneratedColumn<int>(
    'key_generation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta('serverUpdatedAt');
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt = GeneratedColumn<DateTime>(
    'server_updated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncAttemptsMeta = const VerificationMeta('syncAttempts');
  @override
  late final GeneratedColumn<int> syncAttempts = GeneratedColumn<int>(
    'sync_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSyncErrorMeta = const VerificationMeta('lastSyncError');
  @override
  late final GeneratedColumn<String> lastSyncError = GeneratedColumn<String>(
    'last_sync_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    payload,
    revision,
    dirty,
    deleted,
    keyGeneration,
    createdAt,
    updatedAt,
    serverUpdatedAt,
    syncAttempts,
    lastSyncError,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'vault_records';
  @override
  VerificationContext validateIntegrity(Insertable<VaultRecord> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta, payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    }
    if (data.containsKey('revision')) {
      context.handle(_revisionMeta, revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta));
    }
    if (data.containsKey('dirty')) {
      context.handle(_dirtyMeta, dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta, deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('key_generation')) {
      context.handle(
        _keyGenerationMeta,
        keyGeneration.isAcceptableOrUnknown(data['key_generation']!, _keyGenerationMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta, updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(data['server_updated_at']!, _serverUpdatedAtMeta),
      );
    }
    if (data.containsKey('sync_attempts')) {
      context.handle(_syncAttemptsMeta, syncAttempts.isAcceptableOrUnknown(data['sync_attempts']!, _syncAttemptsMeta));
    }
    if (data.containsKey('last_sync_error')) {
      context.handle(
        _lastSyncErrorMeta,
        lastSyncError.isAcceptableOrUnknown(data['last_sync_error']!, _lastSyncErrorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VaultRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VaultRecord(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      kind: $VaultRecordsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}kind'])!,
      ),
      payload: attachedDatabase.typeMapping.read(DriftSqlType.blob, data['${effectivePrefix}payload']),
      revision: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}revision'])!,
      dirty: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}dirty'])!,
      deleted: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      keyGeneration: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}key_generation'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      ),
      syncAttempts: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sync_attempts'])!,
      lastSyncError: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}last_sync_error']),
    );
  }

  @override
  $VaultRecordsTable createAlias(String alias) {
    return $VaultRecordsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RecordKind, int, int> $converterkind = const EnumIndexConverter<RecordKind>(
    RecordKind.values,
  );
}

class VaultRecord extends DataClass implements Insertable<VaultRecord> {
  final String id;
  final RecordKind kind;

  /// [EncBlob] bytes; null for tombstones (permanently deleted records).
  final Uint8List? payload;

  /// Server revision this local payload is based on (0 = never uploaded).
  final int revision;

  /// Local modifications not yet uploaded. Dirty rows ARE the encrypted
  /// pending-operation queue: repeated offline edits coalesce into one upload
  /// and nothing is lost if a sync attempt fails.
  final bool dirty;

  /// Tombstone: permanently deleted; kept so the deletion syncs.
  final bool deleted;

  /// VEK generation used to encrypt [payload].
  final int keyGeneration;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? serverUpdatedAt;
  final int syncAttempts;
  final String? lastSyncError;
  const VaultRecord({
    required this.id,
    required this.kind,
    this.payload,
    required this.revision,
    required this.dirty,
    required this.deleted,
    required this.keyGeneration,
    required this.createdAt,
    required this.updatedAt,
    this.serverUpdatedAt,
    required this.syncAttempts,
    this.lastSyncError,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['kind'] = Variable<int>($VaultRecordsTable.$converterkind.toSql(kind));
    }
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<Uint8List>(payload);
    }
    map['revision'] = Variable<int>(revision);
    map['dirty'] = Variable<bool>(dirty);
    map['deleted'] = Variable<bool>(deleted);
    map['key_generation'] = Variable<int>(keyGeneration);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || serverUpdatedAt != null) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    }
    map['sync_attempts'] = Variable<int>(syncAttempts);
    if (!nullToAbsent || lastSyncError != null) {
      map['last_sync_error'] = Variable<String>(lastSyncError);
    }
    return map;
  }

  VaultRecordsCompanion toCompanion(bool nullToAbsent) {
    return VaultRecordsCompanion(
      id: Value(id),
      kind: Value(kind),
      payload: payload == null && nullToAbsent ? const Value.absent() : Value(payload),
      revision: Value(revision),
      dirty: Value(dirty),
      deleted: Value(deleted),
      keyGeneration: Value(keyGeneration),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      serverUpdatedAt: serverUpdatedAt == null && nullToAbsent ? const Value.absent() : Value(serverUpdatedAt),
      syncAttempts: Value(syncAttempts),
      lastSyncError: lastSyncError == null && nullToAbsent ? const Value.absent() : Value(lastSyncError),
    );
  }

  factory VaultRecord.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VaultRecord(
      id: serializer.fromJson<String>(json['id']),
      kind: $VaultRecordsTable.$converterkind.fromJson(serializer.fromJson<int>(json['kind'])),
      payload: serializer.fromJson<Uint8List?>(json['payload']),
      revision: serializer.fromJson<int>(json['revision']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      keyGeneration: serializer.fromJson<int>(json['keyGeneration']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      serverUpdatedAt: serializer.fromJson<DateTime?>(json['serverUpdatedAt']),
      syncAttempts: serializer.fromJson<int>(json['syncAttempts']),
      lastSyncError: serializer.fromJson<String?>(json['lastSyncError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<int>($VaultRecordsTable.$converterkind.toJson(kind)),
      'payload': serializer.toJson<Uint8List?>(payload),
      'revision': serializer.toJson<int>(revision),
      'dirty': serializer.toJson<bool>(dirty),
      'deleted': serializer.toJson<bool>(deleted),
      'keyGeneration': serializer.toJson<int>(keyGeneration),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'serverUpdatedAt': serializer.toJson<DateTime?>(serverUpdatedAt),
      'syncAttempts': serializer.toJson<int>(syncAttempts),
      'lastSyncError': serializer.toJson<String?>(lastSyncError),
    };
  }

  VaultRecord copyWith({
    String? id,
    RecordKind? kind,
    Value<Uint8List?> payload = const Value.absent(),
    int? revision,
    bool? dirty,
    bool? deleted,
    int? keyGeneration,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> serverUpdatedAt = const Value.absent(),
    int? syncAttempts,
    Value<String?> lastSyncError = const Value.absent(),
  }) => VaultRecord(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    payload: payload.present ? payload.value : this.payload,
    revision: revision ?? this.revision,
    dirty: dirty ?? this.dirty,
    deleted: deleted ?? this.deleted,
    keyGeneration: keyGeneration ?? this.keyGeneration,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    serverUpdatedAt: serverUpdatedAt.present ? serverUpdatedAt.value : this.serverUpdatedAt,
    syncAttempts: syncAttempts ?? this.syncAttempts,
    lastSyncError: lastSyncError.present ? lastSyncError.value : this.lastSyncError,
  );
  VaultRecord copyWithCompanion(VaultRecordsCompanion data) {
    return VaultRecord(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      payload: data.payload.present ? data.payload.value : this.payload,
      revision: data.revision.present ? data.revision.value : this.revision,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      keyGeneration: data.keyGeneration.present ? data.keyGeneration.value : this.keyGeneration,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      serverUpdatedAt: data.serverUpdatedAt.present ? data.serverUpdatedAt.value : this.serverUpdatedAt,
      syncAttempts: data.syncAttempts.present ? data.syncAttempts.value : this.syncAttempts,
      lastSyncError: data.lastSyncError.present ? data.lastSyncError.value : this.lastSyncError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VaultRecord(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('revision: $revision, ')
          ..write('dirty: $dirty, ')
          ..write('deleted: $deleted, ')
          ..write('keyGeneration: $keyGeneration, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('syncAttempts: $syncAttempts, ')
          ..write('lastSyncError: $lastSyncError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    $driftBlobEquality.hash(payload),
    revision,
    dirty,
    deleted,
    keyGeneration,
    createdAt,
    updatedAt,
    serverUpdatedAt,
    syncAttempts,
    lastSyncError,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VaultRecord &&
          other.id == this.id &&
          other.kind == this.kind &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.revision == this.revision &&
          other.dirty == this.dirty &&
          other.deleted == this.deleted &&
          other.keyGeneration == this.keyGeneration &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.syncAttempts == this.syncAttempts &&
          other.lastSyncError == this.lastSyncError);
}

class VaultRecordsCompanion extends UpdateCompanion<VaultRecord> {
  final Value<String> id;
  final Value<RecordKind> kind;
  final Value<Uint8List?> payload;
  final Value<int> revision;
  final Value<bool> dirty;
  final Value<bool> deleted;
  final Value<int> keyGeneration;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> serverUpdatedAt;
  final Value<int> syncAttempts;
  final Value<String?> lastSyncError;
  final Value<int> rowid;
  const VaultRecordsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.payload = const Value.absent(),
    this.revision = const Value.absent(),
    this.dirty = const Value.absent(),
    this.deleted = const Value.absent(),
    this.keyGeneration = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.syncAttempts = const Value.absent(),
    this.lastSyncError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VaultRecordsCompanion.insert({
    required String id,
    required RecordKind kind,
    this.payload = const Value.absent(),
    this.revision = const Value.absent(),
    this.dirty = const Value.absent(),
    this.deleted = const Value.absent(),
    this.keyGeneration = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.serverUpdatedAt = const Value.absent(),
    this.syncAttempts = const Value.absent(),
    this.lastSyncError = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<VaultRecord> custom({
    Expression<String>? id,
    Expression<int>? kind,
    Expression<Uint8List>? payload,
    Expression<int>? revision,
    Expression<bool>? dirty,
    Expression<bool>? deleted,
    Expression<int>? keyGeneration,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? serverUpdatedAt,
    Expression<int>? syncAttempts,
    Expression<String>? lastSyncError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (payload != null) 'payload': payload,
      if (revision != null) 'revision': revision,
      if (dirty != null) 'dirty': dirty,
      if (deleted != null) 'deleted': deleted,
      if (keyGeneration != null) 'key_generation': keyGeneration,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (syncAttempts != null) 'sync_attempts': syncAttempts,
      if (lastSyncError != null) 'last_sync_error': lastSyncError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VaultRecordsCompanion copyWith({
    Value<String>? id,
    Value<RecordKind>? kind,
    Value<Uint8List?>? payload,
    Value<int>? revision,
    Value<bool>? dirty,
    Value<bool>? deleted,
    Value<int>? keyGeneration,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? serverUpdatedAt,
    Value<int>? syncAttempts,
    Value<String?>? lastSyncError,
    Value<int>? rowid,
  }) {
    return VaultRecordsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      revision: revision ?? this.revision,
      dirty: dirty ?? this.dirty,
      deleted: deleted ?? this.deleted,
      keyGeneration: keyGeneration ?? this.keyGeneration,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      syncAttempts: syncAttempts ?? this.syncAttempts,
      lastSyncError: lastSyncError ?? this.lastSyncError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>($VaultRecordsTable.$converterkind.toSql(kind.value));
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (keyGeneration.present) {
      map['key_generation'] = Variable<int>(keyGeneration.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (syncAttempts.present) {
      map['sync_attempts'] = Variable<int>(syncAttempts.value);
    }
    if (lastSyncError.present) {
      map['last_sync_error'] = Variable<String>(lastSyncError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VaultRecordsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('payload: $payload, ')
          ..write('revision: $revision, ')
          ..write('dirty: $dirty, ')
          ..write('deleted: $deleted, ')
          ..write('keyGeneration: $keyGeneration, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('syncAttempts: $syncAttempts, ')
          ..write('lastSyncError: $lastSyncError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncConflictsTable extends SyncConflicts with TableInfo<$SyncConflictsTable, SyncConflict> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta('recordId');
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RecordKind, int> kind = GeneratedColumn<int>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  ).withConverter<RecordKind>($SyncConflictsTable.$converterkind);
  static const VerificationMeta _localPayloadMeta = const VerificationMeta('localPayload');
  @override
  late final GeneratedColumn<Uint8List> localPayload = GeneratedColumn<Uint8List>(
    'local_payload',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteRevisionMeta = const VerificationMeta('remoteRevision');
  @override
  late final GeneratedColumn<int> remoteRevision = GeneratedColumn<int>(
    'remote_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detectedAtMeta = const VerificationMeta('detectedAt');
  @override
  late final GeneratedColumn<DateTime> detectedAt = GeneratedColumn<DateTime>(
    'detected_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, recordId, kind, localPayload, remoteRevision, detectedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_conflicts';
  @override
  VerificationContext validateIntegrity(Insertable<SyncConflict> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('record_id')) {
      context.handle(_recordIdMeta, recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta));
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('local_payload')) {
      context.handle(_localPayloadMeta, localPayload.isAcceptableOrUnknown(data['local_payload']!, _localPayloadMeta));
    } else if (isInserting) {
      context.missing(_localPayloadMeta);
    }
    if (data.containsKey('remote_revision')) {
      context.handle(
        _remoteRevisionMeta,
        remoteRevision.isAcceptableOrUnknown(data['remote_revision']!, _remoteRevisionMeta),
      );
    } else if (isInserting) {
      context.missing(_remoteRevisionMeta);
    }
    if (data.containsKey('detected_at')) {
      context.handle(_detectedAtMeta, detectedAt.isAcceptableOrUnknown(data['detected_at']!, _detectedAtMeta));
    } else if (isInserting) {
      context.missing(_detectedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncConflict map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncConflict(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      recordId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}record_id'])!,
      kind: $SyncConflictsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}kind'])!,
      ),
      localPayload: attachedDatabase.typeMapping.read(DriftSqlType.blob, data['${effectivePrefix}local_payload'])!,
      remoteRevision: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}remote_revision'])!,
      detectedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}detected_at'])!,
    );
  }

  @override
  $SyncConflictsTable createAlias(String alias) {
    return $SyncConflictsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RecordKind, int, int> $converterkind = const EnumIndexConverter<RecordKind>(
    RecordKind.values,
  );
}

class SyncConflict extends DataClass implements Insertable<SyncConflict> {
  final int id;
  final String recordId;
  final RecordKind kind;
  final Uint8List localPayload;
  final int remoteRevision;
  final DateTime detectedAt;
  const SyncConflict({
    required this.id,
    required this.recordId,
    required this.kind,
    required this.localPayload,
    required this.remoteRevision,
    required this.detectedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['record_id'] = Variable<String>(recordId);
    {
      map['kind'] = Variable<int>($SyncConflictsTable.$converterkind.toSql(kind));
    }
    map['local_payload'] = Variable<Uint8List>(localPayload);
    map['remote_revision'] = Variable<int>(remoteRevision);
    map['detected_at'] = Variable<DateTime>(detectedAt);
    return map;
  }

  SyncConflictsCompanion toCompanion(bool nullToAbsent) {
    return SyncConflictsCompanion(
      id: Value(id),
      recordId: Value(recordId),
      kind: Value(kind),
      localPayload: Value(localPayload),
      remoteRevision: Value(remoteRevision),
      detectedAt: Value(detectedAt),
    );
  }

  factory SyncConflict.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncConflict(
      id: serializer.fromJson<int>(json['id']),
      recordId: serializer.fromJson<String>(json['recordId']),
      kind: $SyncConflictsTable.$converterkind.fromJson(serializer.fromJson<int>(json['kind'])),
      localPayload: serializer.fromJson<Uint8List>(json['localPayload']),
      remoteRevision: serializer.fromJson<int>(json['remoteRevision']),
      detectedAt: serializer.fromJson<DateTime>(json['detectedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'recordId': serializer.toJson<String>(recordId),
      'kind': serializer.toJson<int>($SyncConflictsTable.$converterkind.toJson(kind)),
      'localPayload': serializer.toJson<Uint8List>(localPayload),
      'remoteRevision': serializer.toJson<int>(remoteRevision),
      'detectedAt': serializer.toJson<DateTime>(detectedAt),
    };
  }

  SyncConflict copyWith({
    int? id,
    String? recordId,
    RecordKind? kind,
    Uint8List? localPayload,
    int? remoteRevision,
    DateTime? detectedAt,
  }) => SyncConflict(
    id: id ?? this.id,
    recordId: recordId ?? this.recordId,
    kind: kind ?? this.kind,
    localPayload: localPayload ?? this.localPayload,
    remoteRevision: remoteRevision ?? this.remoteRevision,
    detectedAt: detectedAt ?? this.detectedAt,
  );
  SyncConflict copyWithCompanion(SyncConflictsCompanion data) {
    return SyncConflict(
      id: data.id.present ? data.id.value : this.id,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      kind: data.kind.present ? data.kind.value : this.kind,
      localPayload: data.localPayload.present ? data.localPayload.value : this.localPayload,
      remoteRevision: data.remoteRevision.present ? data.remoteRevision.value : this.remoteRevision,
      detectedAt: data.detectedAt.present ? data.detectedAt.value : this.detectedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflict(')
          ..write('id: $id, ')
          ..write('recordId: $recordId, ')
          ..write('kind: $kind, ')
          ..write('localPayload: $localPayload, ')
          ..write('remoteRevision: $remoteRevision, ')
          ..write('detectedAt: $detectedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, recordId, kind, $driftBlobEquality.hash(localPayload), remoteRevision, detectedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncConflict &&
          other.id == this.id &&
          other.recordId == this.recordId &&
          other.kind == this.kind &&
          $driftBlobEquality.equals(other.localPayload, this.localPayload) &&
          other.remoteRevision == this.remoteRevision &&
          other.detectedAt == this.detectedAt);
}

class SyncConflictsCompanion extends UpdateCompanion<SyncConflict> {
  final Value<int> id;
  final Value<String> recordId;
  final Value<RecordKind> kind;
  final Value<Uint8List> localPayload;
  final Value<int> remoteRevision;
  final Value<DateTime> detectedAt;
  const SyncConflictsCompanion({
    this.id = const Value.absent(),
    this.recordId = const Value.absent(),
    this.kind = const Value.absent(),
    this.localPayload = const Value.absent(),
    this.remoteRevision = const Value.absent(),
    this.detectedAt = const Value.absent(),
  });
  SyncConflictsCompanion.insert({
    this.id = const Value.absent(),
    required String recordId,
    required RecordKind kind,
    required Uint8List localPayload,
    required int remoteRevision,
    required DateTime detectedAt,
  }) : recordId = Value(recordId),
       kind = Value(kind),
       localPayload = Value(localPayload),
       remoteRevision = Value(remoteRevision),
       detectedAt = Value(detectedAt);
  static Insertable<SyncConflict> custom({
    Expression<int>? id,
    Expression<String>? recordId,
    Expression<int>? kind,
    Expression<Uint8List>? localPayload,
    Expression<int>? remoteRevision,
    Expression<DateTime>? detectedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordId != null) 'record_id': recordId,
      if (kind != null) 'kind': kind,
      if (localPayload != null) 'local_payload': localPayload,
      if (remoteRevision != null) 'remote_revision': remoteRevision,
      if (detectedAt != null) 'detected_at': detectedAt,
    });
  }

  SyncConflictsCompanion copyWith({
    Value<int>? id,
    Value<String>? recordId,
    Value<RecordKind>? kind,
    Value<Uint8List>? localPayload,
    Value<int>? remoteRevision,
    Value<DateTime>? detectedAt,
  }) {
    return SyncConflictsCompanion(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      kind: kind ?? this.kind,
      localPayload: localPayload ?? this.localPayload,
      remoteRevision: remoteRevision ?? this.remoteRevision,
      detectedAt: detectedAt ?? this.detectedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<int>($SyncConflictsTable.$converterkind.toSql(kind.value));
    }
    if (localPayload.present) {
      map['local_payload'] = Variable<Uint8List>(localPayload.value);
    }
    if (remoteRevision.present) {
      map['remote_revision'] = Variable<int>(remoteRevision.value);
    }
    if (detectedAt.present) {
      map['detected_at'] = Variable<DateTime>(detectedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncConflictsCompanion(')
          ..write('id: $id, ')
          ..write('recordId: $recordId, ')
          ..write('kind: $kind, ')
          ..write('localPayload: $localPayload, ')
          ..write('remoteRevision: $remoteRevision, ')
          ..write('detectedAt: $detectedAt')
          ..write(')'))
        .toString();
  }
}

class $LocalAttachmentsTable extends LocalAttachments with TableInfo<$LocalAttachmentsTable, LocalAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptedSizeMeta = const VerificationMeta('encryptedSize');
  @override
  late final GeneratedColumn<int> encryptedSize = GeneratedColumn<int>(
    'encrypted_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cipherSha256Meta = const VerificationMeta('cipherSha256');
  @override
  late final GeneratedColumn<String> cipherSha256 = GeneratedColumn<String>(
    'cipher_sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AttachmentSyncState, int> syncState = GeneratedColumn<int>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  ).withConverter<AttachmentSyncState>($LocalAttachmentsTable.$convertersyncState);
  static const VerificationMeta _uploadAttemptsMeta = const VerificationMeta('uploadAttempts');
  @override
  late final GeneratedColumn<int> uploadAttempts = GeneratedColumn<int>(
    'upload_attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    itemId,
    localPath,
    encryptedSize,
    cipherSha256,
    syncState,
    uploadAttempts,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_attachments';
  @override
  VerificationContext validateIntegrity(Insertable<LocalAttachment> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta, itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta, localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    }
    if (data.containsKey('encrypted_size')) {
      context.handle(
        _encryptedSizeMeta,
        encryptedSize.isAcceptableOrUnknown(data['encrypted_size']!, _encryptedSizeMeta),
      );
    } else if (isInserting) {
      context.missing(_encryptedSizeMeta);
    }
    if (data.containsKey('cipher_sha256')) {
      context.handle(_cipherSha256Meta, cipherSha256.isAcceptableOrUnknown(data['cipher_sha256']!, _cipherSha256Meta));
    } else if (isInserting) {
      context.missing(_cipherSha256Meta);
    }
    if (data.containsKey('upload_attempts')) {
      context.handle(
        _uploadAttemptsMeta,
        uploadAttempts.isAcceptableOrUnknown(data['upload_attempts']!, _uploadAttemptsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalAttachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAttachment(
      id: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      itemId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      localPath: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}local_path']),
      encryptedSize: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}encrypted_size'])!,
      cipherSha256: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}cipher_sha256'])!,
      syncState: $LocalAttachmentsTable.$convertersyncState.fromSql(
        attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sync_state'])!,
      ),
      uploadAttempts: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}upload_attempts'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LocalAttachmentsTable createAlias(String alias) {
    return $LocalAttachmentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AttachmentSyncState, int, int> $convertersyncState =
      const EnumIndexConverter<AttachmentSyncState>(AttachmentSyncState.values);
}

class LocalAttachment extends DataClass implements Insertable<LocalAttachment> {
  final String id;
  final String itemId;

  /// Path of the *encrypted* blob inside the app sandbox, if present.
  final String? localPath;
  final int encryptedSize;

  /// SHA-256 of the encrypted blob - verified after download and before
  /// decryption (decryption itself also authenticates every chunk).
  final String cipherSha256;
  final AttachmentSyncState syncState;
  final int uploadAttempts;
  final DateTime createdAt;
  const LocalAttachment({
    required this.id,
    required this.itemId,
    this.localPath,
    required this.encryptedSize,
    required this.cipherSha256,
    required this.syncState,
    required this.uploadAttempts,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['item_id'] = Variable<String>(itemId);
    if (!nullToAbsent || localPath != null) {
      map['local_path'] = Variable<String>(localPath);
    }
    map['encrypted_size'] = Variable<int>(encryptedSize);
    map['cipher_sha256'] = Variable<String>(cipherSha256);
    {
      map['sync_state'] = Variable<int>($LocalAttachmentsTable.$convertersyncState.toSql(syncState));
    }
    map['upload_attempts'] = Variable<int>(uploadAttempts);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return LocalAttachmentsCompanion(
      id: Value(id),
      itemId: Value(itemId),
      localPath: localPath == null && nullToAbsent ? const Value.absent() : Value(localPath),
      encryptedSize: Value(encryptedSize),
      cipherSha256: Value(cipherSha256),
      syncState: Value(syncState),
      uploadAttempts: Value(uploadAttempts),
      createdAt: Value(createdAt),
    );
  }

  factory LocalAttachment.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAttachment(
      id: serializer.fromJson<String>(json['id']),
      itemId: serializer.fromJson<String>(json['itemId']),
      localPath: serializer.fromJson<String?>(json['localPath']),
      encryptedSize: serializer.fromJson<int>(json['encryptedSize']),
      cipherSha256: serializer.fromJson<String>(json['cipherSha256']),
      syncState: $LocalAttachmentsTable.$convertersyncState.fromJson(serializer.fromJson<int>(json['syncState'])),
      uploadAttempts: serializer.fromJson<int>(json['uploadAttempts']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'itemId': serializer.toJson<String>(itemId),
      'localPath': serializer.toJson<String?>(localPath),
      'encryptedSize': serializer.toJson<int>(encryptedSize),
      'cipherSha256': serializer.toJson<String>(cipherSha256),
      'syncState': serializer.toJson<int>($LocalAttachmentsTable.$convertersyncState.toJson(syncState)),
      'uploadAttempts': serializer.toJson<int>(uploadAttempts),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalAttachment copyWith({
    String? id,
    String? itemId,
    Value<String?> localPath = const Value.absent(),
    int? encryptedSize,
    String? cipherSha256,
    AttachmentSyncState? syncState,
    int? uploadAttempts,
    DateTime? createdAt,
  }) => LocalAttachment(
    id: id ?? this.id,
    itemId: itemId ?? this.itemId,
    localPath: localPath.present ? localPath.value : this.localPath,
    encryptedSize: encryptedSize ?? this.encryptedSize,
    cipherSha256: cipherSha256 ?? this.cipherSha256,
    syncState: syncState ?? this.syncState,
    uploadAttempts: uploadAttempts ?? this.uploadAttempts,
    createdAt: createdAt ?? this.createdAt,
  );
  LocalAttachment copyWithCompanion(LocalAttachmentsCompanion data) {
    return LocalAttachment(
      id: data.id.present ? data.id.value : this.id,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      encryptedSize: data.encryptedSize.present ? data.encryptedSize.value : this.encryptedSize,
      cipherSha256: data.cipherSha256.present ? data.cipherSha256.value : this.cipherSha256,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
      uploadAttempts: data.uploadAttempts.present ? data.uploadAttempts.value : this.uploadAttempts,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttachment(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('localPath: $localPath, ')
          ..write('encryptedSize: $encryptedSize, ')
          ..write('cipherSha256: $cipherSha256, ')
          ..write('syncState: $syncState, ')
          ..write('uploadAttempts: $uploadAttempts, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, itemId, localPath, encryptedSize, cipherSha256, syncState, uploadAttempts, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAttachment &&
          other.id == this.id &&
          other.itemId == this.itemId &&
          other.localPath == this.localPath &&
          other.encryptedSize == this.encryptedSize &&
          other.cipherSha256 == this.cipherSha256 &&
          other.syncState == this.syncState &&
          other.uploadAttempts == this.uploadAttempts &&
          other.createdAt == this.createdAt);
}

class LocalAttachmentsCompanion extends UpdateCompanion<LocalAttachment> {
  final Value<String> id;
  final Value<String> itemId;
  final Value<String?> localPath;
  final Value<int> encryptedSize;
  final Value<String> cipherSha256;
  final Value<AttachmentSyncState> syncState;
  final Value<int> uploadAttempts;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const LocalAttachmentsCompanion({
    this.id = const Value.absent(),
    this.itemId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.encryptedSize = const Value.absent(),
    this.cipherSha256 = const Value.absent(),
    this.syncState = const Value.absent(),
    this.uploadAttempts = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAttachmentsCompanion.insert({
    required String id,
    required String itemId,
    this.localPath = const Value.absent(),
    required int encryptedSize,
    required String cipherSha256,
    required AttachmentSyncState syncState,
    this.uploadAttempts = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       itemId = Value(itemId),
       encryptedSize = Value(encryptedSize),
       cipherSha256 = Value(cipherSha256),
       syncState = Value(syncState),
       createdAt = Value(createdAt);
  static Insertable<LocalAttachment> custom({
    Expression<String>? id,
    Expression<String>? itemId,
    Expression<String>? localPath,
    Expression<int>? encryptedSize,
    Expression<String>? cipherSha256,
    Expression<int>? syncState,
    Expression<int>? uploadAttempts,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (itemId != null) 'item_id': itemId,
      if (localPath != null) 'local_path': localPath,
      if (encryptedSize != null) 'encrypted_size': encryptedSize,
      if (cipherSha256 != null) 'cipher_sha256': cipherSha256,
      if (syncState != null) 'sync_state': syncState,
      if (uploadAttempts != null) 'upload_attempts': uploadAttempts,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String>? itemId,
    Value<String?>? localPath,
    Value<int>? encryptedSize,
    Value<String>? cipherSha256,
    Value<AttachmentSyncState>? syncState,
    Value<int>? uploadAttempts,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return LocalAttachmentsCompanion(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      localPath: localPath ?? this.localPath,
      encryptedSize: encryptedSize ?? this.encryptedSize,
      cipherSha256: cipherSha256 ?? this.cipherSha256,
      syncState: syncState ?? this.syncState,
      uploadAttempts: uploadAttempts ?? this.uploadAttempts,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (encryptedSize.present) {
      map['encrypted_size'] = Variable<int>(encryptedSize.value);
    }
    if (cipherSha256.present) {
      map['cipher_sha256'] = Variable<String>(cipherSha256.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<int>($LocalAttachmentsTable.$convertersyncState.toSql(syncState.value));
    }
    if (uploadAttempts.present) {
      map['upload_attempts'] = Variable<int>(uploadAttempts.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('itemId: $itemId, ')
          ..write('localPath: $localPath, ')
          ..write('encryptedSize: $encryptedSize, ')
          ..write('cipherSha256: $cipherSha256, ')
          ..write('syncState: $syncState, ')
          ..write('uploadAttempts: $uploadAttempts, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecentAccessTable extends RecentAccess with TableInfo<$RecentAccessTable, RecentAccessData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentAccessTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accessedAtMeta = const VerificationMeta('accessedAt');
  @override
  late final GeneratedColumn<DateTime> accessedAt = GeneratedColumn<DateTime>(
    'accessed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accessCountMeta = const VerificationMeta('accessCount');
  @override
  late final GeneratedColumn<int> accessCount = GeneratedColumn<int>(
    'access_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [itemId, accessedAt, accessCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_access';
  @override
  VerificationContext validateIntegrity(Insertable<RecentAccessData> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_id')) {
      context.handle(_itemIdMeta, itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta));
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('accessed_at')) {
      context.handle(_accessedAtMeta, accessedAt.isAcceptableOrUnknown(data['accessed_at']!, _accessedAtMeta));
    } else if (isInserting) {
      context.missing(_accessedAtMeta);
    }
    if (data.containsKey('access_count')) {
      context.handle(_accessCountMeta, accessCount.isAcceptableOrUnknown(data['access_count']!, _accessCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemId};
  @override
  RecentAccessData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentAccessData(
      itemId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}item_id'])!,
      accessedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}accessed_at'])!,
      accessCount: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}access_count'])!,
    );
  }

  @override
  $RecentAccessTable createAlias(String alias) {
    return $RecentAccessTable(attachedDatabase, alias);
  }
}

class RecentAccessData extends DataClass implements Insertable<RecentAccessData> {
  final String itemId;
  final DateTime accessedAt;
  final int accessCount;
  const RecentAccessData({required this.itemId, required this.accessedAt, required this.accessCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_id'] = Variable<String>(itemId);
    map['accessed_at'] = Variable<DateTime>(accessedAt);
    map['access_count'] = Variable<int>(accessCount);
    return map;
  }

  RecentAccessCompanion toCompanion(bool nullToAbsent) {
    return RecentAccessCompanion(itemId: Value(itemId), accessedAt: Value(accessedAt), accessCount: Value(accessCount));
  }

  factory RecentAccessData.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentAccessData(
      itemId: serializer.fromJson<String>(json['itemId']),
      accessedAt: serializer.fromJson<DateTime>(json['accessedAt']),
      accessCount: serializer.fromJson<int>(json['accessCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemId': serializer.toJson<String>(itemId),
      'accessedAt': serializer.toJson<DateTime>(accessedAt),
      'accessCount': serializer.toJson<int>(accessCount),
    };
  }

  RecentAccessData copyWith({String? itemId, DateTime? accessedAt, int? accessCount}) => RecentAccessData(
    itemId: itemId ?? this.itemId,
    accessedAt: accessedAt ?? this.accessedAt,
    accessCount: accessCount ?? this.accessCount,
  );
  RecentAccessData copyWithCompanion(RecentAccessCompanion data) {
    return RecentAccessData(
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      accessedAt: data.accessedAt.present ? data.accessedAt.value : this.accessedAt,
      accessCount: data.accessCount.present ? data.accessCount.value : this.accessCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentAccessData(')
          ..write('itemId: $itemId, ')
          ..write('accessedAt: $accessedAt, ')
          ..write('accessCount: $accessCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(itemId, accessedAt, accessCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentAccessData &&
          other.itemId == this.itemId &&
          other.accessedAt == this.accessedAt &&
          other.accessCount == this.accessCount);
}

class RecentAccessCompanion extends UpdateCompanion<RecentAccessData> {
  final Value<String> itemId;
  final Value<DateTime> accessedAt;
  final Value<int> accessCount;
  final Value<int> rowid;
  const RecentAccessCompanion({
    this.itemId = const Value.absent(),
    this.accessedAt = const Value.absent(),
    this.accessCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentAccessCompanion.insert({
    required String itemId,
    required DateTime accessedAt,
    this.accessCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemId = Value(itemId),
       accessedAt = Value(accessedAt);
  static Insertable<RecentAccessData> custom({
    Expression<String>? itemId,
    Expression<DateTime>? accessedAt,
    Expression<int>? accessCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemId != null) 'item_id': itemId,
      if (accessedAt != null) 'accessed_at': accessedAt,
      if (accessCount != null) 'access_count': accessCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentAccessCompanion copyWith({
    Value<String>? itemId,
    Value<DateTime>? accessedAt,
    Value<int>? accessCount,
    Value<int>? rowid,
  }) {
    return RecentAccessCompanion(
      itemId: itemId ?? this.itemId,
      accessedAt: accessedAt ?? this.accessedAt,
      accessCount: accessCount ?? this.accessCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (accessedAt.present) {
      map['accessed_at'] = Variable<DateTime>(accessedAt.value);
    }
    if (accessCount.present) {
      map['access_count'] = Variable<int>(accessCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentAccessCompanion(')
          ..write('itemId: $itemId, ')
          ..write('accessedAt: $accessedAt, ')
          ..write('accessCount: $accessCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KeyValuesTable extends KeyValues with TableInfo<$KeyValuesTable, KeyValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KeyValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'key_values';
  @override
  VerificationContext validateIntegrity(Insertable<KeyValue> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(_keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(_valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  KeyValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KeyValue(
      key: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $KeyValuesTable createAlias(String alias) {
    return $KeyValuesTable(attachedDatabase, alias);
  }
}

class KeyValue extends DataClass implements Insertable<KeyValue> {
  final String key;
  final String value;
  const KeyValue({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  KeyValuesCompanion toCompanion(bool nullToAbsent) {
    return KeyValuesCompanion(key: Value(key), value: Value(value));
  }

  factory KeyValue.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KeyValue(key: serializer.fromJson<String>(json['key']), value: serializer.fromJson<String>(json['value']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'key': serializer.toJson<String>(key), 'value': serializer.toJson<String>(value)};
  }

  KeyValue copyWith({String? key, String? value}) => KeyValue(key: key ?? this.key, value: value ?? this.value);
  KeyValue copyWithCompanion(KeyValuesCompanion data) {
    return KeyValue(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KeyValue(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is KeyValue && other.key == this.key && other.value == this.value);
}

class KeyValuesCompanion extends UpdateCompanion<KeyValue> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const KeyValuesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KeyValuesCompanion.insert({required String key, required String value, this.rowid = const Value.absent()})
    : key = Value(key),
      value = Value(value);
  static Insertable<KeyValue> custom({Expression<String>? key, Expression<String>? value, Expression<int>? rowid}) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KeyValuesCompanion copyWith({Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return KeyValuesCompanion(key: key ?? this.key, value: value ?? this.value, rowid: rowid ?? this.rowid);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KeyValuesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $VaultRecordsTable vaultRecords = $VaultRecordsTable(this);
  late final $SyncConflictsTable syncConflicts = $SyncConflictsTable(this);
  late final $LocalAttachmentsTable localAttachments = $LocalAttachmentsTable(this);
  late final $RecentAccessTable recentAccess = $RecentAccessTable(this);
  late final $KeyValuesTable keyValues = $KeyValuesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    vaultRecords,
    syncConflicts,
    localAttachments,
    recentAccess,
    keyValues,
  ];
}

typedef $$VaultRecordsTableCreateCompanionBuilder =
    VaultRecordsCompanion Function({
      required String id,
      required RecordKind kind,
      Value<Uint8List?> payload,
      Value<int> revision,
      Value<bool> dirty,
      Value<bool> deleted,
      Value<int> keyGeneration,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> serverUpdatedAt,
      Value<int> syncAttempts,
      Value<String?> lastSyncError,
      Value<int> rowid,
    });
typedef $$VaultRecordsTableUpdateCompanionBuilder =
    VaultRecordsCompanion Function({
      Value<String> id,
      Value<RecordKind> kind,
      Value<Uint8List?> payload,
      Value<int> revision,
      Value<bool> dirty,
      Value<bool> deleted,
      Value<int> keyGeneration,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> serverUpdatedAt,
      Value<int> syncAttempts,
      Value<String?> lastSyncError,
      Value<int> rowid,
    });

class $$VaultRecordsTableFilterComposer extends Composer<_$AppDatabase, $VaultRecordsTable> {
  $$VaultRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<RecordKind, RecordKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<Uint8List> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get dirty => $composableBuilder(column: $table.dirty, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get keyGeneration =>
      $composableBuilder(column: $table.keyGeneration, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get serverUpdatedAt =>
      $composableBuilder(column: $table.serverUpdatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get syncAttempts =>
      $composableBuilder(column: $table.syncAttempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastSyncError =>
      $composableBuilder(column: $table.lastSyncError, builder: (column) => ColumnFilters(column));
}

class $$VaultRecordsTableOrderingComposer extends Composer<_$AppDatabase, $VaultRecordsTable> {
  $$VaultRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get keyGeneration =>
      $composableBuilder(column: $table.keyGeneration, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get serverUpdatedAt =>
      $composableBuilder(column: $table.serverUpdatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncAttempts =>
      $composableBuilder(column: $table.syncAttempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastSyncError =>
      $composableBuilder(column: $table.lastSyncError, builder: (column) => ColumnOrderings(column));
}

class $$VaultRecordsTableAnnotationComposer extends Composer<_$AppDatabase, $VaultRecordsTable> {
  $$VaultRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RecordKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<Uint8List> get payload => $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get revision => $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<bool> get dirty => $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<bool> get deleted => $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get keyGeneration =>
      $composableBuilder(column: $table.keyGeneration, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt => $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get serverUpdatedAt =>
      $composableBuilder(column: $table.serverUpdatedAt, builder: (column) => column);

  GeneratedColumn<int> get syncAttempts => $composableBuilder(column: $table.syncAttempts, builder: (column) => column);

  GeneratedColumn<String> get lastSyncError =>
      $composableBuilder(column: $table.lastSyncError, builder: (column) => column);
}

class $$VaultRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VaultRecordsTable,
          VaultRecord,
          $$VaultRecordsTableFilterComposer,
          $$VaultRecordsTableOrderingComposer,
          $$VaultRecordsTableAnnotationComposer,
          $$VaultRecordsTableCreateCompanionBuilder,
          $$VaultRecordsTableUpdateCompanionBuilder,
          (VaultRecord, BaseReferences<_$AppDatabase, $VaultRecordsTable, VaultRecord>),
          VaultRecord,
          PrefetchHooks Function()
        > {
  $$VaultRecordsTableTableManager(_$AppDatabase db, $VaultRecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$VaultRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$VaultRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$VaultRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<RecordKind> kind = const Value.absent(),
                Value<Uint8List?> payload = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> keyGeneration = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<int> syncAttempts = const Value.absent(),
                Value<String?> lastSyncError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultRecordsCompanion(
                id: id,
                kind: kind,
                payload: payload,
                revision: revision,
                dirty: dirty,
                deleted: deleted,
                keyGeneration: keyGeneration,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                syncAttempts: syncAttempts,
                lastSyncError: lastSyncError,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required RecordKind kind,
                Value<Uint8List?> payload = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> keyGeneration = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> serverUpdatedAt = const Value.absent(),
                Value<int> syncAttempts = const Value.absent(),
                Value<String?> lastSyncError = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VaultRecordsCompanion.insert(
                id: id,
                kind: kind,
                payload: payload,
                revision: revision,
                dirty: dirty,
                deleted: deleted,
                keyGeneration: keyGeneration,
                createdAt: createdAt,
                updatedAt: updatedAt,
                serverUpdatedAt: serverUpdatedAt,
                syncAttempts: syncAttempts,
                lastSyncError: lastSyncError,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$VaultRecordsTable, VaultRecord>(table),
                  BaseReferences<_$AppDatabase, $VaultRecordsTable, VaultRecord>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VaultRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VaultRecordsTable,
      VaultRecord,
      $$VaultRecordsTableFilterComposer,
      $$VaultRecordsTableOrderingComposer,
      $$VaultRecordsTableAnnotationComposer,
      $$VaultRecordsTableCreateCompanionBuilder,
      $$VaultRecordsTableUpdateCompanionBuilder,
      (VaultRecord, BaseReferences<_$AppDatabase, $VaultRecordsTable, VaultRecord>),
      VaultRecord,
      PrefetchHooks Function()
    >;
typedef $$SyncConflictsTableCreateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<int> id,
      required String recordId,
      required RecordKind kind,
      required Uint8List localPayload,
      required int remoteRevision,
      required DateTime detectedAt,
    });
typedef $$SyncConflictsTableUpdateCompanionBuilder =
    SyncConflictsCompanion Function({
      Value<int> id,
      Value<String> recordId,
      Value<RecordKind> kind,
      Value<Uint8List> localPayload,
      Value<int> remoteRevision,
      Value<DateTime> detectedAt,
    });

class $$SyncConflictsTableFilterComposer extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<RecordKind, RecordKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<Uint8List> get localPayload =>
      $composableBuilder(column: $table.localPayload, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get remoteRevision =>
      $composableBuilder(column: $table.remoteRevision, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get detectedAt =>
      $composableBuilder(column: $table.detectedAt, builder: (column) => ColumnFilters(column));
}

class $$SyncConflictsTableOrderingComposer extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<Uint8List> get localPayload =>
      $composableBuilder(column: $table.localPayload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get remoteRevision =>
      $composableBuilder(column: $table.remoteRevision, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get detectedAt =>
      $composableBuilder(column: $table.detectedAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncConflictsTableAnnotationComposer extends Composer<_$AppDatabase, $SyncConflictsTable> {
  $$SyncConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recordId => $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RecordKind, int> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<Uint8List> get localPayload =>
      $composableBuilder(column: $table.localPayload, builder: (column) => column);

  GeneratedColumn<int> get remoteRevision =>
      $composableBuilder(column: $table.remoteRevision, builder: (column) => column);

  GeneratedColumn<DateTime> get detectedAt =>
      $composableBuilder(column: $table.detectedAt, builder: (column) => column);
}

class $$SyncConflictsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncConflictsTable,
          SyncConflict,
          $$SyncConflictsTableFilterComposer,
          $$SyncConflictsTableOrderingComposer,
          $$SyncConflictsTableAnnotationComposer,
          $$SyncConflictsTableCreateCompanionBuilder,
          $$SyncConflictsTableUpdateCompanionBuilder,
          (SyncConflict, BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflict>),
          SyncConflict,
          PrefetchHooks Function()
        > {
  $$SyncConflictsTableTableManager(_$AppDatabase db, $SyncConflictsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$SyncConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$SyncConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$SyncConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<RecordKind> kind = const Value.absent(),
                Value<Uint8List> localPayload = const Value.absent(),
                Value<int> remoteRevision = const Value.absent(),
                Value<DateTime> detectedAt = const Value.absent(),
              }) => SyncConflictsCompanion(
                id: id,
                recordId: recordId,
                kind: kind,
                localPayload: localPayload,
                remoteRevision: remoteRevision,
                detectedAt: detectedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String recordId,
                required RecordKind kind,
                required Uint8List localPayload,
                required int remoteRevision,
                required DateTime detectedAt,
              }) => SyncConflictsCompanion.insert(
                id: id,
                recordId: recordId,
                kind: kind,
                localPayload: localPayload,
                remoteRevision: remoteRevision,
                detectedAt: detectedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncConflictsTable, SyncConflict>(table),
                  BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflict>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncConflictsTable,
      SyncConflict,
      $$SyncConflictsTableFilterComposer,
      $$SyncConflictsTableOrderingComposer,
      $$SyncConflictsTableAnnotationComposer,
      $$SyncConflictsTableCreateCompanionBuilder,
      $$SyncConflictsTableUpdateCompanionBuilder,
      (SyncConflict, BaseReferences<_$AppDatabase, $SyncConflictsTable, SyncConflict>),
      SyncConflict,
      PrefetchHooks Function()
    >;
typedef $$LocalAttachmentsTableCreateCompanionBuilder =
    LocalAttachmentsCompanion Function({
      required String id,
      required String itemId,
      Value<String?> localPath,
      required int encryptedSize,
      required String cipherSha256,
      required AttachmentSyncState syncState,
      Value<int> uploadAttempts,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$LocalAttachmentsTableUpdateCompanionBuilder =
    LocalAttachmentsCompanion Function({
      Value<String> id,
      Value<String> itemId,
      Value<String?> localPath,
      Value<int> encryptedSize,
      Value<String> cipherSha256,
      Value<AttachmentSyncState> syncState,
      Value<int> uploadAttempts,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$LocalAttachmentsTableFilterComposer extends Composer<_$AppDatabase, $LocalAttachmentsTable> {
  $$LocalAttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get encryptedSize =>
      $composableBuilder(column: $table.encryptedSize, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cipherSha256 =>
      $composableBuilder(column: $table.cipherSha256, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<AttachmentSyncState, AttachmentSyncState, int> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get uploadAttempts =>
      $composableBuilder(column: $table.uploadAttempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalAttachmentsTableOrderingComposer extends Composer<_$AppDatabase, $LocalAttachmentsTable> {
  $$LocalAttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get encryptedSize =>
      $composableBuilder(column: $table.encryptedSize, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cipherSha256 =>
      $composableBuilder(column: $table.cipherSha256, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get uploadAttempts =>
      $composableBuilder(column: $table.uploadAttempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalAttachmentsTableAnnotationComposer extends Composer<_$AppDatabase, $LocalAttachmentsTable> {
  $$LocalAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get itemId => $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get localPath => $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get encryptedSize =>
      $composableBuilder(column: $table.encryptedSize, builder: (column) => column);

  GeneratedColumn<String> get cipherSha256 =>
      $composableBuilder(column: $table.cipherSha256, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AttachmentSyncState, int> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);

  GeneratedColumn<int> get uploadAttempts =>
      $composableBuilder(column: $table.uploadAttempts, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalAttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalAttachmentsTable,
          LocalAttachment,
          $$LocalAttachmentsTableFilterComposer,
          $$LocalAttachmentsTableOrderingComposer,
          $$LocalAttachmentsTableAnnotationComposer,
          $$LocalAttachmentsTableCreateCompanionBuilder,
          $$LocalAttachmentsTableUpdateCompanionBuilder,
          (LocalAttachment, BaseReferences<_$AppDatabase, $LocalAttachmentsTable, LocalAttachment>),
          LocalAttachment,
          PrefetchHooks Function()
        > {
  $$LocalAttachmentsTableTableManager(_$AppDatabase db, $LocalAttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$LocalAttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$LocalAttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$LocalAttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String?> localPath = const Value.absent(),
                Value<int> encryptedSize = const Value.absent(),
                Value<String> cipherSha256 = const Value.absent(),
                Value<AttachmentSyncState> syncState = const Value.absent(),
                Value<int> uploadAttempts = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttachmentsCompanion(
                id: id,
                itemId: itemId,
                localPath: localPath,
                encryptedSize: encryptedSize,
                cipherSha256: cipherSha256,
                syncState: syncState,
                uploadAttempts: uploadAttempts,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String itemId,
                Value<String?> localPath = const Value.absent(),
                required int encryptedSize,
                required String cipherSha256,
                required AttachmentSyncState syncState,
                Value<int> uploadAttempts = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => LocalAttachmentsCompanion.insert(
                id: id,
                itemId: itemId,
                localPath: localPath,
                encryptedSize: encryptedSize,
                cipherSha256: cipherSha256,
                syncState: syncState,
                uploadAttempts: uploadAttempts,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalAttachmentsTable, LocalAttachment>(table),
                  BaseReferences<_$AppDatabase, $LocalAttachmentsTable, LocalAttachment>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalAttachmentsTable,
      LocalAttachment,
      $$LocalAttachmentsTableFilterComposer,
      $$LocalAttachmentsTableOrderingComposer,
      $$LocalAttachmentsTableAnnotationComposer,
      $$LocalAttachmentsTableCreateCompanionBuilder,
      $$LocalAttachmentsTableUpdateCompanionBuilder,
      (LocalAttachment, BaseReferences<_$AppDatabase, $LocalAttachmentsTable, LocalAttachment>),
      LocalAttachment,
      PrefetchHooks Function()
    >;
typedef $$RecentAccessTableCreateCompanionBuilder =
    RecentAccessCompanion Function({
      required String itemId,
      required DateTime accessedAt,
      Value<int> accessCount,
      Value<int> rowid,
    });
typedef $$RecentAccessTableUpdateCompanionBuilder =
    RecentAccessCompanion Function({
      Value<String> itemId,
      Value<DateTime> accessedAt,
      Value<int> accessCount,
      Value<int> rowid,
    });

class $$RecentAccessTableFilterComposer extends Composer<_$AppDatabase, $RecentAccessTable> {
  $$RecentAccessTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get accessedAt =>
      $composableBuilder(column: $table.accessedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accessCount =>
      $composableBuilder(column: $table.accessCount, builder: (column) => ColumnFilters(column));
}

class $$RecentAccessTableOrderingComposer extends Composer<_$AppDatabase, $RecentAccessTable> {
  $$RecentAccessTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get accessedAt =>
      $composableBuilder(column: $table.accessedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accessCount =>
      $composableBuilder(column: $table.accessCount, builder: (column) => ColumnOrderings(column));
}

class $$RecentAccessTableAnnotationComposer extends Composer<_$AppDatabase, $RecentAccessTable> {
  $$RecentAccessTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemId => $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<DateTime> get accessedAt =>
      $composableBuilder(column: $table.accessedAt, builder: (column) => column);

  GeneratedColumn<int> get accessCount => $composableBuilder(column: $table.accessCount, builder: (column) => column);
}

class $$RecentAccessTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecentAccessTable,
          RecentAccessData,
          $$RecentAccessTableFilterComposer,
          $$RecentAccessTableOrderingComposer,
          $$RecentAccessTableAnnotationComposer,
          $$RecentAccessTableCreateCompanionBuilder,
          $$RecentAccessTableUpdateCompanionBuilder,
          (RecentAccessData, BaseReferences<_$AppDatabase, $RecentAccessTable, RecentAccessData>),
          RecentAccessData,
          PrefetchHooks Function()
        > {
  $$RecentAccessTableTableManager(_$AppDatabase db, $RecentAccessTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$RecentAccessTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$RecentAccessTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$RecentAccessTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemId = const Value.absent(),
                Value<DateTime> accessedAt = const Value.absent(),
                Value<int> accessCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  RecentAccessCompanion(itemId: itemId, accessedAt: accessedAt, accessCount: accessCount, rowid: rowid),
          createCompanionCallback:
              ({
                required String itemId,
                required DateTime accessedAt,
                Value<int> accessCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecentAccessCompanion.insert(
                itemId: itemId,
                accessedAt: accessedAt,
                accessCount: accessCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecentAccessTable, RecentAccessData>(table),
                  BaseReferences<_$AppDatabase, $RecentAccessTable, RecentAccessData>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentAccessTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecentAccessTable,
      RecentAccessData,
      $$RecentAccessTableFilterComposer,
      $$RecentAccessTableOrderingComposer,
      $$RecentAccessTableAnnotationComposer,
      $$RecentAccessTableCreateCompanionBuilder,
      $$RecentAccessTableUpdateCompanionBuilder,
      (RecentAccessData, BaseReferences<_$AppDatabase, $RecentAccessTable, RecentAccessData>),
      RecentAccessData,
      PrefetchHooks Function()
    >;
typedef $$KeyValuesTableCreateCompanionBuilder =
    KeyValuesCompanion Function({required String key, required String value, Value<int> rowid});
typedef $$KeyValuesTableUpdateCompanionBuilder =
    KeyValuesCompanion Function({Value<String> key, Value<String> value, Value<int> rowid});

class $$KeyValuesTableFilterComposer extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$KeyValuesTableOrderingComposer extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$KeyValuesTableAnnotationComposer extends Composer<_$AppDatabase, $KeyValuesTable> {
  $$KeyValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key => $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value => $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$KeyValuesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KeyValuesTable,
          KeyValue,
          $$KeyValuesTableFilterComposer,
          $$KeyValuesTableOrderingComposer,
          $$KeyValuesTableAnnotationComposer,
          $$KeyValuesTableCreateCompanionBuilder,
          $$KeyValuesTableUpdateCompanionBuilder,
          (KeyValue, BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>),
          KeyValue,
          PrefetchHooks Function()
        > {
  $$KeyValuesTableTableManager(_$AppDatabase db, $KeyValuesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$KeyValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$KeyValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$KeyValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KeyValuesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({required String key, required String value, Value<int> rowid = const Value.absent()}) =>
                  KeyValuesCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KeyValuesTable, KeyValue>(table),
                  BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KeyValuesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KeyValuesTable,
      KeyValue,
      $$KeyValuesTableFilterComposer,
      $$KeyValuesTableOrderingComposer,
      $$KeyValuesTableAnnotationComposer,
      $$KeyValuesTableCreateCompanionBuilder,
      $$KeyValuesTableUpdateCompanionBuilder,
      (KeyValue, BaseReferences<_$AppDatabase, $KeyValuesTable, KeyValue>),
      KeyValue,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$VaultRecordsTableTableManager get vaultRecords => $$VaultRecordsTableTableManager(_db, _db.vaultRecords);
  $$SyncConflictsTableTableManager get syncConflicts => $$SyncConflictsTableTableManager(_db, _db.syncConflicts);
  $$LocalAttachmentsTableTableManager get localAttachments =>
      $$LocalAttachmentsTableTableManager(_db, _db.localAttachments);
  $$RecentAccessTableTableManager get recentAccess => $$RecentAccessTableTableManager(_db, _db.recentAccess);
  $$KeyValuesTableTableManager get keyValues => $$KeyValuesTableTableManager(_db, _db.keyValues);
}
