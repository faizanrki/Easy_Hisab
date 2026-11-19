import '../../../core/domain/money.dart';
import 'payment.dart';

/// Storage port for Payments, Allocations, and Customer Ledger calculations.
abstract interface class PaymentRepository {
  /// Atomically records a payment, its FIFO allocations across unpaid credit sales,
  /// outbox queue entry, and an append-only audit trail.
  Future<void> recordPayment(Payment payment);

  Future<Payment?> findById(String shopId, String paymentId);

  Future<List<Payment>> listCustomerPayments(
    String shopId,
    String customerId, {
    int limit = 100,
  });

  Future<List<Payment>> listShopPayments(
    String shopId, {
    int limit = 50,
  });

  /// Performs an auditable reversal of a payment record.
  Future<void> reversePayment(
    String shopId,
    String paymentId, {
    required String reason,
    required DateTime reversedAt,
  });

  /// Computes the net outstanding udhar for a customer:
  /// sum(posted credit sales) - sum(posted payments)
  Future<Money> getCustomerBalance(String shopId, String customerId);

  /// Computes the complete chronological khata ledger timeline for a customer.
  Future<List<LedgerEntry>> getCustomerLedger(String shopId, String customerId);
}
