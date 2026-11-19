import '../../../core/domain/money.dart';
import '../../../core/domain/quantity.dart';
import '../domain/sale.dart';

abstract final class SaleMapper {
  static Map<String, Object?> saleToRow(Sale sale) => {
        'id': sale.id,
        'shop_id': sale.shopId,
        'customer_id': sale.customerId,
        'receipt_no': sale.receiptNo,
        'sale_type': sale.saleType.name,
        'total_paisa': sale.total.paisa,
        'status': sale.status.name,
        'reverses_sale_id': sale.reversesSaleId,
        'note': sale.note,
        'created_at': sale.createdAt.millisecondsSinceEpoch,
        'due_at': sale.dueAt?.millisecondsSinceEpoch,
        'sync_status': sale.syncStatus.name,
      };

  static Map<String, Object?> lineToRow(SaleLine line) => {
        'id': line.id,
        'sale_id': line.saleId,
        'product_id': line.productId,
        'description': line.description,
        'unit': line.unit,
        'quantity_milli': line.quantity.milli,
        'unit_price_paisa': line.unitPrice.paisa,
        'line_total_paisa': line.lineTotal.paisa,
        'position': line.position,
      };

  static Sale saleFromRow(
    Map<String, Object?> row,
    List<SaleLine> items,
  ) =>
      Sale(
        id: row['id']! as String,
        shopId: row['shop_id']! as String,
        customerId: row['customer_id']! as String,
        receiptNo: row['receipt_no']! as String,
        saleType: SaleType.values.byName(row['sale_type']! as String),
        total: Money.paisa(row['total_paisa']! as int),
        status: SaleStatus.values.byName(row['status']! as String),
        reversesSaleId: row['reverses_sale_id'] as String?,
        note: row['note'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row['created_at']! as int,
          isUtc: true,
        ),
        dueAt: row['due_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                row['due_at']! as int,
                isUtc: true,
              )
            : null,
        syncStatus: SyncStatus.values.byName(row['sync_status']! as String),
        items: items,
      );

  static SaleLine lineFromRow(Map<String, Object?> row) => SaleLine(
        id: row['id']! as String,
        saleId: row['sale_id']! as String,
        productId: row['product_id'] as String?,
        description: row['description']! as String,
        unit: row['unit']! as String,
        quantity: Quantity.milli(row['quantity_milli']! as int),
        unitPrice: Money.paisa(row['unit_price_paisa']! as int),
        lineTotal: Money.paisa(row['line_total_paisa']! as int),
        position: row['position']! as int,
      );
}
