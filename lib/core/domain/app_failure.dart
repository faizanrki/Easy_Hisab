/// Base type for expected, user-explainable failures.
///
/// Use cases throw/return these; the UI turns [message] into readable errors.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Input broke a business or format rule (bad amount, empty name, ...).
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

/// A requested record does not exist (or is not visible in this shop).
final class NotFoundFailure extends AppFailure {
  const NotFoundFailure(super.message);
}

/// The current user is not allowed to perform the action.
final class PermissionFailure extends AppFailure {
  const PermissionFailure(super.message);
}

/// Authentication or credential failure.
final class AuthFailure extends AppFailure {
  const AuthFailure(super.message);
}

/// Local storage failed (disk, migration, constraint, ...).
final class StorageFailure extends AppFailure {
  const StorageFailure(super.message, [this.cause]);
  final Object? cause;
}
