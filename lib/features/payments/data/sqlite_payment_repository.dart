import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/db_transaction.dart';
import '../../../core/domain/app_failure.dart';
import '../../../core/domain/entity_id.dart';
import '../../../core/domain/money.dart';
import '../domain/payment.dart';
import '../domain/payment_repository.dart';
import 'payment_mapper.dart';

final class SqlitePaymentRepository implements PaymentRepository {
  const SqlitePaymentRepository(this._db, this._ids);

  final DatabaseTransactionPort _db;
  final IdGenerator _ids;

  @override
  Future<void> recordPayment(Payment payment) => _guard(() async {
        await _db.inTransaction((tx) async {
          // 1. Insert payment record
          await tx.insert('payments', PaymentMapper.paymentToRow(payment));

          // 2. FIFO Auto-Allocation against unpaid posted credit sales
          final unpaidSales = await tx.rawQuery('''
            SELECT id, total_paisa 
            FROM sales 
            WHERE shop_id = ? 
              AND customer_id = ? 
              AND sale_type = 'credit' 
              AND status = 'posted' 
            ORDER BY created_at ASC
          ''', [payment.shopId, payment.customerId]);

          var remainingPaisa = payment.amount.paisa;

          for (final saleRow in unpaidSales) {
            if (remainingPaisa <= 0) break;

            final saleId = saleRow['id']! as String;
            final totalPaisa = saleRow['total_paisa']! as int;

            // Compute already allocated paisa for this sale
            final allocRows = await tx.rawQuery('''
              SELECT COALESCE(SUM(pa.allocated_paisa), 0) as paid_paisa
              FROM payment_allocations pa
              JOIN payments p ON pa.payment_id = p.id
              WHERE pa.sale_id = ? AND p.status = 'posted'
            ''', [saleId]);

            final alreadyPaid = allocRows.first['paid_paisa'] as int? ?? 0;
            final remainingSaleDue = totalPaisa - alreadyPaid;

            if (remainingSaleDue > 0) {
              final toAllocate = remainingPaisa > remainingSaleDue
                  ? remainingSaleDue
                  : remainingPaisa;

              await tx.insert('payment_allocations', {
                'id': _ids.newId(),
                'payment_id': payment.id,
                'sale_id': saleId,
                'allocated_paisa': toAllocate,
              });

              remainingPaisa -= toAllocate;
            }
          }

          // 3. Outbox queue for cloud synchronization
          await tx.insert('sync_queue', {
            'operation_id': _ids.newId(),
            'shop_id': payment.shopId,
            'entity_type': 'payment',
            'entity_id': payment.id,
            'operation': 'create',
            'payload': jsonEncode({
              'payment_id': payment.id,
              'customer_id': payment.customerId,
              'amount_paisa': payment.amount.paisa,
              'method': payment.method.name,
              'note': payment.note,
              'created_at': payment.createdAt.millisecondsSinceEpoch,
            }),
            'sync_status': 'pending',
            'created_at': payment.createdAt.millisecondsSinceEpoch,
            'updated_at': payment.createdAt.millisecondsSinceEpoch,
          });

          // 4. Append-only audit trail
          await tx.insert('audit_log', {
            'id': _ids.newId(),
            'shop_id': payment.shopId,
            'actor_uid': null,
            'action': 'payment.posted',
            'record_type': 'payment',
            'record_id': payment.id,
            'details': jsonEncode({
              'amount_paisa': payment.amount.paisa,
              'method': payment.method.name,
              'note': payment.note,
            }),
            'created_at': payment.createdAt.millisecondsSinceEpoch,
          });
        });
      });

