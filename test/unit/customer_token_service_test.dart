import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/features/customer_portal/application/customer_token_service.dart';

void main() {
  sqfliteFfiInit();

  group('CustomerTokenService & Shop Code Unit Tests', () {
    late LocalDatabase db;
    late CustomerTokenService service;

    setUp(() async {
      db = await LocalDatabase.openAt(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      service = CustomerTokenService(db);

      const nowMs = 1763560000000;
      await db.executor.insert('shops', {
        'id': 'b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e',
        'name': 'Bismillah Kiryana Store',
        'contact_phone': '03001234567',
        'address': 'Chowk Yadgar, Peshawar',
        'created_at': nowMs,
        'updated_at': nowMs,
      });

      await db.executor.insert('customers', {
        'id': 'cust_101',
        'shop_id': 'b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e',
        'name': 'Muhammad Tariq',
        'name_search': 'muhammad tariq',
        'phone': '03451122334',
        'created_at': nowMs,
        'updated_at': nowMs,
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('formatShopCode formats shop UUID into clean human-readable code', () {
      final code = CustomerTokenService.formatShopCode('b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e');
      expect(code, equals('SHOP-B1C2D3'));
    });

    test('rotateToken generates 6-digit code and invalidates older token', () async {
      const shopId = 'b1c2d3e4-f5a6-4b7c-8d9e-0f1a2b3c4d5e';
      const customerId = 'cust_101';

      // 1. Initial generation
      final token1 = await service.rotateToken(shopId: shopId, customerId: customerId);
      expect(token1.length, equals(6));

      final active1 = await service.getOrGenerateToken(shopId: shopId, customerId: customerId);
      expect(active1, equals(token1));

      // Resolve with token 1 succeeds
      final res1 = await service.resolve(shopCodeOrId: 'SHOP-B1C2D3', token: token1);
      expect(res1, isNotNull);
      expect(res1!.customerName, equals('Muhammad Tariq'));
      expect(res1.shopName, equals('Bismillah Kiryana Store'));

      // 2. Rotate token (new receipt posted)
      final token2 = await service.rotateToken(shopId: shopId, customerId: customerId);
      expect(token2.length, equals(6));

      // 3. Old token1 is now EXPIRED and returns null
      final expiredRes = await service.resolve(shopCodeOrId: 'SHOP-B1C2D3', token: token1);
      expect(expiredRes, isNull);

      // 4. New token2 resolves properly
      final res2 = await service.resolve(shopCodeOrId: 'B1C2D3', token: token2);
      expect(res2, isNotNull);
      expect(res2!.customerId, equals(customerId));
    });

    test('resolve returns null on nonexistent shop or wrong token', () async {
      final resBadShop = await service.resolve(shopCodeOrId: 'SHOP-999999', token: '123456');
      expect(resBadShop, isNull);

      final resBadToken = await service.resolve(
        shopCodeOrId: 'SHOP-B1C2D3',
        token: '000000',
      );
      expect(resBadToken, isNull);
    });
  });
}
