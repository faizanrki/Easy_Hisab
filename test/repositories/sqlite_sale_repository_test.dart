import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/app_failure.dart';
import 'package:easy_hisab/core/domain/entity_id.dart';
import 'package:easy_hisab/core/domain/money.dart';
import 'package:easy_hisab/core/domain/quantity.dart';
import 'package:easy_hisab/features/sales/data/sqlite_sale_repository.dart';
import 'package:easy_hisab/features/sales/domain/sale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late LocalDatabase db;
  late SqliteSaleRepository repository;
  const idGen = UuidIdGenerator();
  const shopId = 'test-shop-1';
  const otherShopId = 'test-shop-2';
  const customerId = 'cust-1';
  const customer2Id = 'cust-2';

  setUp(() async {
    db = await LocalDatabase.openAt(
      inMemoryDatabasePath,
      factory: databaseFactoryFfi,
    );
    repository = SqliteSaleRepository(db, idGen);

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

    // Insert customers for foreign key validity
    await db.executor.insert('customers', {
      'id': customerId,
      'shop_id': shopId,
      'name': 'Tariq Mehmood',
      'name_search': 'tariq mehmood',
      'created_at': nowMs,
      'updated_at': nowMs,
    });
    await db.executor.insert('customers', {
      'id': customer2Id,
      'shop_id': shopId,
      'name': 'Kamran Khan',
      'name_search': 'kamran khan',
      'created_at': nowMs,
      'updated_at': nowMs,
    });
  });

  tearDown(() => db.close());

  Sale createTestSale({
    required String id,
    required String receiptNo,
    String targetShop = shopId,
    String targetCustomer = customerId,
    SaleType saleType = SaleType.credit,
    SaleStatus status = SaleStatus.posted,
    DateTime? createdAt,
  }) {
    final now = createdAt ?? DateTime.utc(2026, 11, 20, 10, 0);
    final items = [
      SaleLine.create(
        id: '${id}_l1',
        saleId: id,
        description: 'Sugar',
        unit: 'kg',
        quantity: const Quantity.whole(2),
        unitPrice: const Money.rupees(150), // Rs 300
        position: 0,
      ),
      SaleLine.create(
        id: '${id}_l2',
        saleId: id,
        description: 'Cooking Oil',
        unit: 'ltr',
        quantity: const Quantity.whole(4),
        unitPrice: const Money.rupees(550), // Rs 2200
        position: 1,
      ),
    ];

    return Sale(
      id: id,
      shopId: targetShop,
      customerId: targetCustomer,
      receiptNo: receiptNo,
      saleType: saleType,
      total: const Money.rupees(2500),
      createdAt: now,
      items: items,
      status: status,
    );
  }

  group('Receipt Number Generation', () {
    test('starts at R-0001 when no prior sales exist', () async {
      final receipt = await repository.nextReceiptNumber(shopId);
      expect(receipt, 'R-0001');
    });

    test('increments sequentially to R-0002 after saving sale', () async {
      final sale1 = createTestSale(id: 's-1', receiptNo: 'R-0001');
      await repository.savePendingSale(sale1);

      final nextReceipt = await repository.nextReceiptNumber(shopId);
      expect(nextReceipt, 'R-0002');
    });
  });

  group('savePendingSale and findById', () {
    test('atomically saves sale, line items, and audit log', () async {
      final sale = createTestSale(id: 'sale-100', receiptNo: 'R-0001');
      await repository.savePendingSale(sale);

      final fetched = await repository.findById(shopId, 'sale-100');
      expect(fetched, isNotNull);
      expect(fetched!.id, 'sale-100');
      expect(fetched.receiptNo, 'R-0001');
      expect(fetched.total.format(), 'Rs 2,500');
      expect(fetched.items.length, 2);
      expect(fetched.items[0].description, 'Sugar');
      expect(fetched.items[0].lineTotal.format(), 'Rs 300');
      expect(fetched.items[1].description, 'Cooking Oil');
      expect(fetched.items[1].lineTotal.format(), 'Rs 2,200');

      // Check outbox queue
      final queueRows = await db.executor.query(
        'sync_queue',
        where: 'entity_id = ?',
        whereArgs: ['sale-100'],
      );
      expect(queueRows.length, 1);
      expect(queueRows.first['entity_type'], 'sale');

      // Check audit log
      final auditRows = await db.executor.query(
        'audit_log',
        where: 'record_id = ?',
        whereArgs: ['sale-100'],
      );
      expect(auditRows.length, 1);
      expect(auditRows.first['action'], 'sale.posted');
    });

    test('records initial payment and payment allocation at checkout', () async {
      final sale = createTestSale(id: 'sale-101', receiptNo: 'R-0001');
      // Rs 2,500 total with Rs 1,000 paid at checkout
      await repository.savePendingSale(
        sale,
        initialPayment: const Money.rupees(1000),
      );

      final payments = await db.executor.query(
        'payments',
        where: 'sale_id = ?',
        whereArgs: ['sale-101'],
      );
      expect(payments.length, 1);
      expect(payments.first['amount_paisa'], 100000); // Rs 1,000

      final allocations = await db.executor.query(
        'payment_allocations',
        where: 'sale_id = ?',
        whereArgs: ['sale-101'],
      );
      expect(allocations.length, 1);
      expect(allocations.first['allocated_paisa'], 100000);
    });

    test('enforces tenant isolation', () async {
      final sale = createTestSale(id: 'sale-102', receiptNo: 'R-0001');
      await repository.savePendingSale(sale);

      final fetchedFromOther = await repository.findById(otherShopId, 'sale-102');
      expect(fetchedFromOther, isNull);
    });
  });

  group('Reversal', () {
    test('marks sale as reversed, creates outbox entry and audit log', () async {
      final sale = createTestSale(id: 'sale-to-reverse', receiptNo: 'R-0001');
      await repository.savePendingSale(sale);

      await repository.reverseSale(
        shopId,
        'sale-to-reverse',
        reason: 'Customer returned items',
        reversedAt: DateTime.utc(2026, 11, 20, 11, 0),
      );

      final updated = await repository.findById(shopId, 'sale-to-reverse');
      expect(updated, isNotNull);
      expect(updated!.status, SaleStatus.reversed);
      expect(updated.isReversed, isTrue);

      // Verify audit log has reason
      final audit = await db.executor.query(
        'audit_log',
        where: 'record_id = ? AND action = ?',
        whereArgs: ['sale-to-reverse', 'sale.reversed'],
      );
      expect(audit.length, 1);
      expect(audit.first['details'], contains('Customer returned items'));
    });

    test('rejects reversing already reversed sale', () async {
      final sale = createTestSale(id: 'already-reversed', receiptNo: 'R-0001');
      await repository.savePendingSale(sale);

      await repository.reverseSale(
        shopId,
        'already-reversed',
        reason: 'Mistake',
        reversedAt: DateTime.utc(2026, 11, 20, 11, 0),
      );

      expect(
        () => repository.reverseSale(
          shopId,
          'already-reversed',
          reason: 'Double reverse attempt',
          reversedAt: DateTime.utc(2026, 11, 20, 11, 5),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('findByCustomer and findRecent', () {
    test('lists customer sales in reverse chronological order', () async {
      final s1 = createTestSale(
        id: 's-1',
        receiptNo: 'R-0001',
        createdAt: DateTime.utc(2026, 11, 19, 10, 0),
      );
      final s2 = createTestSale(
        id: 's-2',
        receiptNo: 'R-0002',
        createdAt: DateTime.utc(2026, 11, 20, 10, 0),
      );
      final s3 = createTestSale(
        id: 's-3',
        receiptNo: 'R-0003',
        targetCustomer: customer2Id,
        createdAt: DateTime.utc(2026, 11, 20, 11, 0),
      );

      await repository.savePendingSale(s1);
      await repository.savePendingSale(s2);
      await repository.savePendingSale(s3);

      final cust1Sales = await repository.listCustomerSales(shopId, customerId);
      expect(cust1Sales.length, 2);
      expect(cust1Sales[0].id, 's-2'); // latest first
      expect(cust1Sales[1].id, 's-1');

      final recent = await repository.listShopSales(shopId, limit: 10);
      expect(recent.length, 3);
      expect(recent[0].id, 's-3');
    });
  });
}
