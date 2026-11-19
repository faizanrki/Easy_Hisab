import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shop/shop_public.dart';
import '../../domain/customer.dart';
import '../customer_providers.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});

  final String customerId;

  Future<void> _toggleArchive(
    BuildContext context,
    WidgetRef ref,
    Customer customer,
  ) async {
    final shouldArchive = !customer.isArchived;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(shouldArchive ? 'Archive Customer?' : 'Unarchive Customer?'),
        content: Text(
          shouldArchive
              ? 'Archiving hides the customer from active lists, but keeps their complete bill and payment history intact.'
              : 'Restore this customer to the active khata list?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(shouldArchive ? 'Archive' : 'Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final shop = ref.read(activeShopContextProvider);
    if (shop == null) return;

    final archiveUseCase = ref.read(archiveCustomerUseCaseProvider);
    await archiveUseCase.execute(
      shopId: shop.shopId,
      customerId: customer.id,
      archive: shouldArchive,
    );

    final _ = ref.refresh(customerDetailProvider(customerId));
    final _ = ref.refresh(customerListProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldArchive
                ? 'Customer archived (history preserved)'
                : 'Customer restored to active list',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(customerId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/shop/customers/$customerId/edit'),
          ),
        ],
      ),
      body: customerAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (customer) {
          if (customer == null) {
            return const Center(child: Text('Customer not found'));
          }

          final initial =
              customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: customer.isArchived
                            ? Colors.grey.shade400
                            : theme.colorScheme.primaryContainer,
                        child: Text(
                          initial,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: customer.isArchived
                                ? Colors.white
                                : theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        customer.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (customer.isArchived) ...[
                        const SizedBox(height: 6),
                        const Chip(
                          label: Text('Archived Customer'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      if (customer.phone != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.phone_outlined,
                              color: theme.colorScheme.primary),
                          title: const Text('Phone Number'),
                          subtitle: Text(customer.phone!),
                        ),
                      if (customer.email != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.email_outlined,
                              color: theme.colorScheme.primary),
                          title: const Text('Email'),
                          subtitle: Text(customer.email!),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Outstanding Udhar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Rs 0',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Billing & repayments ledger will attach here in Module 05 & 06.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _toggleArchive(context, ref, customer),
                      icon: Icon(
                        customer.isArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                      ),
                      label: Text(
                        customer.isArchived ? 'Restore' : 'Archive',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Billing & sales module (Module 05) next',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.point_of_sale_rounded),
                      label: const Text('New Bill'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
