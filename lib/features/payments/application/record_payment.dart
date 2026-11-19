import '../../../core/contracts/customer_lookup_port.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/clock.dart';
import '../../../core/domain/entity_id.dart';
import '../../../core/domain/money.dart';
import '../domain/payment.dart';
import '../domain/payment_repository.dart';

final class RecordPaymentCommand {
  const RecordPaymentCommand({
    required this.shopId,
    required this.customerId,
    required this.amount,
    this.method = PaymentMethod.cash,
    this.note,
    this.createdAt,
  });

  final String shopId;
  final String customerId;
  final Money amount;
  final PaymentMethod method;
  final String? note;
  final DateTime? createdAt;
}

final class RecordPayment {
  const RecordPayment(
    this._payments,
    this._customers,
    this._ids,
    this._clock,
  );

  final PaymentRepository _payments;
  final CustomerLookupPort _customers;
  final IdGenerator _ids;
  final Clock _clock;

  Future<Payment> execute(RecordPaymentCommand cmd) async {
    Payment.validate(
      shopId: cmd.shopId,
      customerId: cmd.customerId,
      amount: cmd.amount,
    );

    // Verify customer exists and belongs to active shop
    final customer = await _customers.findForShop(
      shopId: cmd.shopId,
      customerId: cmd.customerId,
    );
    if (customer == null) {
      throw const NotFoundFailure('Customer not found in this shop');
    }

    final now = cmd.createdAt ?? _clock.nowUtc();
    final payment = Payment(
      id: _ids.newId(),
      shopId: cmd.shopId,
      customerId: cmd.customerId,
      amount: cmd.amount,
      method: cmd.method,
      note: cmd.note?.trim().isNotEmpty == true ? cmd.note!.trim() : null,
      createdAt: now,
      status: PaymentStatus.posted,
      syncStatus: PaymentSyncStatus.pending,
    );

    await _payments.recordPayment(payment);
    return payment;
  }
}
