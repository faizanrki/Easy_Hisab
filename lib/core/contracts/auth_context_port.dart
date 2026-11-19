/// Identity of the signed-in user, as seen by business modules.
///
/// Business modules depend on this port, never on FirebaseAuth directly.
abstract interface class AuthContextPort {
  String? get currentUid;
  bool get isAuthenticated => currentUid != null;
  String? get email;
  String? get displayName;
  bool get isEmailVerified;
}

/// Fallback context for anonymous local offline operation.
final class LocalOnlyAuthContext implements AuthContextPort {
  const LocalOnlyAuthContext();

  @override
  String? get currentUid => null;

  @override
  bool get isAuthenticated => false;

  @override
  String? get email => null;

  @override
  String? get displayName => 'Local Shopkeeper';

  @override
  bool get isEmailVerified => false;
}

/// Context representing an authenticated user session.
final class AuthenticatedAuthContext implements AuthContextPort {
  const AuthenticatedAuthContext({
    required this.currentUid,
    this.email,
    this.displayName,
    this.isEmailVerified = false,
  });

  @override
  final String currentUid;

  @override
  bool get isAuthenticated => true;

  @override
  final String? email;

  @override
  final String? displayName;

  @override
  final bool isEmailVerified;
}
