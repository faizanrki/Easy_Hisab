import 'shop.dart';

/// Storage port for shops. Implemented by the SQLite adapter (and fakes in
/// tests). No SQL or Firebase types leak through this interface.
abstract interface class ShopRepository {
  /// Saves a new shop and makes it the active shop, atomically.
  Future<void> createAndActivate(Shop shop);

  /// Persists edited details of an existing shop.
  Future<void> update(Shop shop);

  Future<Shop?> findById(String shopId);

  /// ID of the shop selected on this device, if any.
  Future<String?> activeShopId();
}
