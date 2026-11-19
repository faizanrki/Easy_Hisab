import '../../../core/domain/clock.dart';
import '../../../core/domain/entity_id.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

final class CreateProduct {
  const CreateProduct(this._products, this._ids, this._clock);

  final ProductRepository _products;
  final IdGenerator _ids;
  final Clock _clock;

  Future<Product> execute({
    required String shopId,
    required ProductDetails details,
  }) async {
    final now = _clock.nowUtc();
    final product = Product(
      id: _ids.newId(),
      shopId: shopId,
      details: details,
      createdAt: now,
      updatedAt: now,
    );
    await _products.save(product);
    return product;
  }
}
