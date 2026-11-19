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

final class SendPhoneOtp {
  const SendPhoneOtp(this._auth);

  final AuthServicePort _auth;

  Future<void> execute({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String error) onFailed,
  }) async {
    final cleanPhone = phoneNumber.replaceAll(' ', '').trim();
    if (cleanPhone.isEmpty || cleanPhone.length < 10) {
      onFailed('Please enter a valid phone number (e.g. +92 300 1234567)');
      return;
    }
    await _auth.sendPhoneOtp(
      phoneNumber: cleanPhone,
      onCodeSent: onCodeSent,
      onFailed: onFailed,
    );
  }
}

final class VerifyPhoneOtp {
  const VerifyPhoneOtp(this._auth);

  final AuthServicePort _auth;

  Future<AuthUser> execute({
    required String verificationId,
    required String smsCode,
  }) async {
    final cleanCode = smsCode.replaceAll(' ', '').trim();
    if (cleanCode.length != 6) {
      throw const ValidationFailure(
          'Please enter the 6-digit verification code.');
    }
    return _auth.verifyPhoneOtp(
      verificationId: verificationId,
      smsCode: cleanCode,
    );
  }
}
