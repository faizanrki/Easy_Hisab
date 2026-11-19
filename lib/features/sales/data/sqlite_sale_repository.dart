import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_transaction.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/entity_id.dart';
import '../../../core/domain/money.dart';
import '../domain/sale.dart';
import '../domain/sale_repository.dart';
import 'sale_mapper.dart';

final class SqliteSaleRepository implements SaleRepository {
  const SqliteSaleRepository(this._db, this._ids);

  final DatabaseTransactionPort _db;
  final IdGenerator _ids;

  @override
  Future<void> savePendingSale(Sale sale, {Money? initialPayment}) =>
      _guard(() async {
        await _db.inTransaction((tx) async {
          // 1. Insert sale record
          await tx.insert('sales', SaleMapper.saleToRow(sale));

          // 2. Insert line items with snapshots
          for (final line in sale.items) {
            await tx.insert('sale_items', SaleMapper.lineToRow(line));
          }

          // 3. Optional initial payment at checkout
          if (initialPayment != null && initialPayment > Money.zero) {
            final paymentId = _ids.newId();
            await tx.insert('payments', {
              'id': paymentId,
              'shop_id': sale.shopId,
              'customer_id': sale.customerId,
              'amount_paisa': initialPayment.paisa,
              'method': 'cash',
              'sale_id': sale.id,
              'status': 'posted',
              'created_at': sale.createdAt.millisecondsSinceEpoch,
              'sync_status': 'pending',
            });

            await tx.insert('payment_allocations', {
              'id': _ids.newId(),
              'payment_id': paymentId,
              'sale_id': sale.id,
              'allocated_paisa': initialPayment.paisa,
            });

            // Outbox for payment
            await tx.insert('sync_queue', {
              'operation_id': _ids.newId(),
              'shop_id': sale.shopId,
              'entity_type': 'payment',
              'entity_id': paymentId,
              'operation': 'create',
              'payload': jsonEncode({
                'payment_id': paymentId,
                'customer_id': sale.customerId,
                'amount_paisa': initialPayment.paisa,
                'sale_id': sale.id,
              }),
              'sync_status': 'pending',
              'created_at': sale.createdAt.millisecondsSinceEpoch,
              'updated_at': sale.createdAt.millisecondsSinceEpoch,
            });
          }

          // 4. Outbox row for sync queue (Pending offline sync)
          await tx.insert('sync_queue', {
            'operation_id': _ids.newId(),
            'shop_id': sale.shopId,
            'entity_type': 'sale',
            'entity_id': sale.id,
            'operation': 'create',
            'payload': jsonEncode({
              'sale_id': sale.id,
              'customer_id': sale.customerId,
              'receipt_no': sale.receiptNo,
              'sale_type': sale.saleType.name,
              'total_paisa': sale.total.paisa,
              'items': sale.items.map((i) => {
                'product_id': i.productId,
                'description': i.description,
                'unit': i.unit,
                'quantity_milli': i.quantity.milli,
                'unit_price_paisa': i.unitPrice.paisa,
                'line_total_paisa': i.lineTotal.paisa,
              }).toList(),
            }),
            'sync_status': 'pending',
            'created_at': sale.createdAt.millisecondsSinceEpoch,
            'updated_at': sale.createdAt.millisecondsSinceEpoch,
          });

          // 5. Append-only audit entry
          await tx.insert('audit_log', {
            'id': _ids.newId(),
            'shop_id': sale.shopId,
            'actor_uid': null,
            'action': 'sale.posted',
            'record_type': 'sale',
            'record_id': sale.id,
            'details': jsonEncode({
              'receipt_no': sale.receiptNo,
              'total_paisa': sale.total.paisa,
              'items_count': sale.items.length,
              'sale_type': sale.saleType.name,
            }),
            'created_at': sale.createdAt.millisecondsSinceEpoch,
          });
        });
      });

  @override
  Future<Sale?> findById(String shopId, String saleId) => _guard(() async {
        final saleRows = await _db.executor.query(
          'sales',
          where: 'id = ? AND shop_id = ?',
          whereArgs: [saleId, shopId],
          limit: 1,
        );
        if (saleRows.isEmpty) return null;

        final itemRows = await _db.executor.query(
          'sale_items',
          where: 'sale_id = ?',
          whereArgs: [saleId],
          orderBy: 'position ASC',
        );

        final items = itemRows.map(SaleMapper.lineFromRow).toList();
        return SaleMapper.saleFromRow(saleRows.first, items);
      });

