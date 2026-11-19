import '../domain/product.dart';
import '../domain/product_repository.dart';

final class GetProducts {
  const GetProducts(this._products);

  final ProductRepository _products;

  Future<List<Product>> execute({
    required String shopId,
    String? searchQuery,
    bool includeArchived = false,
  }) {
    return _products.listForShop(
      shopId,
      searchQuery: searchQuery,
      includeArchived: includeArchived,
    );
  }

  Future<Product?> getById({
    required String shopId,
    required String productId,
  }) {
    return _products.findById(shopId, productId);
  }
}
