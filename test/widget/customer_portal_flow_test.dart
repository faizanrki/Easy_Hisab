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

  group('Module 09: Customer Portal Flow Tests', () {
    late LocalDatabase db;

    setUp(() async {
      db = await LocalDatabase.openAt(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );

      const nowMs = 1763560000000;
      // Seed shop
      await db.executor.insert('shops', {
        'id': 'shop_1',
        'name': 'Madina Super Store',
        'contact_phone': '03001234567',
        'address': 'Main Market, Lahore',
        'created_at': nowMs,
        'updated_at': nowMs,
      });

      // Seed customer with phone 03009988776
      await db.executor.insert('customers', {
        'id': 'cust_1',
        'shop_id': 'shop_1',
        'name': 'Kashif Khan',
        'name_search': 'kashif khan',
        'phone': '03009988776',
        'created_at': nowMs,
        'updated_at': nowMs,
      });

      // Seed credit sale: Rs 2,500
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

      // Seed repayment: Rs 1,000
      await db.executor.insert('payments', {
        'id': 'pay_1',
        'shop_id': 'shop_1',
        'customer_id': 'cust_1',
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

    testWidgets('customer enters phone, views linked shop balance, and inspects ledger', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDatabaseProvider.overrideWithValue(db),
          ],
          child: EasyHisabApp(key: UniqueKey(), initialLocation: AppRoutes.customerShops),
        ),
      );
      await settleAsync(tester);

      // Verify empty state initially
      expect(find.text('No Connected Shops Yet'), findsOneWidget);

      // Enter phone number
      await tester.enterText(find.byType(TextField), '03009988776');
      await tester.pump();

      // Tap Find Shops
      await tester.tap(find.byTooltip('Find Shops'));
      await settleAsync(tester);

      // Shop found: "Madina Super Store"
      expect(find.text('Madina Super Store'), findsOneWidget);
      // Net due Rs 1,500
      expect(find.text('Rs 1,500'), findsAtLeastNWidgets(1));

      // Tap shop card to open ledger
      await tester.tap(find.text('Madina Super Store'));
      await settleAsync(tester);

      // Verify on CustomerShopLedgerScreen
      expect(find.text('Madina Super Store'), findsOneWidget);
      expect(find.text('Outstanding Udhar'), findsOneWidget);
      expect(find.text('Bill #R-0001'), findsOneWidget);
      expect(find.text('Partial cash repayment'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
    });
  });
}
