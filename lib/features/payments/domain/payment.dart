import '../../../core/domain/app_failure.dart';
import '../../../core/domain/money.dart';

enum PaymentStatus { posted, reversed }

enum PaymentSyncStatus { pending, accepted, rejected }

enum PaymentMethod {
  cash,
  easypaisa,
  jazzcash,
  bankTransfer,
  other;

  String get displayName => switch (this) {
        cash => 'Cash',
        easypaisa => 'EasyPaisa',
        jazzcash => 'JazzCash',
        bankTransfer => 'Bank Transfer',
        other => 'Other',
      };

  static PaymentMethod fromString(String? val) {
    if (val == null) return cash;
    return switch (val.toLowerCase()) {
      'cash' => cash,
      'easypaisa' => easypaisa,
      'jazzcash' => jazzcash,
      'bank' || 'bank_transfer' || 'banktransfer' => bankTransfer,
      _ => other,
    };
  }
}

/// A payment allocation linking a payment to a specific sale (FIFO).
final class PaymentAllocation {
  const PaymentAllocation({
    required this.id,
    required this.paymentId,
    required this.saleId,
    required this.allocatedAmount,
  });

  final String id;
  final String paymentId;
  final String saleId;
  final Money allocatedAmount;
}

/// A posted or reversed financial repayment record.
final class Payment {
  const Payment({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.amount,
    required this.createdAt,
    this.method = PaymentMethod.cash,
    this.status = PaymentStatus.posted,
    this.saleId,
    this.reversesPaymentId,
    this.note,
    this.syncStatus = PaymentSyncStatus.pending,
    this.allocations = const [],
  });

  final String id;
  final String shopId;
  final String customerId;
  final Money amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? saleId;
  final String? reversesPaymentId;
  final String? note;
  final DateTime createdAt;
  final PaymentSyncStatus syncStatus;
  final List<PaymentAllocation> allocations;

  bool get isPosted => status == PaymentStatus.posted;
  bool get isReversed => status == PaymentStatus.reversed;

  static void validate({
    required String shopId,
    required String customerId,
    required Money amount,
  }) {
    if (shopId.isEmpty) throw const ValidationFailure('Shop ID is required');
    if (customerId.isEmpty) {
      throw const ValidationFailure('Customer must be selected for payment');
    }
    if (amount.paisa <= 0) {
      throw const ValidationFailure('Payment amount must be greater than zero');
    }
  }
}

enum LedgerEntryType {
  sale,
  payment,
}

/// A unified chronological entry in a customer's khata ledger.
final class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.date,
    required this.type,
    required this.description,
    required this.referenceNo,
    required this.debit,
    required this.credit,
    required this.runningBalance,
    required this.isReversed,
  });

  final String id;
  final DateTime date;
  final LedgerEntryType type;
  final String description;
  final String referenceNo;

  /// Money owed by customer (e.g. credit bill amount)
  final Money debit;

  /// Money received from customer (e.g. payment amount)
  final Money credit;

  /// Net balance owed after this entry
  final Money runningBalance;

  final bool isReversed;
}
