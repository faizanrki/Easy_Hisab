/// Lightweight summary for external consumer modules (e.g. Sales, Payments)
/// to verify customer existence and basic contact details without depending
/// on Customer presentation, internal entity structure, or database details.
final class CustomerSummary {
  const CustomerSummary({
    required this.id,
    required this.shopId,
    required this.name,
    this.phone,
    this.isArchived = false,
  });

  final String id;
  final String shopId;
  final String name;
  final String? phone;
  final bool isArchived;
}

/// Domain-facing port enabling other modules to look up customer records
/// scoped strictly to a shop.
abstract interface class CustomerLookupPort {
  Future<CustomerSummary?> findForShop({
    required String shopId,
    required String customerId,
  });
}
