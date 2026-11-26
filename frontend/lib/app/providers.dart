import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cloud/cloud_bootstrap.dart';
import '../core/cloud/cloud_interfaces.dart';
import '../core/cloud/firebase_auth_repository.dart';
import '../core/cloud/firestore_remote_store.dart';
import '../core/cloud/r2_object_storage.dart';
import '../core/config/app_paths.dart';
import '../core/crypto/crypto_service.dart';
import '../core/crypto/key_hierarchy.dart';
import '../core/db/database.dart';
import '../core/platform/platform_security.dart';
import '../core/storage/secure_store.dart';
import '../features/devices/device_identity.dart';
import '../features/generator/domain/generators.dart';
import '../features/security_health/data/hibp_client.dart';
import '../features/vault/data/record_codec.dart';
import '../features/vault/data/vault_repository.dart';

// ---------------------------------------------------------------------------
// Core singletons - created in bootstrap() and injected via overrides.
// ---------------------------------------------------------------------------

final cryptoProvider = Provider<CryptoService>((_) => throw UnimplementedError('override'));
final secureStoreProvider = Provider<SecureStore>((_) => throw UnimplementedError('override'));
final databaseProvider = Provider<AppDatabase>((_) => throw UnimplementedError('override'));
final appPathsProvider = Provider<AppPaths>((_) => throw UnimplementedError('override'));
final cloudConfigProvider = Provider<CloudConfig>((_) => const CloudConfig.offline());
final wordListProvider = Provider<List<String>>((_) => const []);

final platformSecurityProvider = Provider<PlatformSecurity>((_) => PlatformSecurity());

// ---------------------------------------------------------------------------
// Derived services.
// ---------------------------------------------------------------------------

final keyHierarchyProvider = Provider((ref) => KeyHierarchy(ref.watch(cryptoProvider)));
final recordCodecProvider = Provider((ref) => RecordCodec(ref.watch(cryptoProvider)));

final vaultRepositoryProvider = Provider((ref) {
  final repo = VaultRepository(ref.watch(databaseProvider), ref.watch(recordCodecProvider));
  ref.onDispose(repo.dispose);
  return repo;
});

final deviceIdentityProvider = Provider(
  (ref) => DeviceIdentityService(ref.watch(cryptoProvider), ref.watch(secureStoreProvider)),
);

final hibpClientProvider = Provider((_) => HibpClient());

/// libsodium randombytes_uniform (unbiased CSPRNG) for generators.
final secureRandomProvider = Provider<SecureRandomSource>((ref) => _SodiumRandom(ref.watch(cryptoProvider)));

class _SodiumRandom implements SecureRandomSource {
  _SodiumRandom(this.crypto);
  final CryptoService crypto;
  @override
  int nextInt(int max) => crypto.randomUniform(max);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final cfg = ref.watch(cloudConfigProvider);
  return cfg.firebaseReady ? FirebaseAuthRepository(FirebaseAuth.instance) : const UnavailableAuthRepository();
});

final remoteVaultStoreProvider = Provider<RemoteVaultStore?>((ref) {
  final cfg = ref.watch(cloudConfigProvider);
  return cfg.firebaseReady ? FirestoreRemoteVaultStore(FirebaseFirestore.instance) : null;
});

final objectStorageProvider = Provider<ObjectStorage>((ref) {
  final cfg = ref.watch(cloudConfigProvider);
  if (!cfg.objectStorageReady) return const UnavailableObjectStorage();
  final auth = ref.watch(authRepositoryProvider);
  return R2ObjectStorage(
    apiBaseUrl: cfg.apiBaseUrl,
    idToken: () => auth.idToken(),
    appCheckToken: () async {
      try {
        return await FirebaseAppCheck.instance.getToken();
      } catch (_) {
        return null;
      }
    },
  );
});

/// Signed-in cloud user (null in offline mode or when signed out).
final cloudUserProvider = StreamProvider<CloudUser?>((ref) => ref.watch(authRepositoryProvider).authStateChanges());
