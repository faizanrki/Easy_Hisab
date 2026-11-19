import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/app_failure.dart';
import 'package:easy_hisab/core/domain/entity_id.dart';
import 'package:easy_hisab/core/domain/money.dart';
import 'package:easy_hisab/features/payments/data/sqlite_payment_repository.dart';
import 'package:easy_hisab/features/payments/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late LocalDatabase db;
  late SqlitePaymentRepository repository;
  const idGen = UuidIdGenerator();
  const shopId = 'test-shop-1';
  const otherShopId = 'test-shop-2';
  const customerId = 'cust-1';

  setUp(() async {
    db = await LocalDatabase.openAt(
      inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    repository = SqlitePaymentRepository(db, idGen);

    const nowMs = 1763560000000;
    // Insert shops
    await db.executor.insert('shops', {
      'id': shopId,
      'name': 'Primary Shop',
      'created_at': nowMs,
      'updated_at': nowMs,
    });
    await db.executor.insert('shops', {
      'id': otherShopId,
      'name': 'Other Shop',
      'created_at': nowMs,
      'updated_at': nowMs,
    });

    // Insert customer
    await db.executor.insert('customers', {
      'id': customerId,
      'shop_id': shopId,
      'name': 'Tariq Mehmood',
      'name_search': 'tariq mehmood',
      'created_at': nowMs,
      'updated_at': nowMs,
    });
  });

  tearDown(() => db.close());

  Future<void> seedCreditSale(String saleId, int totalRupees, int timestampMs) async {
    await db.executor.insert('sales', {
      'id': saleId,
      'shop_id': shopId,
      'customer_id': customerId,
      'receipt_no': 'R-$saleId',
      'sale_type': 'credit',
      'total_paisa': totalRupees * 100,
      'status': 'posted',
      'created_at': timestampMs,
      'sync_status': 'pending',
    });
  }

  group('recordPayment & findById', () {
    test('atomically records payment, outbox entry, and audit log', () async {
      final now = DateTime.utc(2026, 11, 20, 10, 0);
      final payment = Payment(
        id: 'pay-1',
        shopId: shopId,
        customerId: customerId,
        amount: const Money.rupees(1000),
        method: PaymentMethod.cash,
        note: 'Cash repayment',
        createdAt: now,
      );

      await repository.recordPayment(payment);

      final fetched = await repository.findById(shopId, 'pay-1');
      expect(fetched, isNotNull);
      expect(fetched!.amount, const Money.rupees(1000));
      expect(fetched.method, PaymentMethod.cash);
      expect(fetched.note, 'Cash repayment');
      expect(fetched.isPosted, isTrue);

      // Verify sync_queue outbox
      final queueRows = await db.executor.query(
        'sync_queue',
        where: 'entity_id = ?',
        whereArgs: ['pay-1'],
      );
      expect(queueRows.length, 1);
      expect(queueRows.first['entity_type'], 'payment');

      // Verify audit_log
      final auditRows = await db.executor.query(
        'audit_log',
        where: 'record_id = ?',
        whereArgs: ['pay-1'],
      );
      expect(auditRows.length, 1);
      expect(auditRows.first['action'], 'payment.posted');
    });

    test('enforces tenant isolation', () async {
      final payment = Payment(
        id: 'pay-2',
        shopId: shopId,
        customerId: customerId,
        amount: const Money.rupees(500),
        createdAt: DateTime.utc(2026, 11, 20, 10, 0),
      );
      await repository.recordPayment(payment);

      final otherShopResult = await repository.findById(otherShopId, 'pay-2');
      expect(otherShopResult, isNull);
    });
  });

  group('FIFO Auto-Allocation', () {
    test('allocates payment across unpaid credit sales in oldest-first order', () async {
      // Sale 1: Rs 1,000 at 10:00
      await seedCreditSale('sale-1', 1000, 1763630000000);
      // Sale 2: Rs 1,500 at 11:00
      await seedCreditSale('sale-2', 1500, 1763633600000);

      // Payment: Rs 1,500 at 12:00
      final payment = Payment(
        id: 'pay-fifo',
        shopId: shopId,
        customerId: customerId,
        amount: const Money.rupees(1500),
        createdAt: DateTime.utc(2026, 11, 20, 12, 0),
      );

      await repository.recordPayment(payment);

      final allocations = await db.executor.query(
        'payment_allocations',
        where: 'payment_id = ?',
        whereArgs: ['pay-fifo'],
        orderBy: 'sale_id ASC',
      );

      // Should have 2 allocations:
      // 1. Rs 1,000 allocated to sale-1 (fully pays sale-1)
      // 2. Rs 500 allocated to sale-2 (leaves Rs 1,000 unpaid on sale-2)
      expect(allocations.length, 2);

      final allocSale1 = allocations.firstWhere((a) => a['sale_id'] == 'sale-1');
      expect(allocSale1['allocated_paisa'], 100000); // Rs 1,000

      final allocSale2 = allocations.firstWhere((a) => a['sale_id'] == 'sale-2');
      expect(allocSale2['allocated_paisa'], 50000); // Rs 500
    });
  });

  group('Customer Balance Calculation', () {
    test('computes net udhar = sum(posted sales) - sum(posted payments)', () async {
      // Rs 2,500 credit sale
      await seedCreditSale('sale-spec', 2500, 1763630000000);

      // Initial balance should be Rs 2,500
      final balanceBefore = await repository.getCustomerBalance(shopId, customerId);
      expect(balanceBefore, const Money.rupees(2500));
      expect(balanceBefore.format(), 'Rs 2,500');

      // Record Rs 1,000 repayment
      final payment = Payment(
        id: 'pay-spec',
        shopId: shopId,
        customerId: customerId,
        amount: const Money.rupees(1000),
        createdAt: DateTime.utc(2026, 11, 20, 11, 0),
      );
      await repository.recordPayment(payment);

      // Balance after payment: Rs 2,500 - Rs 1,000 = Rs 1,500
      final balanceAfter = await repository.getCustomerBalance(shopId, customerId);
      expect(balanceAfter, const Money.rupees(1500));
      expect(balanceAfter.format(), 'Rs 1,500');
    });
  });

  group('Payment Reversal', () {
    test('reverses payment, writes outbox and audit log, and restores balance', () async {
      await seedCreditSale('sale-rev', 2500, 1763630000000);

      final payment = Payment(
        id: 'pay-to-rev',
        shopId: shopId,
        customerId: customerId,
        amount: const Money.rupees(1000),
        createdAt: DateTime.utc(2026, 11, 20, 11, 0),
      );
      await repository.recordPayment(payment);

      // Reverse the payment
      await repository.reversePayment(
        shopId,
        'pay-to-rev',
        reason: 'Customer cancelled transaction',
        reversedAt: DateTime.utc(2026, 11, 20, 12, 0),
      );

      final fetched = await repository.findById(shopId, 'pay-to-rev');
      expect(fetched, isNotNull);
      expect(fetched!.status, PaymentStatus.reversed);
      expect(fetched.note, contains('REVERSED: Customer cancelled transaction'));

      // Check balance restored back to full Rs 2,500
      final restoredBalance = await repository.getCustomerBalance(shopId, customerId);
      expect(restoredBalance, const Money.rupees(2500));

      // Audit log has reversal
      final audit = await db.executor.query(
        'audit_log',
        where: 'record_id = ? AND action = ?',
        whereArgs: ['pay-to-rev', 'payment.reversed'],
      );
      expect(audit.length, 1);
    });

    test('rejects double reversal', () async {
      final payment = Payment(
        id: 'pay-double',
        shopId: shopId,
        customerId: customerId,
        amount: const Money.rupees(500),
        createdAt: DateTime.utc(2026, 11, 20, 10, 0),
      );
      await repository.recordPayment(payment);

      await repository.reversePayment(
        shopId,
        'pay-double',
        reason: 'First reversal',
        reversedAt: DateTime.utc(2026, 11, 20, 11, 0),
      );

      expect(
        () => repository.reversePayment(
          shopId,
          'pay-double',
          reason: 'Second reversal attempt',
          reversedAt: DateTime.utc(2026, 11, 20, 11, 5),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('Customer Ledger Timeline', () {
    test('computes unified chronological khata ledger with accurate running balances', () async {
      // 1. Credit sale: Rs 2,500 at 10:00
      await seedCreditSale('s1', 2500, 1763630000000);

      // 2. Repayment: Rs 1,000 at 11:00
      final pay1 = Payment(
        id: 'p1',
        shopId: shopId,
        customerId: customerId,
        amount: const Money.rupees(1000),
        createdAt: DateTime.fromMillisecondsSinceEpoch(1763633600000, isUtc: true),
      );
      await repository.recordPayment(pay1);

      // 3. Second credit sale: Rs 500 at 12:00
      await seedCreditSale('s2', 500, 1763637200000);

      final ledger = await repository.getCustomerLedger(shopId, customerId);

      // Returns in reverse chronological order (latest first)
      expect(ledger.length, 3);

      // Latest entry (s2): +Rs 500 -> Running balance = Rs 1,500 + Rs 500 = Rs 2,000
      expect(ledger[0].type, LedgerEntryType.sale);
      expect(ledger[0].debit, const Money.rupees(500));
      expect(ledger[0].runningBalance, const Money.rupees(2000));

      // Middle entry (p1): -Rs 1,000 -> Running balance = Rs 2,500 - Rs 1,000 = Rs 1,500
      expect(ledger[1].type, LedgerEntryType.payment);
      expect(ledger[1].credit, const Money.rupees(1000));
      expect(ledger[1].runningBalance, const Money.rupees(1500));

      // Oldest entry (s1): +Rs 2,500 -> Running balance = Rs 2,500
      expect(ledger[2].type, LedgerEntryType.sale);
      expect(ledger[2].debit, const Money.rupees(2500));
      expect(ledger[2].runningBalance, const Money.rupees(2500));
    });
  });
}
