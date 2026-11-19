import '../../../core/domain/app_failure.dart';
import '../../../core/domain/clock.dart';
import '../domain/product_repository.dart';

final class ArchiveProduct {
  const ArchiveProduct(this._products, this._clock);

  final ProductRepository _products;
  final Clock _clock;

  Future<void> execute({
    required String shopId,
    required String productId,
    required bool archive,
  }) async {
    final existing = await _products.findById(shopId, productId);
    if (existing == null) {
      throw const NotFoundFailure('Product not found');
    }

    await _products.setArchivedStatus(
      shopId,
      productId,
      archived: archive,
      timestamp: _clock.nowUtc(),
    );
  }
}
