import '../../../core/domain/app_failure.dart';
import '../../../core/domain/clock.dart';
import '../domain/payment_repository.dart';

final class ReversePayment {
  const ReversePayment(this._payments, this._clock);

  final PaymentRepository _payments;
  final Clock _clock;

  Future<void> execute({
    required String shopId,
    required String paymentId,
    required String reason,
  }) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw const ValidationFailure('A reason is required to reverse a payment');
    }

    final existing = await _payments.findById(shopId, paymentId);
    if (existing == null) {
      throw const NotFoundFailure('Payment record not found');
    }
    if (existing.isReversed) {
      throw const ValidationFailure('This payment is already reversed');
    }

    await _payments.reversePayment(
      shopId,
      paymentId,
      reason: cleanReason,
      reversedAt: _clock.nowUtc(),
    );
  }
}
