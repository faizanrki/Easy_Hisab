import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
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
            onRefresh: () => ref.read(activeShopProvider.notifier).reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ShopHeaderCard(shop: shop),
                const SizedBox(height: 16),
                _QuickActionsGrid(),
                const SizedBox(height: 16),
                _RecentActivityPlaceholder(),
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
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shop.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Edit Profile',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push(AppRoutes.shopEdit),
                ),
              ],
            ),
            if (shop.contactPhone != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.phone_outlined,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(shop.contactPhone!, style: theme.textTheme.bodyMedium),
                ],
              ),
            ],
            if (shop.address != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      shop.address!,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.people_alt_outlined,
                label: 'Customers',
                subtitle: 'Manage khata',
                onTap: () => context.push(AppRoutes.customerList),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.inventory_2_outlined,
                label: 'Products',
                subtitle: 'Grocery catalog',
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
                icon: Icons.point_of_sale_rounded,
                label: 'New Bill',
                subtitle: 'Credit / Paid sale',
                onTap: () => context.push(AppRoutes.saleNew),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.payments_outlined,
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
                icon: Icons.insights_rounded,
                label: 'Analytics',
                subtitle: 'Cash flow & exposure',
                onTap: () => context.push(AppRoutes.analytics),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionTile(
                icon: Icons.backup_outlined,
                label: 'Backup & Safety',
                subtitle: 'Export & integrity check',
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
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(icon,
                    size: 22, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ledger Overview',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'No bills or payments recorded yet. After adding customers and sales, your daily udhar summary and recent activity will appear here.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
