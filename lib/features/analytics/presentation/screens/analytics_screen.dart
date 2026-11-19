import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/domain/money.dart';
import '../../../shop/presentation/shop_providers.dart';
import '../../domain/analytics_summary.dart';
import '../analytics_providers.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  Future<void> _sendWhatsAppReminder(
    BuildContext context,
    String? phone,
    String customerName,
    Money balance,
    String shopName,
  ) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number recorded for customer.')),
      );
      return;
    }

    final cleanDigits = phone.replaceAll(RegExp(r'\D'), '');
    final internationalPhone = cleanDigits.startsWith('0')
        ? '92${cleanDigits.substring(1)}'
        : cleanDigits;

    final msg = Uri.encodeComponent(
      'Assalam-o-Alaikum $customerName, this is a friendly reminder from $shopName regarding your pending udhar balance of ${balance.format()}. JazakAllah khair!',
    );
    final url = Uri.parse('https://wa.me/$internationalPhone?text=$msg');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeShop = ref.watch(activeShopContextProvider);
    final selectedPeriod = ref.watch(selectedAnalyticsPeriodProvider);
    final reportAsync = ref.watch(analyticsReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Cash Flow'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Period Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SegmentedButton<AnalyticsPeriod>(
                segments: const [
                  ButtonSegment(
                    value: AnalyticsPeriod.today,
                    label: Text('Today'),
                  ),
                  ButtonSegment(
                    value: AnalyticsPeriod.thisWeek,
                    label: Text('Week'),
                  ),
                  ButtonSegment(
                    value: AnalyticsPeriod.thisMonth,
                    label: Text('Month'),
                  ),
                  ButtonSegment(
                    value: AnalyticsPeriod.allTime,
                    label: Text('All Time'),
                  ),
                ],
                selected: {selectedPeriod},
                onSelectionChanged: (set) {
                  ref
                      .read(selectedAnalyticsPeriodProvider.notifier)
                      .setPeriod(set.first);
                },
              ),
            ),

            // Content
            Expanded(
              child: reportAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(
                  child: Text('Error loading analytics: $err'),
                ),
                data: (report) {
                  if (report == null) {
                    return const Center(child: Text('No shop selected.'));
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // KPI Cards Row
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              title: 'Total Sales',
                              amount: report.metrics.totalSales,
                              color: theme.colorScheme.primaryContainer,
                              textColor: theme.colorScheme.onPrimaryContainer,
                              icon: Icons.trending_up_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MetricCard(
                              title: 'Cash Collected',
                              amount: report.metrics.cashCollected,
                              color: Colors.green.shade100,
                              textColor: Colors.green.shade900,
                              icon: Icons.payments_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _MetricCard(
                        title: 'Total Net Outstanding Udhar',
                        amount: report.metrics.outstandingUdhar,
                        color: theme.colorScheme.errorContainer,
                        textColor: theme.colorScheme.onErrorContainer,
                        icon: Icons.account_balance_wallet_rounded,
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'Udhar Aging Breakdown',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              for (final bucket in report.agingBuckets) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          bucket.label,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${bucket.customerCount} ${bucket.customerCount == 1 ? "customer" : "customers"}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        bucket.amount.format(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: bucket.amount.paisa > 0
                                              ? theme.colorScheme.error
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (bucket != report.agingBuckets.last)
                                  const Divider(height: 12),
                              ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Text(
                        'Top Customers by Udhar',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (report.topDebtors.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text('No customers with outstanding credit.'),
                          ),
                        )
                      else
                        Card(
                          child: Column(
                            children: [
                              for (final debtor in report.topDebtors) ...[
                                ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        theme.colorScheme.errorContainer,
                                    child: Text(
                                      debtor.customerName.isNotEmpty
                                          ? debtor.customerName[0].toUpperCase()
                                          : 'C',
                                      style: TextStyle(
                                        color: theme
                                            .colorScheme.onErrorContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    debtor.customerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    debtor.customerPhone ?? 'No phone recorded',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        debtor.balance.format(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (debtor.customerPhone != null &&
                                          debtor.customerPhone!.isNotEmpty)
                                        IconButton(
                                          icon: const Icon(
                                            Icons.chat_rounded,
                                            color: Color(0xFF25D366),
                                          ),
                                          tooltip: 'WhatsApp Reminder',
                                          onPressed: () =>
                                              _sendWhatsAppReminder(
                                            context,
                                            debtor.customerPhone,
                                            debtor.customerName,
                                            debtor.balance,
                                            activeShop?.shopName ?? 'Our Shop',
                                          ),
                                        ),
                                    ],
                                  ),
                                  onTap: () {
                                    context.push(
                                      '/shop/customers/${debtor.customerId}',
                                    );
                                  },
                                ),
                                if (debtor != report.topDebtors.last)
                                  const Divider(height: 1),
                              ],
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.textColor,
    required this.icon,
  });

  final String title;
  final Money amount;
  final Color color;
  final Color textColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: textColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            amount.format(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