  @override
  Future<Payment?> findById(String shopId, String paymentId) =>
      _guard(() async {
        final rows = await _db.executor.query(
          'payments',
          where: 'id = ? AND shop_id = ?',
          whereArgs: [paymentId, shopId],
          limit: 1,
        );
        if (rows.isEmpty) return null;

        final allocRows = await _db.executor.query(
          'payment_allocations',
          where: 'payment_id = ?',
          whereArgs: [paymentId],
        );
        final allocations =
            allocRows.map(PaymentMapper.allocationFromRow).toList();

        return PaymentMapper.paymentFromRow(rows.first, allocations);
      });

  @override
  Future<List<Payment>> listCustomerPayments(
    String shopId,
    String customerId, {
    int limit = 100,
  }) =>
      _guard(() async {
        final rows = await _db.executor.query(
          'payments',
          where: 'shop_id = ? AND customer_id = ?',
          whereArgs: [shopId, customerId],
          orderBy: 'created_at DESC',
          limit: limit,
        );

        final result = <Payment>[];
        for (final row in rows) {
          final pid = row['id']! as String;
          final allocRows = await _db.executor.query(
            'payment_allocations',
            where: 'payment_id = ?',
            whereArgs: [pid],
          );
          final allocations =
              allocRows.map(PaymentMapper.allocationFromRow).toList();
          result.add(PaymentMapper.paymentFromRow(row, allocations));
        }
        return result;
      });

  @override
  Future<List<Payment>> listShopPayments(
    String shopId, {
    int limit = 50,
  }) =>
      _guard(() async {
        final rows = await _db.executor.query(
          'payments',
          where: 'shop_id = ?',
          whereArgs: [shopId],
          orderBy: 'created_at DESC',
          limit: limit,
        );

        return rows.map((r) => PaymentMapper.paymentFromRow(r)).toList();
      });

  @override
  Future<void> reversePayment(
    String shopId,
    String paymentId, {
    required String reason,
    required DateTime reversedAt,
  }) =>
      _guard(() async {
        await _db.inTransaction((tx) async {
          final rows = await tx.query(
            'payments',
            where: 'id = ? AND shop_id = ?',
            whereArgs: [paymentId, shopId],
            limit: 1,
          );
          if (rows.isEmpty) throw const NotFoundFailure('Payment not found');

          final status = rows.first['status'] as String;
          if (status == 'reversed') {
            throw const ValidationFailure('Payment is already reversed');
          }

          // Triggers in migration_001 forbid deleting or modifying amounts, but allow status updates
          await tx.update(
            'payments',
            {
              'status': 'reversed',
              'note': 'REVERSED: $reason',
            },
            where: 'id = ? AND shop_id = ?',
            whereArgs: [paymentId, shopId],
          );

          // Outbox reversal entry
          await tx.insert('sync_queue', {
            'operation_id': _ids.newId(),
            'shop_id': shopId,
            'entity_type': 'payment',
            'entity_id': paymentId,
            'operation': 'reverse',
            'payload': jsonEncode({'payment_id': paymentId, 'reason': reason}),
            'sync_status': 'pending',
            'created_at': reversedAt.millisecondsSinceEpoch,
            'updated_at': reversedAt.millisecondsSinceEpoch,
          });

          // Append-only audit
          await tx.insert('audit_log', {
            'id': _ids.newId(),
            'shop_id': shopId,
            'actor_uid': null,
            'action': 'payment.reversed',
            'record_type': 'payment',
            'record_id': paymentId,
            'details': jsonEncode({'reason': reason}),
            'created_at': reversedAt.millisecondsSinceEpoch,
          });
        });
      });

  @override
  Future<Money> getCustomerBalance(String shopId, String customerId) =>
      _guard(() async {
        final rows = await _db.executor.rawQuery('''
          SELECT
            (SELECT COALESCE(SUM(total_paisa), 0) 
             FROM sales 
             WHERE shop_id = ? AND customer_id = ? AND sale_type = 'credit' AND status = 'posted') as sales_total,
            (SELECT COALESCE(SUM(amount_paisa), 0) 
             FROM payments 
             WHERE shop_id = ? AND customer_id = ? AND status = 'posted') as payments_total
        ''', [shopId, customerId, shopId, customerId]);

        final salesTotal = rows.first['sales_total'] as int? ?? 0;
        final paymentsTotal = rows.first['payments_total'] as int? ?? 0;

        return Money.paisa(salesTotal - paymentsTotal);
      });

