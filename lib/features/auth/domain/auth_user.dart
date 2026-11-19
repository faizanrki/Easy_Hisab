enum AuthRole {
  shopkeeper,
  customer;

  String get displayName => switch (this) {
        shopkeeper => 'Shopkeeper (Dukaandar)',
        customer => 'Customer (Grahak)',
      };
}

/// An authenticated user identity across Firebase and the local app.
final class AuthUser {
  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.isEmailVerified = false,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final bool isEmailVerified;

  AuthUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? phoneNumber,
    bool? isEmailVerified,
  }) =>
      AuthUser(
        uid: uid ?? this.uid,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      );
}
