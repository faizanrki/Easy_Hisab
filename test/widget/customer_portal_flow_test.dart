import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:easy_hisab/app/app_router.dart';
import 'package:easy_hisab/app/dependency_providers.dart';
import 'package:easy_hisab/app/easy_hisab_app.dart';
import 'package:easy_hisab/core/database/local_database.dart';

void main() {
  sqfliteFfiInit();

  group('Module 09: Customer Portal Flow Tests (Token & Shop ID Only)', () {
    late LocalDatabase db;
    const shopId = 'a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d';
    const shopCode = 'SHOP-A1B2C3';
    const customerId = 'cust_1';
    const token = '849201';

    setUp(() async {
      db = await LocalDatabase.openAt(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );

      const nowMs = 1763560000000;
      // Seed shop
      await db.executor.insert('shops', {
        'id': shopId,
        'name': 'Madina Super Store',
        'contact_phone': '03001234567',
        'address': 'Main Market, Lahore',
        'created_at': nowMs,
        'updated_at': nowMs,
      });

      // Seed customer
      await db.executor.insert('customers', {
        'id': customerId,
        'shop_id': shopId,
        'name': 'Kashif Khan',
        'name_search': 'kashif khan',
        'phone': null,
        'created_at': nowMs,
        'updated_at': nowMs,
      });

      // Seed active token
      await db.executor.insert(
        'app_settings',
        {
          'key': 'active_token:$shopId:$customerId',
          'value': token,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.executor.insert(
        'app_settings',
        {
          'key': 'cust_token:$shopId:$token',
          'value': customerId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Seed credit sale: Rs 2,500
      await db.executor.insert('sales', {
        'id': 'sale_1',
        'shop_id': shopId,
        'customer_id': customerId,
        'receipt_no': 'R-0001',
        'sale_type': 'credit',
        'status': 'posted',
        'total_paisa': 250000,
        'created_at': nowMs,
      });

      // Seed repayment: Rs 1,000
      await db.executor.insert('payments', {
        'id': 'pay_1',
        'shop_id': shopId,
        'customer_id': customerId,
        'amount_paisa': 100000,
        'status': 'posted',
        'created_at': nowMs,
        'method': 'cash',
        'note': 'Partial cash repayment',
      });
    });

    tearDown(() => db.close());

    Future<void> settleAsync(WidgetTester tester) async {
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 50)),
        );
      }
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets(
        'customer enters Shop ID and Receipt Token and sees instant balance only',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDatabaseProvider.overrideWithValue(db),
          ],
          child: EasyHisabApp(
            key: UniqueKey(),
            initialLocation: AppRoutes.customerShops,
          ),
        ),
      );
      await settleAsync(tester);

      // Verify token lookup form is shown directly (no phone input)
      expect(find.text('Check Balance with Token'), findsOneWidget);
      expect(find.byKey(const Key('token_shop_code_field')), findsOneWidget);
      expect(find.byKey(const Key('token_code_field')), findsOneWidget);

      // Enter Shop ID and Receipt Token
      await tester.enterText(
        find.byKey(const Key('token_shop_code_field')),
        shopCode,
      );
      await tester.enterText(
        find.byKey(const Key('token_code_field')),
        token,
      );
      await tester.pump();

      // Tap Check My Balance
      await tester.tap(find.byKey(const Key('token_submit_button')));
      await settleAsync(tester);

      // Instant Balance Card is shown directly on screen
      expect(find.text('Madina Super Store'), findsOneWidget);
      expect(find.text('Customer: Kashif Khan'), findsOneWidget);
      expect(find.text('Outstanding Udhar Due'), findsOneWidget);
      expect(find.byKey(const Key('customer_instant_balance_text')),
          findsOneWidget);
      expect(find.text('Rs 1,500'), findsOneWidget);
      expect(find.text('WhatsApp Shopkeeper'), findsOneWidget);
      expect(find.byKey(const Key('check_another_token_button')),
          findsOneWidget);
    });
  });
}
