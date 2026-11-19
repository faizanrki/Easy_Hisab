import 'dart:async';
import '../../../core/domain/app_failure.dart';
import '../domain/auth_service_port.dart';
import '../domain/auth_user.dart';

final class InMemoryAuthService implements AuthServicePort {
  InMemoryAuthService({AuthUser? initialUser}) : _currentUser = initialUser {
    if (initialUser != null) {
      _users[initialUser.email ?? ''] = _StoredAccount(
        user: initialUser,
        password: 'password123',
      );
    }
  }

  final Map<String, _StoredAccount> _users = {};
  final StreamController<AuthUser?> _controller =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<AuthUser> signInWithEmail(String email, String password) async {
    final account = _users[email.toLowerCase()];
    if (account == null || account.password != password) {
      throw const ValidationFailure('Invalid email or password.');
    }
    _currentUser = account.user;
    _controller.add(_currentUser);
    return account.user;
  }

  @override
  Future<AuthUser> registerWithEmail(
    String email,
    String password, {
    String? displayName,
  }) async {
    final key = email.toLowerCase();
    if (_users.containsKey(key)) {
      throw const ValidationFailure('An account with this email already exists.');
    }

    final user = AuthUser(
      uid: 'user_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: displayName ?? email.split('@').first,
      isEmailVerified: false,
    );

    _users[key] = _StoredAccount(user: user, password: password);
    _currentUser = user;
    _controller.add(_currentUser);
    return user;
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final user = AuthUser(
      uid: 'google_user_${DateTime.now().millisecondsSinceEpoch}',
      email: 'test.shopkeeper@gmail.com',
      displayName: 'Google Shopkeeper',
      isEmailVerified: true,
    );
    _currentUser = user;
    _controller.add(_currentUser);
    return user;
  }

  @override
  Future<void> sendEmailVerification() async {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(isEmailVerified: true);
      _controller.add(_currentUser);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (!_users.containsKey(email.toLowerCase())) {
      throw const ValidationFailure('No user found with this email.');
    }
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

final class _StoredAccount {
  _StoredAccount({required this.user, required this.password});
  final AuthUser user;
  final String password;
}
