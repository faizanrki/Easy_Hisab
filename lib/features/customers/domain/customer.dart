import '../../../core/domain/app_failure.dart';
import '../../../core/domain/phone_number.dart';

/// A ledger customer belonging to a specific shop.
///
/// Customers can be created completely offline by the shopkeeper.
/// They do NOT need an account or password to be entered into the khata.
final class Customer {
  const Customer({
    required this.id,
    required this.shopId,
    required this.details,
    required this.createdAt,
    required this.updatedAt,
    this.linkedAuthUid,
    this.archivedAt,
  });

  final String id;
  final String shopId;
  final CustomerDetails details;

  /// Nullable Firebase UID; bound only after customer links via approved invite (Module 09).
  final String? linkedAuthUid;

  /// Non-null if archived; archived customers retain full financial history.
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get name => details.name;
  String get nameSearch => details.nameSearch;
  String? get phone => details.phone;
  String? get email => details.email;
  bool get isArchived => archivedAt != null;

  Customer copyWith({
    CustomerDetails? details,
    String? linkedAuthUid,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    DateTime? updatedAt,
  }) =>
      Customer(
        id: id,
        shopId: shopId,
        details: details ?? this.details,
        linkedAuthUid: linkedAuthUid ?? this.linkedAuthUid,
        archivedAt:
            clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// User-provided customer contact details with validation and normalized search key.
final class CustomerDetails {
  const CustomerDetails._({
    required this.name,
    required this.nameSearch,
    this.phone,
    this.email,
  });

  static const int maxNameLength = 60;
  static const int maxEmailLength = 100;

  final String name;
  final String nameSearch;
  final String? phone;
  final String? email;

  factory CustomerDetails.create({
    required String name,
    String? phone,
    String? email,
  }) {
    final nameError = validateName(name);
    if (nameError != null) throw ValidationFailure(nameError);

    final emailError = validateEmail(email);
    if (emailError != null) throw ValidationFailure(emailError);

    final cleanName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final cleanEmail = email?.trim();

    return CustomerDetails._(
      name: cleanName,
      nameSearch: cleanName.toLowerCase(),
      phone: PhoneNumber.normalize(phone),
      email: (cleanEmail == null || cleanEmail.isEmpty) ? null : cleanEmail,
    );
  }

  const CustomerDetails.fromStorage({
    required this.name,
    required this.nameSearch,
    this.phone,
    this.email,
  });

  static String? validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Customer name is required';
    if (v.length < 2) return 'Customer name is too short';
    if (v.length > maxNameLength) {
      return 'Customer name must be at most $maxNameLength characters';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return null;
    if (v.length > maxEmailLength) {
      return 'Email must be at most $maxEmailLength characters';
    }
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$');
    if (!emailRegex.hasMatch(v)) {
      return 'Enter a valid email address';
    }
    return null;
  }
}
