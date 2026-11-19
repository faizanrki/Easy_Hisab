import 'auth_user.dart';

abstract interface class AuthServicePort {
  /// Signs in using email and password credentials.
  Future<AuthUser> signInWithEmail(String email, String password);

  /// Registers a new user account with email and password.
  Future<AuthUser> registerWithEmail(
    String email,
    String password, {
    String? displayName,
  });

  /// Signs in using Google OAuth provider.
  Future<AuthUser> signInWithGoogle();

  /// Triggers SMS OTP to the given phone number in E.164 format (e.g. +923001234567).
  Future<void> sendPhoneOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
  });

  /// Verifies the 6-digit SMS code against the verification ID.
  Future<AuthUser> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
  });

  /// Sends email verification link to current user.
  Future<void> sendEmailVerification();

  /// Sends password recovery link to the specified email.
  Future<void> sendPasswordReset(String email);

  /// Signs out the currently authenticated user.
  Future<void> signOut();

  /// Current user or null if anonymous/signed out.
  AuthUser? get currentUser;

  /// Stream of authentication state changes.
  Stream<AuthUser?> authStateChanges();
}
