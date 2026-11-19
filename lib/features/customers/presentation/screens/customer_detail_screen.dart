import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/app_router.dart';
import '../../../../core/domain/app_failure.dart';
import '../../../../core/domain/money.dart';
import '../../../payments/payments_public.dart';
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

    final archiveCustomer = ref.read(archiveCustomerUseCaseProvider);
    await archiveCustomer.execute(
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

  Future<void> _reversePayment(
    BuildContext context,
    WidgetRef ref,
    String shopId,
    String paymentId,
  ) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reverse Payment?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reversing preserves an auditable cancellation trail. Posted records are never deleted.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for reversal *',
                hintText: 'e.g. Wrong entry, duplicate receipt',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Reversal'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final reverse = ref.read(paymentRepositoryProvider);
      await reverse.reversePayment(
        shopId,
        paymentId,
        reason: reasonController.text,
        reversedAt: DateTime.now().toUtc(),
      );
      final _ = ref.refresh(customerBalanceProvider(customerId));
      final _ = ref.refresh(customerLedgerProvider(customerId));
      final _ = ref.refresh(recentPaymentsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment reversed successfully')),
        );
      }
    } on AppFailure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(customerId));
    final balanceAsync = ref.watch(customerBalanceProvider(customerId));
    final ledgerAsync = ref.watch(customerLedgerProvider(customerId));
    final shop = ref.watch(activeShopContextProvider);
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
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: customer.isArchived
                                ? Colors.grey.shade700
                                : theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
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

              // Outstanding Udhar Card
              Card(
                color: theme.colorScheme.surface,
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
                          balanceAsync.when(
                            data: (bal) => Text(
                              bal.format(),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: bal > Money.zero
                                    ? Colors.red.shade800
                                    : Colors.green.shade800,
                              ),
                            ),
                            loading: () => const Text('...'),
                            error: (_, _) => const Text('Error'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total credit bills minus recorded repayments.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons: New Bill and Receive Payment
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.push(
                        '${AppRoutes.saleNew}?customerId=${customer.id}',
                      ),
                      icon: const Icon(Icons.point_of_sale_rounded),
                      label: const Text('New Bill'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => context.push(
                        '${AppRoutes.paymentNew}?customerId=${customer.id}',
                      ),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Receive Payment'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
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
              const SizedBox(height: 24),

              // Khata Ledger Timeline
              Text(
                'Khata Ledger Timeline',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              ledgerAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, _) => Text('Error loading ledger: $err'),
                data: (entries) {
                  if (entries.isEmpty) {
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.history_edu_outlined,
                                size: 40,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 8),
                              const Text('No transactions yet'),
                              const SizedBox(height: 4),
                              Text(
                                'Post a credit bill or record a payment to view ledger.',
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

                  return Column(
                    children: entries.map((entry) {
                      final isSale = entry.type == LedgerEntryType.sale;
                      final dateStr = DateFormat('dd MMM yyyy, hh:mm a')
                          .format(entry.date.toLocal());

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: entry.isReversed
                                ? Colors.grey.shade200
                                : isSale
                                    ? Colors.red.shade50
                                    : Colors.green.shade50,
                            child: Icon(
                              isSale
                                  ? Icons.receipt_long_outlined
                                  : Icons.payments_outlined,
                              color: entry.isReversed
                                  ? Colors.grey
                                  : isSale
                                      ? Colors.red.shade800
                                      : Colors.green.shade800,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            entry.description,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: entry.isReversed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dateStr, style: theme.textTheme.bodySmall),
                              if (entry.isReversed)
                                const Text(
                                  'REVERSED',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                )
                              else
                                Text(
                                  'Balance: ${entry.runningBalance.format()}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Text(
                            isSale
                                ? '+ ${entry.debit.format()}'
                                : '- ${entry.credit.format()}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: entry.isReversed
                                  ? Colors.grey
                                  : isSale
                                      ? Colors.red.shade800
                                      : Colors.green.shade800,
                              decoration: entry.isReversed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          onTap: () {
                            if (isSale) {
                              context.push('/shop/sales/${entry.id}');
                            } else if (!entry.isReversed && shop != null) {
                              _reversePayment(
                                context,
                                ref,
                                shop.shopId,
                                entry.id,
                              );
                            }
                          },
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
