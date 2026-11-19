import '../../../core/domain/app_failure.dart';
import '../../../core/domain/clock.dart';
import '../domain/sale_repository.dart';

final class ReverseSale {
  const ReverseSale(this._sales, this._clock);

  final SaleRepository _sales;
  final Clock _clock;

  Future<void> execute({
    required String shopId,
    required String saleId,
    required String reason,
  }) async {
    final existing = await _sales.findById(shopId, saleId);
    if (existing == null) {
      throw const NotFoundFailure('Sale record not found');
    }
    if (existing.isReversed) {
      throw const ValidationFailure('This sale has already been reversed');
    }

    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw const ValidationFailure('A reason is required to reverse a bill');
    }

    await _sales.reverseSale(
      shopId,
      saleId,
      reason: cleanReason,
      reversedAt: _clock.nowUtc(),
    );
  }
}
