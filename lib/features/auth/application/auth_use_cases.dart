import '../../../core/domain/app_failure.dart';
import '../domain/auth_service_port.dart';
import '../domain/auth_user.dart';

final class SignInWithGoogle {
  const SignInWithGoogle(this._auth);

  final AuthServicePort _auth;

  Future<AuthUser> execute() => _auth.signInWithGoogle();
}

final class SendPasswordReset {
  const SendPasswordReset(this._auth);

  final AuthServicePort _auth;

  Future<void> execute(String email) async {
    final cleanEmail = email.trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const ValidationFailure('Please enter a valid email address');
    }
    await _auth.sendPasswordReset(cleanEmail);
  }
}

final class SignOutUser {
  const SignOutUser(this._auth);

  final AuthServicePort _auth;

  Future<void> execute() => _auth.signOut();
}

final class SendEmailVerification {
  const SendEmailVerification(this._auth);

  final AuthServicePort _auth;

  Future<void> execute() => _auth.sendEmailVerification();
}
