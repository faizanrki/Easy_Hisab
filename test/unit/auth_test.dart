import 'package:flutter_test/flutter_test.dart';
import 'package:easy_hisab/core/domain/app_failure.dart';
import 'package:easy_hisab/features/auth/application/auth_use_cases.dart';
import 'package:easy_hisab/features/auth/application/register_with_email.dart';
import 'package:easy_hisab/features/auth/application/sign_in_with_email.dart';
import 'package:easy_hisab/features/auth/data/in_memory_auth_service.dart';

void main() {
  group('Module 08: Authentication Unit Tests', () {
    late InMemoryAuthService authService;
    late RegisterWithEmail registerUseCase;
    late SignInWithEmail signInUseCase;
    late SignOutUser signOutUseCase;
    late SendPasswordReset resetPasswordUseCase;

    setUp(() {
      authService = InMemoryAuthService();
      registerUseCase = RegisterWithEmail(authService);
      signInUseCase = SignInWithEmail(authService);
      signOutUseCase = SignOutUser(authService);
      resetPasswordUseCase = SendPasswordReset(authService);
    });

    test('register with email succeeds with valid inputs', () async {
      final user = await registerUseCase.execute(
        'shopkeeper@easyhisab.pk',
        'password123',
        displayName: 'Tariq Kiryana Store',
      );

      expect(user.email, 'shopkeeper@easyhisab.pk');
      expect(user.displayName, 'Tariq Kiryana Store');
      expect(authService.currentUser?.uid, user.uid);
    });

    test('register with invalid email throws ValidationFailure', () async {
      expect(
        () => registerUseCase.execute(
          'invalid-email',
          'password123',
          displayName: 'Test',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('register with short password throws ValidationFailure', () async {
      expect(
        () => registerUseCase.execute(
          'valid@example.com',
          '123',
          displayName: 'Test',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('register duplicate email throws ValidationFailure', () async {
      await registerUseCase.execute(
        'dup@example.com',
        'password123',
        displayName: 'First',
      );

      expect(
        () => registerUseCase.execute(
          'dup@example.com',
          'password456',
          displayName: 'Second',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('sign in succeeds with correct credentials', () async {
      await registerUseCase.execute(
        'tariq@example.com',
        'secretPassword',
        displayName: 'Tariq',
      );
      await signOutUseCase.execute();
      expect(authService.currentUser, isNull);

      final user = await signInUseCase.execute(
        'tariq@example.com',
        'secretPassword',
      );

      expect(user.email, 'tariq@example.com');
      expect(authService.currentUser?.uid, user.uid);
    });

    test('sign in with wrong password throws ValidationFailure', () async {
      await registerUseCase.execute(
        'tariq@example.com',
        'secretPassword',
        displayName: 'Tariq',
      );
      await signOutUseCase.execute();

      expect(
        () => signInUseCase.execute(
          'tariq@example.com',
          'wrongPassword',
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('reset password succeeds for registered email', () async {
      await registerUseCase.execute(
        'tariq@example.com',
        'secretPassword',
        displayName: 'Tariq',
      );

      await expectLater(
        resetPasswordUseCase.execute('tariq@example.com'),
        completes,
      );
    });

    test('reset password for non-existent email throws ValidationFailure', () async {
      expect(
        () => resetPasswordUseCase.execute('notfound@example.com'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('Google sign-in signs in demo/google user', () async {
      final user = await authService.signInWithGoogle();
      expect(user.email, contains('@gmail.com'));
      expect(authService.currentUser, isNotNull);
    });
  });
}
