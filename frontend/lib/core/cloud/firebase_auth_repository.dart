import 'package:firebase_auth/firebase_auth.dart';

import 'cloud_interfaces.dart';

/// Firebase Authentication identifies the *account*. It is completely
/// separate from the master password, which never reaches Firebase.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth);

  final FirebaseAuth _auth;

  @override
  bool get available => true;

  static CloudUser? _map(User? u) =>
      u == null ? null : CloudUser(uid: u.uid, email: u.email, emailVerified: u.emailVerified);

  @override
  CloudUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<CloudUser?> authStateChanges() => _auth.userChanges().map(_map);

  Future<T> _guard<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on FirebaseAuthException catch (e) {
      throw CloudAuthException(e.code, _friendly(e.code));
    }
  }

  static String _friendly(String code) => switch (code) {
    'invalid-email' => 'That email address is not valid.',
    'user-disabled' => 'This account has been disabled.',
    'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Incorrect email or password.',
    'email-already-in-use' => 'An account already exists for that email.',
    'weak-password' => 'Choose a stronger account password (at least 8 characters).',
    'too-many-requests' => 'Too many attempts. Try again later.',
    'network-request-failed' => 'No network connection.',
    'requires-recent-login' => 'Please sign in again to continue.',
    _ => 'Authentication failed ($code).',
  };

  @override
  Future<CloudUser> signUp(String email, String accountPassword) => _guard(() async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: accountPassword);
    await cred.user!.sendEmailVerification();
    return _map(cred.user)!;
  });

  @override
  Future<CloudUser> signIn(String email, String accountPassword) => _guard(() async {
    final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: accountPassword);
    return _map(cred.user)!;
  });

  @override
  Future<void> sendEmailVerification() => _guard(() async => _auth.currentUser?.sendEmailVerification());

  @override
  Future<CloudUser?> reload() => _guard(() async {
    await _auth.currentUser?.reload();
    // Force a new ID token so the email_verified claim reaches security rules.
    await _auth.currentUser?.getIdToken(true);
    return _map(_auth.currentUser);
  });

  @override
  Future<void> sendPasswordReset(String email) => _guard(() => _auth.sendPasswordResetEmail(email: email.trim()));

  @override
  Future<void> reauthenticate(String accountPassword) => _guard(() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const CloudAuthException('no-user', 'Not signed in.');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: accountPassword),
    );
  });

  @override
  Future<void> deleteUser() => _guard(() async => _auth.currentUser?.delete());

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<String?> idToken({bool forceRefresh = false}) async => _auth.currentUser?.getIdToken(forceRefresh);
}

/// Used when Firebase is not configured: the app runs fully offline.
class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository();

  Never _no() => throw const CloudAuthException('unavailable', 'Cloud sync is not configured.');

  @override
  bool get available => false;
  @override
  CloudUser? get currentUser => null;
  @override
  Stream<CloudUser?> authStateChanges() => Stream.value(null);
  @override
  Future<CloudUser> signUp(String email, String accountPassword) async => _no();
  @override
  Future<CloudUser> signIn(String email, String accountPassword) async => _no();
  @override
  Future<void> sendEmailVerification() async => _no();
  @override
  Future<CloudUser?> reload() async => null;
  @override
  Future<void> sendPasswordReset(String email) async => _no();
  @override
  Future<void> reauthenticate(String accountPassword) async => _no();
  @override
  Future<void> deleteUser() async => _no();
  @override
  Future<void> signOut() async {}
  @override
  Future<String?> idToken({bool forceRefresh = false}) async => null;
}
