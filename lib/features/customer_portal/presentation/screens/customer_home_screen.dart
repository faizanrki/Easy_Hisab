import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
import '../../../../core/domain/money.dart';
import '../customer_portal_providers.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _linkPhone() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    ref.read(customerPhoneNumberProvider.notifier).setPhone(phone);
    ref.invalidate(linkedShopsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shopsAsync = ref.watch(linkedShopsProvider);
    final activePhone = ref.watch(customerPhoneNumberProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shops'),
        leading: IconButton(
          tooltip: 'Change role',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.chooseRole),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Phone Link / Search Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: activePhone ?? 'Enter phone (e.g. 03001234567)',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _linkPhone,
                    icon: const Icon(Icons.search_rounded),
                    tooltip: 'Find Shops',
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: shopsAsync.when(
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
                        Text('Error loading shops: $err'),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => ref.invalidate(linkedShopsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (shops) {
                  if (shops.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.storefront_outlined,
                              size: 64,
                              color: theme.colorScheme.primary.withValues(alpha: 0.7),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Connected Shops Yet',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              activePhone == null
                                  ? 'Enter your mobile number above to find your account across local grocery shops.'
                                  : 'No accounts found for "$activePhone". Ask your shopkeeper to record your phone number on your customer file.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Compute aggregate total outstanding
                  final totalDuePaisa = shops.fold<int>(
                    0,
                    (sum, s) => sum + s.balance.paisa,
                  );
                  final totalDue = Money.paisa(totalDuePaisa);

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Total balance header card
                      Card(
                        color: totalDuePaisa > 0
                            ? theme.colorScheme.errorContainer
                            : theme.colorScheme.primaryContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                totalDuePaisa > 0
                                    ? 'Total Outstanding Udhar'
                                    : 'All Accounts Cleared',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: totalDuePaisa > 0
                                      ? theme.colorScheme.onErrorContainer
                                      : theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                totalDue.format(),
                                style:
                                    theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: totalDuePaisa > 0
                                      ? theme.colorScheme.onErrorContainer
                                      : theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Across ${shops.length} linked ${shops.length == 1 ? "shop" : "shops"}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: totalDuePaisa > 0
                                      ? theme.colorScheme.onErrorContainer
                                      : theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Your Shops', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      for (final shop in shops)
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor:
                                  theme.colorScheme.secondaryContainer,
                              child: Icon(
                                Icons.store_rounded,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                            title: Text(
                              shop.shopName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (shop.shopAddress != null &&
                                    shop.shopAddress!.isNotEmpty)
                                  Text(shop.shopAddress!),
                                Text(
                                  'Registered name: ${shop.customerName}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  shop.balance.format(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: shop.balance.paisa > 0
                                        ? theme.colorScheme.error
                                        : Colors.green,
                                  ),
                                ),
                                Text(
                                  shop.balance.paisa > 0 ? 'Due' : 'Cleared',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            onTap: () {
                              context.push(
                                '/customer/shops/${shop.shopId}/ledger?customerId=${shop.customerId}&shopName=${Uri.encodeComponent(shop.shopName)}&phone=${shop.shopPhone ?? ""}',
                              );
                            },
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
