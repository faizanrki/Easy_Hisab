import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contracts/auth_context_port.dart';
import '../application/auth_use_cases.dart';
import '../application/register_with_email.dart';
import '../application/sign_in_with_email.dart';
import '../data/in_memory_auth_service.dart';
import '../domain/auth_service_port.dart';
import '../domain/auth_user.dart';

/// The active auth service instance.
/// Defaults to [InMemoryAuthService] so the app and tests work immediately offline.
/// Can be overridden with [FirebaseAuthService] when Firebase is configured.
final authServiceProvider = Provider<AuthServicePort>((ref) {
  return InMemoryAuthService();
});

/// Watches authentication state changes (stream of AuthUser?).
final authSessionProvider = StreamProvider<AuthUser?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges();
});

/// Adapts the active user into an [AuthContextPort] for the rest of the application.
final authContextProvider = Provider<AuthContextPort>((ref) {
  final session = ref.watch(authSessionProvider);
  return session.when(
    data: (user) {
      if (user == null) {
        return const LocalOnlyAuthContext();
      }
      return AuthenticatedAuthContext(
        currentUid: user.uid,
        email: user.email,
        displayName: user.displayName,
        isEmailVerified: user.isEmailVerified,
      );
    },
    loading: () => const LocalOnlyAuthContext(),
    error: (_, _) => const LocalOnlyAuthContext(),
  );
});

final signInWithEmailUseCaseProvider = Provider<SignInWithEmail>((ref) {
  final authService = ref.watch(authServiceProvider);
  return SignInWithEmail(authService);
});

final registerWithEmailUseCaseProvider = Provider<RegisterWithEmail>((ref) {
  final authService = ref.watch(authServiceProvider);
  return RegisterWithEmail(authService);
});

final signOutUseCaseProvider = Provider<SignOutUser>((ref) {
  final authService = ref.watch(authServiceProvider);
  return SignOutUser(authService);
});

final resetPasswordUseCaseProvider = Provider<SendPasswordReset>((ref) {
  final authService = ref.watch(authServiceProvider);
  return SendPasswordReset(authService);
});

final sendVerificationEmailUseCaseProvider = Provider<SendEmailVerification>((ref) {
  final authService = ref.watch(authServiceProvider);
  return SendEmailVerification(authService);
});
