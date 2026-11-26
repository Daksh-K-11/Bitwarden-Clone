import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/cloud/cloud_interfaces.dart';
import '../../core/storage/secure_store.dart';
import '../../core/util/log.dart';
import '../account/account_service.dart';
import '../attachments/attachment_service.dart';
import '../session/session_controller.dart';
import '../vault/application/vault_controller.dart';
import 'sync_engine.dart';

enum SyncPhase { disabled, idle, syncing, offline, error }

class SyncStatus {
  const SyncStatus({required this.phase, this.lastSyncAt, this.pending = 0, this.message, this.lastReport});

  static const disabled = SyncStatus(phase: SyncPhase.disabled);

  final SyncPhase phase;
  final DateTime? lastSyncAt;
  final int pending;
  final String? message;
  final SyncReport? lastReport;

  SyncStatus copyWith({
    SyncPhase? phase,
    DateTime? lastSyncAt,
    int? pending,
    String? message,
    SyncReport? lastReport,
  }) => SyncStatus(
    phase: phase ?? this.phase,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    pending: pending ?? this.pending,
    message: message,
    lastReport: lastReport ?? this.lastReport,
  );
}

final syncProvider = NotifierProvider<SyncController, SyncStatus>(SyncController.new);

/// Schedules sync runs. Avoids realtime listeners and tight polling to keep
/// Firestore reads low: runs on unlock, ~3 s after local edits (debounced),
/// when connectivity returns, on app resume, on pull-to-refresh, and every
/// 15 minutes while unlocked in the foreground.
class SyncController extends Notifier<SyncStatus> {
  Timer? _debounce;
  Timer? _periodic;
  StreamSubscription<void>? _changesSub;
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  bool _running = false;
  bool _again = false;
  bool _online = true;

  @override
  SyncStatus build() {
    final keys = ref.watch(vaultKeysProvider);
    final user = ref.watch(cloudUserProvider).value;
    final remote = ref.watch(remoteVaultStoreProvider);
    ref.onDispose(_teardown);
    if (keys == null || user == null || remote == null || !user.emailVerified) {
      return SyncStatus.disabled;
    }
    _changesSub = ref.read(vaultRepositoryProvider).changes.listen((_) => schedule());
    _connSub = Connectivity().onConnectivityChanged.listen((r) {
      final online = !r.contains(ConnectivityResult.none) || r.isEmpty;
      final cameOnline = online && !_online;
      _online = online;
      if (cameOnline) schedule(delay: const Duration(seconds: 1));
      if (!online) state = state.copyWith(phase: SyncPhase.offline, message: 'Offline - changes are saved locally');
    });
    _periodic = Timer.periodic(const Duration(minutes: 15), (_) => schedule());
    Future.microtask(() => syncNow());
    return const SyncStatus(phase: SyncPhase.idle);
  }

  void _teardown() {
    _debounce?.cancel();
    _periodic?.cancel();
    _changesSub?.cancel();
    _connSub?.cancel();
  }

  void schedule({Duration delay = const Duration(seconds: 3)}) {
    if (state.phase == SyncPhase.disabled) return;
    _debounce?.cancel();
    _debounce = Timer(delay, syncNow);
  }

  Future<void> syncNow() async {
    if (state.phase == SyncPhase.disabled) return;
    if (_running) {
      _again = true;
      return;
    }
    final session = ref.read(sessionProvider);
    final user = ref.read(authRepositoryProvider).currentUser;
    final remote = ref.read(remoteVaultStoreProvider);
    if (session is! SessionUnlocked || user == null || remote == null) return;
    // Only sync a vault that was explicitly connected to this account.
    if (await ref.read(secureStoreProvider).read(SecureKeys.boundUid) != user.uid) return;

    _running = true;
    final db = ref.read(databaseProvider);
    state = state.copyWith(phase: SyncPhase.syncing, pending: await db.dirtyCount());
    try {
      final identity = await ref.read(deviceIdentityProvider).ensure();
      final engine = SyncEngine(
        db: db,
        remote: remote,
        codec: ref.read(recordCodecProvider),
        deviceId: identity.deviceId,
        onRemoteMaterial: (m) => ref.read(sessionProvider.notifier).replaceMaterial(m),
        onMissingDevice: () => ref.read(accountServiceProvider).registerDevice(),
      );
      final report = await engine.run(uid: user.uid, keys: session.keys, localMaterial: session.material);
      await ref.read(attachmentServiceProvider).syncPending();
      if (report.pulled > 0 || report.conflicts > 0 || report.rollbacksRejected > 0) {
        await ref.read(vaultProvider.notifier).reload();
      }
      state = SyncStatus(
        phase: SyncPhase.idle,
        lastSyncAt: DateTime.now(),
        pending: await db.dirtyCount(),
        lastReport: report,
        message: report.conflicts > 0 ? '${report.conflicts} sync conflict(s) need review' : null,
      );
    } on DeviceRevokedException {
      state = state.copyWith(phase: SyncPhase.error, message: 'This device was revoked');
      Log.w('sync', 'Device revoked - wiping local data');
      await ref.read(authRepositoryProvider).signOut();
      await ref.read(sessionProvider.notifier).wipeLocal();
    } on VaultKeyRotatedException catch (e) {
      await ref.read(sessionProvider.notifier).replaceMaterial(e.material);
      await ref.read(sessionProvider.notifier).lock(reason: e.toString());
    } on ObjectStorageException catch (e) {
      state = state.copyWith(phase: SyncPhase.error, message: e.message, pending: await db.dirtyCount());
    } catch (e) {
      Log.w('sync', 'Sync failed (${e.runtimeType})');
      state = state.copyWith(
        phase: _online ? SyncPhase.error : SyncPhase.offline,
        message: _online ? 'Sync failed - will retry' : 'Offline - changes are saved locally',
        pending: await db.dirtyCount(),
      );
      schedule(delay: const Duration(seconds: 60));
    } finally {
      _running = false;
      if (_again) {
        _again = false;
        schedule(delay: const Duration(milliseconds: 500));
      }
    }
  }
}
