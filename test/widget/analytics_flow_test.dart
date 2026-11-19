import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:easy_hisab/app/app_router.dart';
import 'package:easy_hisab/app/dependency_providers.dart';
import 'package:easy_hisab/app/easy_hisab_app.dart';
import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/entity_id.dart';
import 'package:easy_hisab/features/shop/data/sqlite_shop_repository.dart';
import 'package:easy_hisab/features/shop/domain/shop.dart';

void main() {
  sqfliteFfiInit();

  group('Module 11: Analytics Flow Widget Tests', () {
    late LocalDatabase db;
    const idGen = UuidIdGenerator();
    const shopId = 'shop_analytics_widget';

    setUp(() async {
      db = await LocalDatabase.openAt(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );

      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      // Seed active shop
      final shopRepo = SqliteShopRepository(db, idGen);
      await shopRepo.createAndActivate(
        Shop(
          id: shopId,
          details: ShopDetails.create(name: 'Al-Madina Store'),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Seed customer with credit debt
      await db.executor.insert('customers', {
        'id': 'cust_1',
        'shop_id': shopId,
        'name': 'Usman Ghani',
        'name_search': 'usman ghani',
        'phone': '03001234567',
        'created_at': nowMs,
        'updated_at': nowMs,
      });

      // Credit sale: Rs 4,000
      await db.executor.insert('sales', {
        'id': 'sale_1',
        'shop_id': shopId,
        'customer_id': 'cust_1',
        'receipt_no': 'R-0001',
        'sale_type': 'credit',
        'status': 'posted',
        'total_paisa': 400000,
        'created_at': nowMs,
      });

      // Repayment: Rs 1,500
      await db.executor.insert('payments', {
        'id': 'pay_1',
        'shop_id': shopId,
        'customer_id': 'cust_1',
        'amount_paisa': 150000,
        'status': 'posted',
        'created_at': nowMs,
        'method': 'cash',
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
      await tester.pumpAndSettle();
    }

    testWidgets('displays cash flow KPIs, aging breakdown, and top debtor with reminder', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localDatabaseProvider.overrideWithValue(db),
          ],
          child: const EasyHisabApp(initialLocation: AppRoutes.analytics),
        ),
      );
      await settleAsync(tester);

      // Verify screen title
      expect(find.text('Analytics & Cash Flow'), findsOneWidget);

      // Verify KPI metrics
      expect(find.text('Total Sales'), findsOneWidget);
      expect(find.text('Cash Collected'), findsOneWidget);
      expect(find.text('Total Net Outstanding Udhar'), findsOneWidget);

      // Total Sales = Rs 4,000
      expect(find.text('Rs 4,000'), findsOneWidget);
      // Cash Collected = Rs 1,500
      expect(find.text('Rs 1,500'), findsOneWidget);
      // Outstanding Udhar = Rs 2,500
      expect(find.text('Rs 2,500'), findsAtLeastNWidgets(1));

      // Verify Udhar Aging breakdown
      expect(find.text('Udhar Aging Breakdown'), findsOneWidget);
      expect(find.text('0-15 Days'), findsOneWidget);

      // Scroll down to see Top Debtors
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await settleAsync(tester);

      // Verify Top Debtors list
      expect(find.text('Top Customers by Udhar'), findsOneWidget);
      expect(find.text('Usman Ghani'), findsOneWidget);
      expect(find.byTooltip('WhatsApp Reminder'), findsOneWidget);
    });
  });
}
