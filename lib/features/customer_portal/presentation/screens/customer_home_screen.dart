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
            if (activePhone != null) ...[
              // Secure Verified Customer Account Banner
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_user_rounded,
                          size: 20, color: Colors.green),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verified Customer Account',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                          Text(
                            activePhone,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          context.push('${AppRoutes.phoneLogin}?role=customer'),
                      icon: const Icon(Icons.switch_account_outlined, size: 16),
                      label: const Text('Switch', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Fallback for unauthenticated guest / testing
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: theme.colorScheme.surfaceContainerHighest,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Enter phone (e.g. 03001234567)',
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
            ],

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
                              activePhone == null
                                  ? 'No Connected Shops Yet'
                                  : 'No Khata Records Found',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              activePhone == null
                                  ? 'Enter your mobile number above to find stores where you have an active udhar khata.'
                                  : 'No shops have recorded credit or transactions for $activePhone yet.',
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

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: shops.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = shops[index];
                      final isDue = item.balance.paisa > 0;
                      final isAdvance = item.balance.paisa < 0;

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: theme.colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            final phoneParam = item.shopPhone != null
                                ? '&phone=${Uri.encodeComponent(item.shopPhone!)}'
                                : '';
                            context.push(
                              '/customer/shops/${item.shopId}/ledger?customerId=${item.customerId}&shopName=${Uri.encodeComponent(item.shopName)}$phoneParam',
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  child: Icon(
                                    Icons.storefront_rounded,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.shopName,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (item.shopPhone != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          item.shopPhone!,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        'Customer: ${item.customerName}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      Money.paisa(item.balance.paisa.abs()).format(),
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isDue
                                            ? theme.colorScheme.error
                                            : isAdvance
                                                ? Colors.green
                                                : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    Text(
                                      isDue
                                          ? 'You owe'
                                          : isAdvance
                                              ? 'Advance'
                                              : 'Settled',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isDue
                                            ? theme.colorScheme.error
                                            : isAdvance
                                                ? Colors.green
                                                : theme.colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
