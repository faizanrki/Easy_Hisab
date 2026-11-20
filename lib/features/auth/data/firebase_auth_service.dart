import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/domain/app_failure.dart';
import '../domain/auth_service_port.dart';
import '../domain/auth_user.dart';

final class FirebaseAuthService implements AuthServicePort {
  FirebaseAuthService(this._firebaseAuth, {this.fallbackUser});

  final fb.FirebaseAuth _firebaseAuth;
  AuthUser? fallbackUser;

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
    if (user != null) return _mapFirebaseUser(user);
    return fallbackUser;
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(
          (user) {
            if (user != null) return _mapFirebaseUser(user);
            return fallbackUser;
          },
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
      final user = _mapFirebaseUser(cred.user!);
      fallbackUser = user;
      return user;
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
      final user = _mapFirebaseUser(cred.user!);
      fallbackUser = user;
      return user;
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    }
  }

  static const String _serverClientId =
      '80143681231-qdjv369q92chcon90jkipdi51a2n6icv.apps.googleusercontent.com';
  static bool _googleInitialized = false;

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: _serverClientId,
    );
    _googleInitialized = true;
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();
      // Sign out any stale Google session before prompting so account picker
      // works cleanly on the first tap without a double prompt or stale state.
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}

      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthFailure('Could not obtain Google ID token.');
      }

      final credential = fb.GoogleAuthProvider.credential(
        idToken: idToken,
      );
      final cred = await _firebaseAuth.signInWithCredential(credential);
      if (cred.user == null) {
        throw const NotFoundFailure('Google Sign-In failed');
      }
      final user = _mapFirebaseUser(cred.user!);
      fallbackUser = user;
      return user;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthFailure('Google Sign-In was cancelled.');
      }
      throw AuthFailure(e.description ?? 'Google Sign-In failed.');
    } on fb.FirebaseAuthException catch (e) {
      throw _mapFirebaseAuthException(e);
    } catch (e) {
      if (e is AppFailure) rethrow;
      throw AuthFailure(e.toString());
    }
  }

  @override
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
  }) async {
    try {
      await _firebaseAuth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (fb.PhoneAuthCredential credential) async {
          await _firebaseAuth.signInWithCredential(credential);
        },
        verificationFailed: (fb.FirebaseAuthException e) {
          onFailed(e.message ?? 'Phone verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
        timeout: const Duration(seconds: 60),
      );
    } on fb.FirebaseAuthException catch (e) {
      onFailed(e.message ?? 'Failed to send SMS code');
    } catch (e) {
      onFailed(e.toString());
    }
  }

  @override
  Future<AuthUser> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final cred = await _firebaseAuth.signInWithCredential(credential);
      if (cred.user == null) {
        throw const NotFoundFailure('Phone authentication failed');
      }
      final user = _mapFirebaseUser(cred.user!);
      fallbackUser = user;
      return user;
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
    fallbackUser = null;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
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
