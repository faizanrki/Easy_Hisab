import '../domain/money.dart';

/// Lightweight, immutable product snapshot at the time of sale.
///
/// When a bill is created (Module 05), the sale line item copies these
/// snapshot values. Later price edits in the catalog never change old sales.
final class ProductSnapshot {
  const ProductSnapshot({
    required this.id,
    required this.shopId,
    required this.name,
    required this.unit,
    required this.unitPrice,
    this.isArchived = false,
  });

  final String id;
  final String shopId;
  final String name;
  final String unit;
  final Money unitPrice;
  final bool isArchived;
}

/// Domain-facing port enabling the billing & sales module to look up
/// products and their current sale prices.
abstract interface class ProductLookupPort {
  Future<ProductSnapshot?> findForShop({
    required String shopId,
    required String productId,
  });
}
