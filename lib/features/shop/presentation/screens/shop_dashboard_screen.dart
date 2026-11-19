import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_router.dart';
import '../../../analytics/domain/analytics_summary.dart';
import '../../../analytics/presentation/analytics_providers.dart';
import '../../../sync/domain/sync_operation.dart';
import '../../../sync/presentation/sync_providers.dart';
import '../../domain/shop.dart';
import '../shop_providers.dart';

class ShopDashboardScreen extends ConsumerWidget {
  const ShopDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeShopAsync = ref.watch(activeShopProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: activeShopAsync.maybeWhen(
          data: (shop) => Text(shop?.name ?? 'Shop Dashboard'),
          orElse: () => const Text('Shop Dashboard'),
        ),
        leading: IconButton(
          tooltip: 'Switch Role',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.chooseRole),
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final syncState = ref.watch(syncStatusProvider);
              final pendingCount = ref.watch(pendingSyncCountProvider).value ?? 0;
              final shop = activeShopAsync.value;

              return IconButton(
                tooltip: syncState == SyncState.syncing
                    ? 'Syncing...'
                    : pendingCount > 0
                        ? '$pendingCount pending changes. Tap to sync.'
                        : 'Cloud Synced',
                icon: syncState == SyncState.syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        pendingCount > 0
                            ? Icons.sync_problem_rounded
                            : Icons.cloud_done_outlined,
                      ),
                onPressed: shop != null && syncState != SyncState.syncing
                    ? () async {
                        await ref
                            .read(syncStatusProvider.notifier)
                            .triggerSync(shop.id);
                      }
                    : null,
              );
            },
          ),
          IconButton(
            tooltip: 'Analytics & Insights',
            icon: const Icon(Icons.insights_rounded),
            onPressed: () => context.push(AppRoutes.analytics),
          ),
          IconButton(
            tooltip: 'Shop Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              final shop = activeShopAsync.value;
              if (shop != null) {
                context.push(AppRoutes.shopEdit);
              }
            },
          ),
        ],
      ),
      body: activeShopAsync.when(
        loading: () => const Center(child: SizedBox(width: 24, height: 24)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text('Failed to load shop: $err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      ref.read(activeShopProvider.notifier).reload(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (shop) {
          if (shop == null) {
            return _EmptyShopView(
              onSetup: () => context.go(AppRoutes.shopSetup),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(activeShopProvider.notifier).reload();
              ref.invalidate(analyticsReportProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ShopHeaderCard(shop: shop),
                const SizedBox(height: 16),
                const _DigitalFinancialOverview(),
                const SizedBox(height: 16),
                _QuickActionsGrid(),
                const SizedBox(height: 16),
                const _LiveDebtorFeed(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyShopView extends StatelessWidget {
  const _EmptyShopView({required this.onSetup});

  final VoidCallback onSetup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.storefront_rounded,
                size: 42,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Shop Configured Yet',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Set up your grocery shop name and contact details to begin keeping track of customer udhar.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onSetup,
              icon: const Icon(Icons.add_business_rounded),
              label: const Text('Set Up Shop Now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopHeaderCard extends StatelessWidget {
  const _ShopHeaderCard({required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.storefront_rounded,
                      color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        shop.contactPhone ?? 'No phone recorded',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (shop.address != null && shop.address!.isNotEmpty)
                        Text(
                          shop.address!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit Profile',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push(AppRoutes.shopEdit),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Chip(
              avatar: const Icon(Icons.info_outline, size: 16),
              label: Text(
                shop.businessVerification == BusinessVerification.unverified
                    ? 'Local store (unverified)'
                    : 'Verified store',
              ),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

/// Digital KPI Cards (Total Udhar vs Cash Collected)
class _DigitalFinancialOverview extends ConsumerWidget {
  const _DigitalFinancialOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(analyticsReportProvider);

    return reportAsync.maybeWhen(
      data: (report) {
        final udharDue = report?.metrics.outstandingUdhar.format() ?? 'Rs 0';
        final cashIn = report?.metrics.cashCollected.format() ?? 'Rs 0';

        return Row(
          children: [
            Expanded(
              child: _KpiMetricCard(
                title: 'Total Udhar',
                amount: udharDue,
                subtitle: 'Due from Customers',
                icon: Icons.trending_up_rounded,
                color: Colors.red.shade700,
                backgroundColor: Colors.red.shade50,
                onTap: () => context.push(AppRoutes.analytics),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KpiMetricCard(
                title: 'Cash Wasool',
                amount: cashIn,
                subtitle: 'Collected this month',
                icon: Icons.trending_down_rounded,
                color: Colors.green.shade700,
                backgroundColor: Colors.green.shade50,
                onTap: () => context.push(AppRoutes.analytics),
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox(height: 80),
    );
  }
}

class _KpiMetricCard extends StatelessWidget {
  const _KpiMetricCard({
    required this.title,
    required this.amount,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.onTap,
  });

  final String title;
  final String amount;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Icon(icon, size: 18, color: color),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                amount,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.8),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.point_of_sale_rounded,
                iconColor: Colors.deepPurple,
                label: 'New Bill',
                subtitle: 'Credit / Paid sale',
                onTap: () => context.push(AppRoutes.saleNew),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.payments_rounded,
                iconColor: Colors.teal,
                label: 'Receive Money',
                subtitle: 'Record repayment',
                onTap: () => context.push(AppRoutes.paymentNew),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.people_alt_rounded,
                iconColor: Colors.blue,
                label: 'Customers',
                subtitle: 'Customer ledgers',
                onTap: () => context.push(AppRoutes.customerList),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.inventory_2_rounded,
                iconColor: Colors.orange,
                label: 'Products',
                subtitle: 'Catalog & prices',
                onTap: () => context.push(AppRoutes.productList),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.insights_rounded,
                iconColor: Colors.indigo,
                label: 'Analytics',
                subtitle: 'Cash flow & insights',
                onTap: () => context.push(AppRoutes.analytics),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.backup_rounded,
                iconColor: Colors.green,
                label: 'Backup & Safety',
                subtitle: 'Export & verify',
                onTap: () => context.push(AppRoutes.backup),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dynamic Live Activity & Debtor Feed
class _LiveDebtorFeed extends ConsumerWidget {
  const _LiveDebtorFeed();

  Future<void> _sendWhatsAppReminder(BuildContext context, TopDebtor debtor) async {
    final phone = debtor.customerPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number recorded for this customer.')),
      );
      return;
    }

    final message = Uri.encodeComponent(
      'Assalam-o-Alaikum ${debtor.customerName},\n'
      'Aap ki taraf EasyHisab par total baqaya udhar ${debtor.balance.format()} hai.\n'
      'Baraye meherbani jald az jald ada farmayein. Shukriya!',
    );

    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-]'), '');
    final uri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$message');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(
          Uri.parse('https://wa.me/$cleanPhone?text=$message'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(analyticsReportProvider);
    final theme = Theme.of(context);

    return reportAsync.maybeWhen(
      data: (report) {
        final debtors = report?.topDebtors ?? [];
        if (debtors.isEmpty) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline_rounded,
                          size: 20, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      const Text(
                        'Live Ledger Activity',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'All customer accounts are clear, or no credit sales have been recorded yet. Create a bill to begin tracking udhar.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Top Customer Udhar',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => context.push(AppRoutes.analytics),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...debtors.take(3).map((debtor) {
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      debtor.customerName.isNotEmpty
                          ? debtor.customerName[0].toUpperCase()
                          : 'C',
                      style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    debtor.customerName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    debtor.customerPhone ?? 'No phone',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        debtor.balance.format(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Send WhatsApp Reminder',
                        icon: const Icon(Icons.send_rounded,
                            color: Color(0xFF25D366), size: 20),
                        onPressed: () =>
                            _sendWhatsAppReminder(context, debtor),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
