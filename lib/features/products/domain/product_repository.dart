import 'product.dart';

/// Storage port for Product entities.
abstract interface class ProductRepository {
  Future<void> save(Product product);

  Future<void> update(Product product);

  Future<Product?> findById(String shopId, String productId);

  Future<List<Product>> listForShop(
    String shopId, {
    String? searchQuery,
    bool includeArchived = false,
  });

  Future<void> setArchivedStatus(
    String shopId,
    String productId, {
    required bool archived,
    required DateTime timestamp,
  });
}
