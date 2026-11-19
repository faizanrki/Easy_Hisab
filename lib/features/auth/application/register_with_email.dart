import '../../../core/domain/app_failure.dart';
import '../domain/auth_service_port.dart';
import '../domain/auth_user.dart';

final class RegisterWithEmail {
  const RegisterWithEmail(this._auth);

  final AuthServicePort _auth;

  Future<AuthUser> execute(
    String email,
    String password, {
    String? displayName,
  }) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const ValidationFailure('Please enter a valid email address');
    }
    if (password.length < 6) {
      throw const ValidationFailure('Password must be at least 6 characters');
    }

    return _auth.registerWithEmail(
      cleanEmail,
      password,
      displayName: displayName?.trim(),
    );
  }
}
