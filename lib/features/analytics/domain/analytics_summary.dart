import '../../../core/domain/money.dart';

enum AnalyticsPeriod {
  today,
  thisWeek,
  thisMonth,
  allTime,
}

class CashFlowMetrics {
  const CashFlowMetrics({
    required this.totalSales,
    required this.cashCollected,
    required this.outstandingUdhar,
  });

  final Money totalSales;
  final Money cashCollected;
  final Money outstandingUdhar;
}

class AgingBucket {
  const AgingBucket({
    required this.label,
    required this.amount,
    required this.customerCount,
  });

  final String label;
  final Money amount;
  final int customerCount;
}

class TopDebtor {
  const TopDebtor({
    required this.customerId,
    required this.customerName,
    this.customerPhone,
    required this.balance,
    this.lastPaymentDate,
  });

  final String customerId;
  final String customerName;
  final String? customerPhone;
  final Money balance;
  final DateTime? lastPaymentDate;
}

class AnalyticsReport {
  const AnalyticsReport({
    required this.period,
    required this.metrics,
    required this.agingBuckets,
    required this.topDebtors,
  });

  final AnalyticsPeriod period;
  final CashFlowMetrics metrics;
  final List<AgingBucket> agingBuckets;
  final List<TopDebtor> topDebtors;
}
