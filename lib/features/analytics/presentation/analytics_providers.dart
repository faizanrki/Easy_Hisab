import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependency_providers.dart';
import '../../shop/presentation/shop_providers.dart';
import '../data/sqlite_analytics_repository.dart';
import '../domain/analytics_repository.dart';
import '../domain/analytics_summary.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final db = ref.watch(dbTransactionProvider);
  return SqliteAnalyticsRepository(db);
});

class SelectedPeriodNotifier extends Notifier<AnalyticsPeriod> {
  @override
  AnalyticsPeriod build() => AnalyticsPeriod.thisMonth;

  void setPeriod(AnalyticsPeriod period) {
    state = period;
  }
}

final selectedAnalyticsPeriodProvider =
    NotifierProvider<SelectedPeriodNotifier, AnalyticsPeriod>(
  SelectedPeriodNotifier.new,
);

final analyticsReportProvider =
    FutureProvider.autoDispose<AnalyticsReport?>((ref) async {
  final activeShop = ref.watch(activeShopContextProvider);
  if (activeShop == null) return null;

  final period = ref.watch(selectedAnalyticsPeriodProvider);
  final repo = ref.watch(analyticsRepositoryProvider);

  return repo.getAnalyticsReport(activeShop.shopId, period: period);
});
