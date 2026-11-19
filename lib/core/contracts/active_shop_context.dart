/// What other features may know about the currently selected shop.
///
/// Sales, customers, products, etc. receive this - never the Shop screens,
/// the Shop entity internals or the shops SQL table.
final class ActiveShopContext {
  const ActiveShopContext({required this.shopId, required this.shopName});

  final String shopId;
  final String shopName;
}
