import 'dart:io';
import 'dart:typed_data';

import '../crypto/key_hierarchy.dart';
import '../db/database.dart';

/// Provider-neutral cloud contracts. The app talks only to these interfaces;
/// Firebase / Cloudflare R2 are swappable implementations. Nothing passed
/// through them is plaintext vault data.

class CloudUser {
  const CloudUser({required this.uid, this.email, required this.emailVerified});
  final String uid;
  final String? email;
  final bool emailVerified;
}

class CloudAuthException implements Exception {
  const CloudAuthException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

/// Account authentication (identity only - never the vault key).
abstract interface class AuthRepository {
  bool get available;
  CloudUser? get currentUser;
  Stream<CloudUser?> authStateChanges();
  Future<CloudUser> signUp(String email, String accountPassword);
  Future<CloudUser> signIn(String email, String accountPassword);
  Future<void> sendEmailVerification();
  Future<CloudUser?> reload();
  Future<void> sendPasswordReset(String email);
  Future<void> reauthenticate(String accountPassword);
  Future<void> deleteUser();
  Future<void> signOut();
  Future<String?> idToken({bool forceRefresh = false});
}

class RemoteRecord {
  const RemoteRecord({
    required this.id,
    required this.kind,
    required this.payload,
    required this.revision,
    required this.deleted,
    required this.keyGeneration,
    this.serverUpdatedAt,
    this.createdAt,
    this.deviceId,
  });

  final String id;
  final RecordKind kind;
  final Uint8List? payload;
  final int revision;
  final bool deleted;
  final int keyGeneration;
  final DateTime? serverUpdatedAt;
  final DateTime? createdAt;
  final String? deviceId;
}

class SyncCursor {
  const SyncCursor(this.updatedAt, this.recordId);
  final DateTime updatedAt;
  final String recordId;

  String encode() => '${updatedAt.microsecondsSinceEpoch}|$recordId';
  static SyncCursor? decode(String? s) {
    if (s == null) return null;
    final i = s.indexOf('|');
    if (i < 0) return null;
    final us = int.tryParse(s.substring(0, i));
    if (us == null) return null;
    return SyncCursor(DateTime.fromMicrosecondsSinceEpoch(us, isUtc: true), s.substring(i + 1));
  }
}

class RemoteChanges {
  const RemoteChanges(this.records, this.nextCursor, {required this.hasMore});
  final List<RemoteRecord> records;
  final SyncCursor? nextCursor;
  final bool hasMore;
}

class PushRequest {
  const PushRequest({
    required this.id,
    required this.kind,
    required this.payload,
    required this.baseRevision,
    required this.deleted,
    required this.keyGeneration,
    required this.createdAt,
    required this.deviceId,
  });

  final String id;
  final RecordKind kind;
  final Uint8List? payload;

  /// Revision the local change was based on. The server applies the write
  /// only if its current revision still equals this (optimistic concurrency).
  final int baseRevision;
  final bool deleted;
  final int keyGeneration;
  final DateTime createdAt;
  final String deviceId;
}

enum PushOutcome { applied, alreadyApplied, conflict }

class PushResult {
  const PushResult(this.outcome, {this.newRevision, this.remote});
  final PushOutcome outcome;
  final int? newRevision;
  final RemoteRecord? remote;
}

class DeviceRecord {
  const DeviceRecord({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.osVersion,
    required this.model,
    required this.createdAt,
    required this.lastActiveAt,
    required this.signPublicKey,
    required this.kxPublicKey,
    required this.registrationSignature,
    this.revoked = false,
    this.revokedAt,
  });

  final String deviceId;
  final String name;
  final String platform;
  final String osVersion;
  final String model;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  /// Ed25519 identity key (base64).
  final String signPublicKey;

  /// X25519 key-agreement key for future device-to-device key delivery.
  final String kxPublicKey;

  /// Self-signature over the registration statement (proof of key possession).
  final String registrationSignature;
  final bool revoked;
  final DateTime? revokedAt;
}

class BackupIndexEntry {
  const BackupIndexEntry({
    required this.id,
    required this.createdAt,
    required this.encryptedSize,
    required this.cipherSha256,
    required this.formatVersion,
    required this.deviceId,
  });

  final String id;
  final DateTime createdAt;
  final int encryptedSize;
  final String cipherSha256;
  final int formatVersion;
  final String deviceId;
}

/// Encrypted vault records + key material + devices.
abstract interface class RemoteVaultStore {
  Future<VaultKeyMaterial?> fetchKeyMaterial(String uid);
  Future<void> putKeyMaterial(String uid, VaultKeyMaterial material);
  Future<RemoteChanges> fetchChanges(String uid, {SyncCursor? since, int limit = 300});
  Future<PushResult> push(String uid, PushRequest request);
  Future<RemoteRecord?> fetchRecord(String uid, String id);

  Future<void> upsertDevice(String uid, DeviceRecord device);
  Future<DeviceRecord?> getDevice(String uid, String deviceId);
  Future<List<DeviceRecord>> listDevices(String uid);
  Future<void> touchDevice(String uid, String deviceId);
  Future<void> renameDevice(String uid, String deviceId, String name);
  Future<void> revokeDevice(String uid, String deviceId);

  Future<void> putBackupIndex(String uid, BackupIndexEntry entry);
  Future<List<BackupIndexEntry>> listBackups(String uid);
  Future<void> deleteBackupIndex(String uid, String backupId);

  /// Deletes every document under the user (account deletion).
  Future<void> deleteAllUserData(String uid);
}

enum ObjectKind { attachment, backup }

class ObjectStorageException implements Exception {
  const ObjectStorageException(this.message, {this.retryable = true});
  final String message;
  final bool retryable;
  @override
  String toString() => message;
}

/// Encrypted binary object storage (Cloudflare R2 behind a broker API).
/// Callers must only ever pass already-encrypted files.
abstract interface class ObjectStorage {
  bool get available;
  Future<void> upload(
    ObjectKind kind,
    String objectId,
    File encryptedFile, {
    required String sha256,
    void Function(int sent, int total)? onProgress,
  });
  Future<void> download(
    ObjectKind kind,
    String objectId,
    File destination, {
    void Function(int received, int total)? onProgress,
  });
  Future<void> delete(ObjectKind kind, String objectId);
  Future<void> deleteAll();
}