  @override
  Future<List<LedgerEntry>> getCustomerLedger(
    String shopId,
    String customerId,
  ) =>
      _guard(() async {
        // Query posted credit sales
        final saleRows = await _db.executor.query(
          'sales',
          where: "shop_id = ? AND customer_id = ? AND sale_type = 'credit'",
          whereArgs: [shopId, customerId],
          orderBy: 'created_at ASC',
        );

        // Query payments
        final paymentRows = await _db.executor.query(
          'payments',
          where: 'shop_id = ? AND customer_id = ?',
          whereArgs: [shopId, customerId],
          orderBy: 'created_at ASC',
        );

        // Combine into unified events list sorted by timestamp
        final rawEvents = <_RawEvent>[];

        for (final row in saleRows) {
          rawEvents.add(_RawEvent(
            id: row['id']! as String,
            date: DateTime.fromMillisecondsSinceEpoch(
              row['created_at']! as int,
              isUtc: true,
            ),
            type: LedgerEntryType.sale,
            description: 'Credit Bill #${row['receipt_no']}',
            referenceNo: row['receipt_no']! as String,
            amount: Money.paisa(row['total_paisa']! as int),
            isReversed: (row['status'] as String? ?? 'posted') == 'reversed',
          ));
        }

        for (final row in paymentRows) {
          final pid = row['id']! as String;
          final methodStr = PaymentMethod.fromString(row['method'] as String?)
              .displayName;
          final note = row['note'] as String?;
          final desc = note != null && note.isNotEmpty
              ? 'Payment ($methodStr): $note'
              : 'Payment received ($methodStr)';

          rawEvents.add(_RawEvent(
            id: pid,
            date: DateTime.fromMillisecondsSinceEpoch(
              row['created_at']! as int,
              isUtc: true,
            ),
            type: LedgerEntryType.payment,
            description: desc,
            referenceNo: pid.length > 8 ? pid.substring(0, 8) : pid,
            amount: Money.paisa(row['amount_paisa']! as int),
            isReversed: (row['status'] as String? ?? 'posted') == 'reversed',
          ));
        }

        rawEvents.sort((a, b) => a.date.compareTo(b.date));

        // Compute running balance chronologically
        var runningPaisa = 0;
        final ledger = <LedgerEntry>[];

        for (final ev in rawEvents) {
          if (!ev.isReversed) {
            if (ev.type == LedgerEntryType.sale) {
              runningPaisa += ev.amount.paisa;
            } else {
              runningPaisa -= ev.amount.paisa;
            }
          }

          ledger.add(LedgerEntry(
            id: ev.id,
            date: ev.date,
            type: ev.type,
            description: ev.description,
            referenceNo: ev.referenceNo,
            debit: ev.type == LedgerEntryType.sale ? ev.amount : Money.zero,
            credit:
                ev.type == LedgerEntryType.payment ? ev.amount : Money.zero,
            runningBalance: Money.paisa(runningPaisa),
            isReversed: ev.isReversed,
          ));
        }

        // Return latest first for presentation in the UI
        return ledger.reversed.toList();
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on DatabaseException catch (e) {
      throw StorageFailure('Could not access payment data', e);
    }
  }
}

final class _RawEvent {
  const _RawEvent({
    required this.id,
    required this.date,
    required this.type,
    required this.description,
    required this.referenceNo,
    required this.amount,
    required this.isReversed,
  });

  final String id;
  final DateTime date;
  final LedgerEntryType type;
  final String description;
  final String referenceNo;
  final Money amount;
  final bool isReversed;
}
