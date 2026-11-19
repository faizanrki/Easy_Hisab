import '../../../core/domain/app_failure.dart';
import '../../../core/domain/money.dart';

/// Supported default grocery units commonly used in local Pakistani shops.
abstract final class StandardGroceryUnits {
  static const kg = 'kg';
  static const gram = 'g';
  static const liter = 'liter';
  static const packet = 'packet';
  static const piece = 'piece';
  static const dozen = 'dozen';
  static const sack = 'sack';
  static const carton = 'carton';

  static const List<String> all = [
    kg,
    packet,
    piece,
    liter,
    dozen,
    gram,
    sack,
    carton,
  ];
}

/// A grocery product in a shop catalog.
final class Product {
  const Product({
    required this.id,
    required this.shopId,
    required this.details,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  final String id;
  final String shopId;
  final ProductDetails details;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get name => details.name;
  String get nameSearch => details.nameSearch;
  String get unit => details.unit;
  Money get unitPrice => details.unitPrice;
  bool get isArchived => archivedAt != null;

  Product copyWith({
    ProductDetails? details,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    DateTime? updatedAt,
  }) =>
      Product(
        id: id,
        shopId: shopId,
        details: details ?? this.details,
        archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Validated product details.
final class ProductDetails {
  const ProductDetails._({
    required this.name,
    required this.nameSearch,
    required this.unit,
    required this.unitPrice,
  });

  static const int maxNameLength = 80;
  static const int maxUnitLength = 20;

  final String name;
  final String nameSearch;
  final String unit;
  final Money unitPrice;

  factory ProductDetails.create({
    required String name,
    required String unit,
    required Money unitPrice,
  }) {
    final nameError = validateName(name);
    if (nameError != null) throw ValidationFailure(nameError);

    final unitError = validateUnit(unit);
    if (unitError != null) throw ValidationFailure(unitError);

    if (unitPrice.isNegative) {
      throw const ValidationFailure('Unit price cannot be negative');
    }

    final cleanName = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    final cleanUnit = unit.trim().toLowerCase();

    return ProductDetails._(
      name: cleanName,
      nameSearch: cleanName.toLowerCase(),
      unit: cleanUnit,
      unitPrice: unitPrice,
    );
  }

  const ProductDetails.fromStorage({
    required this.name,
    required this.nameSearch,
    required this.unit,
    required this.unitPrice,
  });

  static String? validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Product name is required';
    if (v.length < 2) return 'Product name is too short';
    if (v.length > maxNameLength) {
      return 'Product name must be at most $maxNameLength characters';
    }
    return null;
  }

  static String? validateUnit(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Unit is required (e.g. kg, packet, piece)';
    if (v.length > maxUnitLength) {
      return 'Unit must be at most $maxUnitLength characters';
    }
    return null;
  }
}
