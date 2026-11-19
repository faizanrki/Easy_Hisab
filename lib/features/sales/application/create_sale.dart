import '../../../core/contracts/customer_lookup_port.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/clock.dart';
import '../../../core/domain/entity_id.dart';
import '../../../core/domain/money.dart';
import '../../../core/domain/quantity.dart';
import '../domain/sale.dart';
import '../domain/sale_repository.dart';

/// Command DTO specifying an item to be added to a sale.
final class CreateSaleItemInput {
  const CreateSaleItemInput({
    required this.description,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    this.productId,
  });

  final String? productId;
  final String description;
  final String unit;
  final Quantity quantity;
  final Money unitPrice;
}

/// Command DTO for posting a new grocery bill.
final class CreateSaleCommand {
  const CreateSaleCommand({
    required this.shopId,
    required this.customerId,
    required this.saleType,
    required this.items,
    this.initialPayment,
    this.note,
    this.dueAt,
  });

  final String shopId;
  final String customerId;
  final SaleType saleType;
  final List<CreateSaleItemInput> items;
  final Money? initialPayment;
  final String? note;
  final DateTime? dueAt;
}

final class CreateSale {
  const CreateSale(
    this._sales,
    this._customers,
    this._ids,
    this._clock,
  );

  final SaleRepository _sales;
  final CustomerLookupPort _customers;
  final IdGenerator _ids;
  final Clock _clock;

  Future<Sale> execute(CreateSaleCommand cmd) async {
    // 1. Verify customer belongs to the shop via CustomerLookupPort
    final customer = await _customers.findForShop(
      shopId: cmd.shopId,
      customerId: cmd.customerId,
    );
    if (customer == null) {
      throw const NotFoundFailure('Selected customer does not exist in this shop');
    }
    if (customer.isArchived) {
      throw const ValidationFailure('Cannot create a bill for an archived customer');
    }

    if (cmd.items.isEmpty) {
      throw const ValidationFailure('Bill must contain at least one product');
    }

    // 2. Validate initial payment if provided
    final initPay = cmd.initialPayment;
    if (initPay != null && initPay.isNegative) {
      throw const ValidationFailure('Initial payment cannot be negative');
    }

    final now = _clock.nowUtc();
    final saleId = _ids.newId();
    final receiptNo = await _sales.nextReceiptNumber(cmd.shopId);

    // 3. Build immutable SaleLines
    final lines = <SaleLine>[];
    for (var i = 0; i < cmd.items.length; i++) {
      final input = cmd.items[i];
      final line = SaleLine.create(
        id: _ids.newId(),
        saleId: saleId,
        productId: input.productId,
        description: input.description,
        unit: input.unit,
        quantity: input.quantity,
        unitPrice: input.unitPrice,
        position: i,
      );
      lines.add(line);
    }

    // 4. Calculate exact bill total in integer paisa
    final total = Money.sum(lines.map((l) => l.lineTotal));

    if (initPay != null && initPay > total) {
      throw const ValidationFailure('Initial payment cannot exceed the total bill amount');
    }

    final sale = Sale(
      id: saleId,
      shopId: cmd.shopId,
      customerId: cmd.customerId,
      receiptNo: receiptNo,
      saleType: cmd.saleType,
      total: total,
      status: SaleStatus.posted,
      note: cmd.note?.trim().isEmpty == true ? null : cmd.note?.trim(),
      createdAt: now,
      dueAt: cmd.dueAt,
      syncStatus: SyncStatus.pending,
      items: lines,
    );

    // 5. Invariant check
    Sale.validate(
      shopId: sale.shopId,
      customerId: sale.customerId,
      items: sale.items,
      total: sale.total,
    );

    // 6. Atomically persist sale + lines + optional initial payment + outbox
    await _sales.savePendingSale(sale, initialPayment: cmd.initialPayment);
    return sale;
  }
}
