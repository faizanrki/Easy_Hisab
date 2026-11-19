import '../../../core/domain/app_failure.dart';
import '../../../core/domain/phone_number.dart';

enum BusinessVerification { unverified, pending, verified }

/// A shop (tenant). Every customer, product, sale and payment belongs to one.
final class Shop {
  const Shop({
    required this.id,
    required this.details,
    required this.createdAt,
    required this.updatedAt,
    this.ownerUid,
    this.businessVerification = BusinessVerification.unverified,
  });

  final String id;
  final ShopDetails details;

  /// Firebase UID of the owner; null while the app is used before sign-in.
  final String? ownerUid;

  /// Verified login != verified business. MVP shops stay `unverified`.
  final BusinessVerification businessVerification;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get name => details.name;
  String? get address => details.address;
  String? get contactPhone => details.contactPhone;

  Shop copyWith({ShopDetails? details, DateTime? updatedAt}) => Shop(
        id: id,
        details: details ?? this.details,
        ownerUid: ownerUid,
        businessVerification: businessVerification,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Validated, normalized, user-editable shop information.
final class ShopDetails {
  const ShopDetails._(this.name, this.address, this.contactPhone);

  static const int maxNameLength = 80;
  static const int maxAddressLength = 200;

  final String name;
  final String? address;
  final String? contactPhone;

  /// Trims and validates input. Throws [ValidationFailure] on invalid data.
  factory ShopDetails.create({
    required String name,
    String? address,
    String? contactPhone,
  }) {
    final nameError = validateName(name);
    if (nameError != null) throw ValidationFailure(nameError);
    final addressError = validateAddress(address);
    if (addressError != null) throw ValidationFailure(addressError);
    final trimmedAddress = address?.trim() ?? '';
    return ShopDetails._(
      name.trim().replaceAll(RegExp(r'\s+'), ' '),
      trimmedAddress.isEmpty ? null : trimmedAddress,
      PhoneNumber.normalize(contactPhone),
    );
  }

  /// Rebuilds already-stored data without re-validating.
  const ShopDetails.fromStorage({
    required this.name,
    this.address,
    this.contactPhone,
  });

  static String? validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Shop name is required';
    if (v.length < 2) return 'Shop name is too short';
    if (v.length > maxNameLength) {
      return 'Shop name must be at most $maxNameLength characters';
    }
    return null;
  }

  static String? validateAddress(String? value) {
    if ((value?.trim().length ?? 0) > maxAddressLength) {
      return 'Address must be at most $maxAddressLength characters';
    }
    return null;
  }
}
