import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:easy_hisab/core/database/local_database.dart';
import 'package:easy_hisab/core/domain/money.dart';
import 'package:easy_hisab/features/analytics/data/sqlite_analytics_repository.dart';
import 'package:easy_hisab/features/analytics/domain/analytics_summary.dart';

void main() {
  sqfliteFfiInit();

  group('Module 11: SqliteAnalyticsRepository Unit Tests', () {
    late LocalDatabase db;
    late SqliteAnalyticsRepository repo;
    const shopId = 'shop_analytics_1';

    setUp(() async {
      db = await LocalDatabase.openAt(
        inMemoryDatabasePath,
        factory: databaseFactoryFfi,
      );
      repo = SqliteAnalyticsRepository(db);

      final now = DateTime.now();
      final nowMs = now.millisecondsSinceEpoch;

      // Seed shop
      await db.executor.insert('shops', {
        'id': shopId,
        'name': 'Analytics Test Shop',
        'contact_phone': '03001234567',
        'address': 'Main Market',
        'created_at': nowMs,
        'updated_at': nowMs,
      });

      // Customer 1: Ali (owes Rs 3,000)
      await db.executor.insert('customers', {
        'id': 'cust_1',
        'shop_id': shopId,
        'name': 'Ali Khan',
        'name_search': 'ali khan',
        'phone': '03001111111',
        'created_at': nowMs,
        'updated_at': nowMs,
      });

      // Customer 2: Bilal (owes Rs 1,000)
      await db.executor.insert('customers', {
        'id': 'cust_2',
        'shop_id': shopId,
        'name': 'Bilal Ahmed',
        'name_search': 'bilal ahmed',
        'phone': '03002222222',
        'created_at': nowMs,
        'updated_at': nowMs,
      });

      // Sale 1 for Ali: Rs 5,000 credit sale
      await db.executor.insert('sales', {
        'id': 'sale_1',
        'shop_id': shopId,
        'customer_id': 'cust_1',
        'receipt_no': 'R-0001',
        'sale_type': 'credit',
        'status': 'posted',
        'total_paisa': 500000,
        'created_at': nowMs,
      });

      // Payment from Ali: Rs 2,000 cash repayment
      await db.executor.insert('payments', {
        'id': 'pay_1',
        'shop_id': shopId,
        'customer_id': 'cust_1',
        'amount_paisa': 200000,
        'status': 'posted',
        'created_at': nowMs,
        'method': 'cash',
      });

      // Sale 2 for Bilal: Rs 1,000 credit sale
      await db.executor.insert('sales', {
        'id': 'sale_2',
        'shop_id': shopId,
        'customer_id': 'cust_2',
        'receipt_no': 'R-0002',
        'sale_type': 'credit',
        'status': 'posted',
        'total_paisa': 100000,
        'created_at': nowMs,
      });
    });

    tearDown(() => db.close());

    test('computes cash flow metrics accurately', () async {
      final report = await repo.getAnalyticsReport(
        shopId,
        period: AnalyticsPeriod.allTime,
      );

      // Total sales = 500,000 + 100,000 = 600,000 paisa (Rs 6,000)
      expect(report.metrics.totalSales, const Money.rupees(6000));
      // Cash collected = 200,000 paisa (Rs 2,000)
      expect(report.metrics.cashCollected, const Money.rupees(2000));
      // Net outstanding udhar = 6,000 - 2,000 = Rs 4,000
      expect(report.metrics.outstandingUdhar, const Money.rupees(4000));
    });

    test('ranks top debtors correctly descending by balance', () async {
      final report = await repo.getAnalyticsReport(
        shopId,
        period: AnalyticsPeriod.allTime,
      );

      expect(report.topDebtors.length, 2);
      // Ali owes Rs 3,000 (5,000 - 2,000)
      expect(report.topDebtors.first.customerName, 'Ali Khan');
      expect(report.topDebtors.first.balance, const Money.rupees(3000));

      // Bilal owes Rs 1,000
      expect(report.topDebtors[1].customerName, 'Bilal Ahmed');
      expect(report.topDebtors[1].balance, const Money.rupees(1000));
    });

    test('categorizes aging buckets for recent debts into 0-15 days', () async {
      final report = await repo.getAnalyticsReport(
        shopId,
        period: AnalyticsPeriod.allTime,
      );

      final bucket0To15 = report.agingBuckets.firstWhere((b) => b.label == '0-15 Days');
      expect(bucket0To15.customerCount, 2);
      expect(bucket0To15.amount, const Money.rupees(4000));
    });
  });
}
