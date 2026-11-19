import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/entity_id.dart';
import 'package:easy_hisab/core/domain/money.dart';
import 'package:easy_hisab/features/customer_portal/data/sqlite_customer_portal_repository.dart';

void main() {
  sqfliteFfiInit();

  group('Module 09: SqliteCustomerPortalRepository', () {
    late LocalDatabase db;
    late SqliteCustomerPortalRepository repo;
    const idGen = UuidIdGenerator();

    setUp(() async {
      db = await LocalDatabase.openAt(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      repo = SqliteCustomerPortalRepository(db, idGen);

      // Seed shop
      const nowMs = 1763560000000;
      await db.executor.insert('shops', {
        'id': 'shop_1',
        'name': 'Madina Super Store',
        'contact_phone': '03001234567',
        'address': 'Main Bazar, Lahore',
        'created_at': nowMs,
        'updated_at': nowMs,
      });

      // Seed customer with phone 03129876543
      await db.executor.insert('customers', {
        'id': 'cust_1',
        'shop_id': 'shop_1',
        'name': 'Ahmed Ali',
        'name_search': 'ahmed ali',
        'phone': '03129876543',
        'created_at': nowMs,
        'updated_at': nowMs,
      });

      // Seed credit sale: total 250,000 paisa (Rs 2,500)
      await db.executor.insert('sales', {
        'id': 'sale_1',
        'shop_id': 'shop_1',
        'customer_id': 'cust_1',
        'receipt_no': 'R-0001',
        'sale_type': 'credit',
        'status': 'posted',
        'total_paisa': 250000,
        'created_at': nowMs,
      });

      // Seed repayment: 100,000 paisa (Rs 1,000)
      await db.executor.insert('payments', {
        'id': 'pay_1',
        'shop_id': 'shop_1',
        'customer_id': 'cust_1',
        'amount_paisa': 100000,
        'status': 'posted',
        'created_at': nowMs,
        'method': 'cash',
        'note': 'Partial repayment',
      });
    });

    tearDown(() => db.close());

    test('linkByPhoneNumber matches customer and creates active link', () async {
      final linkedCount = await repo.linkByPhoneNumber(
        customerUid: 'cust_user_99',
        phone: '03129876543',
      );

      expect(linkedCount, 1);

      // Subsequent call does not create duplicate
      final secondCall = await repo.linkByPhoneNumber(
        customerUid: 'cust_user_99',
        phone: '03129876543',
      );
      expect(secondCall, 0);
    });

    test('getLinkedShops returns shop with accurate outstanding balance', () async {
      final shops = await repo.getLinkedShops(
        customerUid: 'cust_user_99',
        phone: '03129876543',
      );

      expect(shops.length, 1);
      final shop = shops.first;
      expect(shop.shopName, 'Madina Super Store');
      expect(shop.customerName, 'Ahmed Ali');
      // Rs 2,500 - Rs 1,000 = Rs 1,500 (150,000 paisa)
      expect(shop.balance.paisa, 150000);
      expect(shop.balance.format(), 'Rs 1,500');
    });

    test('getShopLedger returns chronological ledger items', () async {
      final ledger = await repo.getShopLedger(
        shopId: 'shop_1',
        customerId: 'cust_1',
      );

      expect(ledger.length, 2);
      expect(ledger.any((i) => i.isSale && i.amount == const Money.rupees(2500)), isTrue);
      expect(ledger.any((i) => i.isPayment && i.amount == const Money.rupees(1000)), isTrue);
    });
  });
}
