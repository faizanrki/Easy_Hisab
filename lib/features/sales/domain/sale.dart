import '../../../core/domain/app_failure.dart';
import '../../../core/domain/money.dart';
import '../../../core/domain/quantity.dart';

enum SaleType { credit, paid }

enum SaleStatus { posted, reversed }

enum SyncStatus { pending, accepted, rejected }

/// A single line item within a sale.
///
/// Contains immutable snapshots of product name, unit, and unit price
/// captured at the exact moment the bill was posted.
final class SaleLine {
  const SaleLine({
    required this.id,
    required this.saleId,
    required this.description,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.position,
    this.productId,
  });

  final String id;
  final String saleId;
  final String? productId;
  final String description;
  final String unit;
  final Quantity quantity;
  final Money unitPrice;
  final Money lineTotal;
  final int position;

  factory SaleLine.create({
    required String id,
    required String saleId,
    required String description,
    required String unit,
    required Quantity quantity,
    required Money unitPrice,
    required int position,
    String? productId,
  }) {
    final cleanDesc = description.trim();
    if (cleanDesc.isEmpty) {
      throw const ValidationFailure('Item description cannot be empty');
    }
    if (quantity.milli <= 0) {
      throw const ValidationFailure('Quantity must be greater than zero');
    }
    if (unitPrice.isNegative) {
      throw const ValidationFailure('Unit price cannot be negative');
    }

    final calculatedTotal = quantity.times(unitPrice);

    return SaleLine(
      id: id,
      saleId: saleId,
      productId: productId,
      description: cleanDesc,
      unit: unit.trim().toLowerCase(),
      quantity: quantity,
      unitPrice: unitPrice,
      lineTotal: calculatedTotal,
      position: position,
    );
  }
}

/// An immutable posted credit or cash grocery bill.
final class Sale {
  const Sale({
    required this.id,
    required this.shopId,
    required this.customerId,
    required this.receiptNo,
    required this.saleType,
    required this.total,
    required this.createdAt,
    required this.items,
    this.status = SaleStatus.posted,
    this.reversesSaleId,
    this.note,
    this.dueAt,
    this.syncStatus = SyncStatus.pending,
  });

  final String id;
  final String shopId;
  final String customerId;
  final String receiptNo;
  final SaleType saleType;
  final Money total;
  final SaleStatus status;
  final String? reversesSaleId;
  final String? note;
  final DateTime createdAt;
  final DateTime? dueAt;
  final SyncStatus syncStatus;
  final List<SaleLine> items;

  bool get isPosted => status == SaleStatus.posted;
  bool get isReversed => status == SaleStatus.reversed;
  bool get isCredit => saleType == SaleType.credit;
  bool get isPaid => saleType == SaleType.paid;

  /// Verifies cart invariants and total consistency.
  static void validate({
    required String shopId,
    required String customerId,
    required List<SaleLine> items,
    required Money total,
  }) {
    if (shopId.isEmpty) throw const ValidationFailure('Shop ID is required');
    if (customerId.isEmpty) {
      throw const ValidationFailure('Customer must be selected for the bill');
    }
    if (items.isEmpty) {
      throw const ValidationFailure('Bill must contain at least one item');
    }

    final sum = Money.sum(items.map((i) => i.lineTotal));
    if (sum != total) {
      throw ValidationFailure(
        'Bill total (${total.format()}) does not match items sum (${sum.format()})',
      );
    }
  }
}
