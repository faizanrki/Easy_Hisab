import 'analytics_summary.dart';

abstract interface class AnalyticsRepository {
  /// Computes cash flow, collections, aging and top debtor insights.
  Future<AnalyticsReport> getAnalyticsReport(
    String shopId, {
    AnalyticsPeriod period = AnalyticsPeriod.thisMonth,
  });
}
