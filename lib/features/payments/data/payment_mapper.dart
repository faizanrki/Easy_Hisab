import '../../../core/domain/money.dart';
import '../domain/payment.dart';

abstract final class PaymentMapper {
  static Map<String, Object?> paymentToRow(Payment payment) {
    return {
      'id': payment.id,
      'shop_id': payment.shopId,
      'customer_id': payment.customerId,
      'amount_paisa': payment.amount.paisa,
      'method': payment.method.name,
      'sale_id': payment.saleId,
      'status': payment.status.name,
      'reverses_payment_id': payment.reversesPaymentId,
      'note': payment.note,
      'created_at': payment.createdAt.millisecondsSinceEpoch,
      'sync_status': payment.syncStatus.name,
    };
  }

  static Payment paymentFromRow(
    Map<String, Object?> row, [
    List<PaymentAllocation> allocations = const [],
  ]) {
    return Payment(
      id: row['id']! as String,
      shopId: row['shop_id']! as String,
      customerId: row['customer_id']! as String,
      amount: Money.paisa(row['amount_paisa']! as int),
      method: PaymentMethod.fromString(row['method'] as String?),
      status: (row['status'] as String? ?? 'posted') == 'reversed'
          ? PaymentStatus.reversed
          : PaymentStatus.posted,
      saleId: row['sale_id'] as String?,
      reversesPaymentId: row['reverses_payment_id'] as String?,
      note: row['note'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at']! as int,
        isUtc: true,
      ),
      syncStatus: switch (row['sync_status'] as String? ?? 'pending') {
        'accepted' => PaymentSyncStatus.accepted,
        'rejected' => PaymentSyncStatus.rejected,
        _ => PaymentSyncStatus.pending,
      },
      allocations: allocations,
    );
  }

  static Map<String, Object?> allocationToRow(PaymentAllocation allocation) {
    return {
      'id': allocation.id,
      'payment_id': allocation.paymentId,
      'sale_id': allocation.saleId,
      'allocated_paisa': allocation.allocatedAmount.paisa,
    };
  }

  static PaymentAllocation allocationFromRow(Map<String, Object?> row) {
    return PaymentAllocation(
      id: row['id']! as String,
      paymentId: row['payment_id']! as String,
      saleId: row['sale_id']! as String,
      allocatedAmount: Money.paisa(row['allocated_paisa']! as int),
    );
  }
}
