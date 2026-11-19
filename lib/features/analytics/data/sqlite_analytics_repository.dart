import '../../../core/database/db_transaction.dart';
import '../../../core/domain/money.dart';
import '../domain/analytics_repository.dart';
import '../domain/analytics_summary.dart';

class SqliteAnalyticsRepository implements AnalyticsRepository {
  const SqliteAnalyticsRepository(this._db);

  final DatabaseTransactionPort _db;

  int _calculatePeriodStart(AnalyticsPeriod period, DateTime now) {
    switch (period) {
      case AnalyticsPeriod.today:
        final start = DateTime(now.year, now.month, now.day);
        return start.millisecondsSinceEpoch;
      case AnalyticsPeriod.thisWeek:
        // Monday of current week
        final daysToSubtract = (now.weekday - 1);
        final monday = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: daysToSubtract));
        return monday.millisecondsSinceEpoch;
      case AnalyticsPeriod.thisMonth:
        final firstOfMonth = DateTime(now.year, now.month, 1);
        return firstOfMonth.millisecondsSinceEpoch;
      case AnalyticsPeriod.allTime:
        return 0;
    }
  }

  @override
  Future<AnalyticsReport> getAnalyticsReport(
    String shopId, {
    AnalyticsPeriod period = AnalyticsPeriod.thisMonth,
  }) async {
    final now = DateTime.now();
    final periodStartMs = _calculatePeriodStart(period, now);

    // 1. Total Sales in period
    final salesRes = await _db.executor.rawQuery(
      '''
      SELECT COALESCE(SUM(total_paisa), 0) as total
      FROM sales
      WHERE shop_id = ? AND status = 'posted' AND created_at >= ?
      ''',
      [shopId, periodStartMs],
    );
    final totalSalesPaisa = (salesRes.first['total'] as num?)?.toInt() ?? 0;

    // 2. Cash Collected in period
    final paymentsRes = await _db.executor.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_paisa), 0) as total
      FROM payments
      WHERE shop_id = ? AND status = 'posted' AND created_at >= ?
      ''',
      [shopId, periodStartMs],
    );
    final cashCollectedPaisa =
        (paymentsRes.first['total'] as num?)?.toInt() ?? 0;

    // 3. All-time Outstanding Udhar across all customers
    final allSalesRes = await _db.executor.rawQuery(
      '''
      SELECT COALESCE(SUM(total_paisa), 0) as total
      FROM sales
      WHERE shop_id = ? AND status = 'posted' AND sale_type = 'credit'
      ''',
      [shopId],
    );
    final allSalesPaisa = (allSalesRes.first['total'] as num?)?.toInt() ?? 0;

    final allPaymentsRes = await _db.executor.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_paisa), 0) as total
      FROM payments
      WHERE shop_id = ? AND status = 'posted'
      ''',
      [shopId],
    );
    final allPaymentsPaisa =
        (allPaymentsRes.first['total'] as num?)?.toInt() ?? 0;

    final outstandingUdharPaisa =
        (allSalesPaisa - allPaymentsPaisa).clamp(0, 1 << 62);

    // 4. Top Debtors
    final customers = await _db.executor.rawQuery(
      '''
      SELECT id, name, phone
      FROM customers
      WHERE shop_id = ? AND archived_at IS NULL
      ''',
      [shopId],
    );

    final debtors = <TopDebtor>[];
    int bucket0To15Paisa = 0;
    int bucket0To15Count = 0;
    int bucket16To30Paisa = 0;
    int bucket16To30Count = 0;
    int bucket31To60Paisa = 0;
    int bucket31To60Count = 0;
    int bucket60PlusPaisa = 0;
    int bucket60PlusCount = 0;

    for (final c in customers) {
      final custId = c['id'] as String;
      final custSales = await _db.executor.rawQuery(
        '''
        SELECT COALESCE(SUM(total_paisa), 0) as total
        FROM sales
        WHERE shop_id = ? AND customer_id = ? AND status = 'posted' AND sale_type = 'credit'
        ''',
        [shopId, custId],
      );
      final cSales = (custSales.first['total'] as num?)?.toInt() ?? 0;

      final custPayments = await _db.executor.rawQuery(
        '''
        SELECT COALESCE(SUM(amount_paisa), 0) as total, MAX(created_at) as last_pay
        FROM payments
        WHERE shop_id = ? AND customer_id = ? AND status = 'posted'
        ''',
        [shopId, custId],
      );
      final cPayments = (custPayments.first['total'] as num?)?.toInt() ?? 0;
      final lastPayMs = custPayments.first['last_pay'] as int?;

      final balancePaisa = cSales - cPayments;
      if (balancePaisa > 0) {
        debtors.add(
          TopDebtor(
            customerId: custId,
            customerName: c['name'] as String? ?? 'Customer',
            customerPhone: c['phone'] as String?,
            balance: Money.paisa(balancePaisa),
            lastPaymentDate: lastPayMs != null
                ? DateTime.fromMillisecondsSinceEpoch(lastPayMs, isUtc: true)
                : null,
          ),
        );

        // Calculate oldest unpaid bill date for aging
        final oldestBill = await _db.executor.rawQuery(
          '''
          SELECT MIN(created_at) as oldest_date
          FROM sales
          WHERE shop_id = ? AND customer_id = ? AND status = 'posted' AND sale_type = 'credit'
          ''',
          [shopId, custId],
        );
        final oldestMs = oldestBill.first['oldest_date'] as int?;
        if (oldestMs != null) {
          final ageDays = now
              .difference(DateTime.fromMillisecondsSinceEpoch(oldestMs, isUtc: true))
              .inDays;
          if (ageDays <= 15) {
            bucket0To15Paisa += balancePaisa;
            bucket0To15Count++;
          } else if (ageDays <= 30) {
            bucket16To30Paisa += balancePaisa;
            bucket16To30Count++;
          } else if (ageDays <= 60) {
            bucket31To60Paisa += balancePaisa;
            bucket31To60Count++;
          } else {
            bucket60PlusPaisa += balancePaisa;
            bucket60PlusCount++;
          }
        }
      }
    }

    // Sort debtors descending by balance
    debtors.sort((a, b) => b.balance.compareTo(a.balance));
    final topDebtors = debtors.take(5).toList();

    final agingBuckets = [
      AgingBucket(
        label: '0-15 Days',
        amount: Money.paisa(bucket0To15Paisa),
        customerCount: bucket0To15Count,
      ),
      AgingBucket(
        label: '16-30 Days',
        amount: Money.paisa(bucket16To30Paisa),
        customerCount: bucket16To30Count,
      ),
      AgingBucket(
        label: '31-60 Days',
        amount: Money.paisa(bucket31To60Paisa),
        customerCount: bucket31To60Count,
      ),
      AgingBucket(
        label: '60+ Days',
        amount: Money.paisa(bucket60PlusPaisa),
        customerCount: bucket60PlusCount,
      ),
    ];

    return AnalyticsReport(
      period: period,
      metrics: CashFlowMetrics(
        totalSales: Money.paisa(totalSalesPaisa),
        cashCollected: Money.paisa(cashCollectedPaisa),
        outstandingUdhar: Money.paisa(outstandingUdharPaisa),
      ),
      agingBuckets: agingBuckets,
      topDebtors: topDebtors,
    );
  }
}