  @override
  Future<List<Sale>> listCustomerSales(String shopId, String customerId) =>
      _guard(() async {
        final saleRows = await _db.executor.query(
          'sales',
          where: 'shop_id = ? AND customer_id = ?',
          whereArgs: [shopId, customerId],
          orderBy: 'created_at DESC',
        );

        final result = <Sale>[];
        for (final row in saleRows) {
          final id = row['id']! as String;
          final itemRows = await _db.executor.query(
            'sale_items',
            where: 'sale_id = ?',
            whereArgs: [id],
            orderBy: 'position ASC',
          );
          result.add(
            SaleMapper.saleFromRow(
              row,
              itemRows.map(SaleMapper.lineFromRow).toList(),
            ),
          );
        }
        return result;
      });

  @override
  Future<List<Sale>> listShopSales(String shopId, {int limit = 50}) =>
      _guard(() async {
        final saleRows = await _db.executor.query(
          'sales',
          where: 'shop_id = ?',
          whereArgs: [shopId],
          orderBy: 'created_at DESC',
          limit: limit,
        );

        final result = <Sale>[];
        for (final row in saleRows) {
          final id = row['id']! as String;
          final itemRows = await _db.executor.query(
            'sale_items',
            where: 'sale_id = ?',
            whereArgs: [id],
            orderBy: 'position ASC',
          );
          result.add(
            SaleMapper.saleFromRow(
              row,
              itemRows.map(SaleMapper.lineFromRow).toList(),
            ),
          );
        }
        return result;
      });

  @override
  Future<String> nextReceiptNumber(String shopId) => _guard(() async {
        final rows = await _db.executor.rawQuery(
          'SELECT COUNT(*) as cnt FROM sales WHERE shop_id = ?',
          [shopId],
        );
        final count = (rows.first['cnt'] as int? ?? 0) + 1;
        return 'R-${count.toString().padLeft(4, '0')}';
      });

  @override
  Future<void> reverseSale(
    String shopId,
    String saleId, {
    required String reason,
    required DateTime reversedAt,
  }) =>
      _guard(() async {
        await _db.inTransaction((tx) async {
          final rows = await tx.query(
            'sales',
            where: 'id = ? AND shop_id = ?',
            whereArgs: [saleId, shopId],
            limit: 1,
          );
          if (rows.isEmpty) throw const NotFoundFailure('Sale not found');

          final status = rows.first['status'] as String;
          if (status == 'reversed') {
            throw const ValidationFailure('Sale is already reversed');
          }

          // Mark sale as reversed (Triggers in migration_001 forbid deleting or modifying amounts, but allow status updates)
          final count = await tx.update(
            'sales',
            {
              'status': 'reversed',
              'note': 'REVERSED: $reason',
            },
            where: 'id = ? AND shop_id = ?',
            whereArgs: [saleId, shopId],
          );

          if (count == 0) throw const NotFoundFailure('Sale not found');

          // Outbox reversal entry
          await tx.insert('sync_queue', {
            'operation_id': _ids.newId(),
            'shop_id': shopId,
            'entity_type': 'sale',
            'entity_id': saleId,
            'operation': 'reverse',
            'payload': jsonEncode({'sale_id': saleId, 'reason': reason}),
            'sync_status': 'pending',
            'created_at': reversedAt.millisecondsSinceEpoch,
            'updated_at': reversedAt.millisecondsSinceEpoch,
          });

          // Append-only audit
          await tx.insert('audit_log', {
            'id': _ids.newId(),
            'shop_id': shopId,
            'actor_uid': null,
            'action': 'sale.reversed',
            'record_type': 'sale',
            'record_id': saleId,
            'details': jsonEncode({'reason': reason}),
            'created_at': reversedAt.millisecondsSinceEpoch,
          });
        });
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on DatabaseException catch (e) {
      throw StorageFailure('Could not query sales data', e);
    }
  }
}
