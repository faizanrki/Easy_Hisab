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
