import '../../../core/domain/money.dart';

/// Summary of a shop where a customer has an account and balance.
class LinkedShopSummary {
  const LinkedShopSummary({
    required this.shopId,
    required this.shopName,
    this.shopPhone,
    this.shopAddress,
    required this.customerId,
    required this.customerName,
    required this.balance,
    required this.linkedAt,
  });

  final String shopId;
  final String shopName;
  final String? shopPhone;
  final String? shopAddress;
  final String customerId;
  final String customerName;
  final Money balance;
  final DateTime linkedAt;
}

/// A read-only ledger transaction entry for the customer.
class CustomerLedgerItem {
  const CustomerLedgerItem({
    required this.id,
    required this.shopId,
    required this.date,
    required this.type, // 'sale' or 'payment'
    required this.amount,
    required this.description,
    this.receiptNumber,
    this.saleId,
  });

  final String id;
  final String shopId;
  final DateTime date;
  final String type;
  final Money amount;
  final String description;
  final String? receiptNumber;
  final String? saleId;

  bool get isSale => type == 'sale';
  bool get isPayment => type == 'payment';
}
