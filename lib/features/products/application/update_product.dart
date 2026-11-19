import '../../../core/domain/app_failure.dart';
import '../../../core/domain/clock.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

final class UpdateProduct {
  const UpdateProduct(this._products, this._clock);

  final ProductRepository _products;
  final Clock _clock;

  Future<Product> execute({
    required String shopId,
    required String productId,
    required ProductDetails details,
  }) async {
    final existing = await _products.findById(shopId, productId);
    if (existing == null) {
      throw const NotFoundFailure('Product not found');
    }

    final updated = existing.copyWith(
      details: details,
      updatedAt: _clock.nowUtc(),
    );

    await _products.update(updated);
    return updated;
  }
}
