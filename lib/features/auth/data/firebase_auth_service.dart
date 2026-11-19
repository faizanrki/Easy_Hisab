import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../../core/domain/app_failure.dart';
import '../domain/auth_service_port.dart';
import '../domain/auth_user.dart';

final class FirebaseAuthService implements AuthServicePort {
  FirebaseAuthService(this._firebaseAuth);

  final fb.FirebaseAuth _firebaseAuth;

  AuthUser _mapFirebaseUser(fb.User user) {
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      phoneNumber: user.phoneNumber,
      isEmailVerified: user.emailVerified,
    );
  }

  @override
  AuthUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    return user != null ? _mapFirebaseUser(user) : null;
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(
          (user) => user != null ? _mapFirebaseUser(user) : null,
        );
  }

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    try {
      final cred = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user == null) {
        throw const NotFoundFailure('Failed to authenticate user');
      }
      return _mapFirebaseUser(cred.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<AuthUser> registerWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final cred = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (cred.user == null) {
        throw const StorageFailure('Account creation failed');
      }
      if (displayName != null && displayName.isNotEmpty) {
        await cred.user!.updateDisplayName(displayName);
      }
      return _mapFirebaseUser(cred.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      final provider = fb.GoogleAuthProvider();
      final cred = await _firebaseAuth.signInWithProvider(provider);
      if (cred.user == null) {
        throw const NotFoundFailure('Google Sign-In failed');
      }
      return _mapFirebaseUser(cred.user!);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  @override
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  AppFailure _mapFirebaseAuthException(fb.FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        const ValidationFailure('Invalid email or password.'),
      'email-already-in-use' =>
        const ValidationFailure('An account with this email already exists.'),
      'weak-password' =>
        const ValidationFailure('The password provided is too weak.'),
      'invalid-email' =>
        const ValidationFailure('The email address is badly formatted.'),
      'user-disabled' =>
        const PermissionFailure('This user account has been disabled.'),
      'too-many-requests' => const ValidationFailure(
          'Too many unsuccessful attempts. Please try again later.'),
      _ => ValidationFailure(e.message ?? 'Authentication error occurred.'),
    };
  }
}
