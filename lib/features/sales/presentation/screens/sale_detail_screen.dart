import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/app_router.dart';
import '../../../../core/domain/app_failure.dart';
import '../../../customers/customers_public.dart';
import '../../domain/sale.dart';
import '../sale_providers.dart';

class SaleDetailScreen extends ConsumerStatefulWidget {
  const SaleDetailScreen({super.key, required this.saleId});

  final String saleId;

  @override
  ConsumerState<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends ConsumerState<SaleDetailScreen> {
  bool _isReversing = false;

  Future<void> _reverseSale(Sale sale) async {
    final reasonController = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reverse Bill?'),
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
                hintText: 'e.g. Customer returned items, wrong entry',
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

    setState(() => _isReversing = true);

    try {
      final reverse = ref.read(reverseSaleUseCaseProvider);
      await reverse.execute(
        shopId: sale.shopId,
        saleId: sale.id,
        reason: reasonController.text,
      );

      final _ = ref.refresh(saleDetailProvider(sale.id));
      final _ = ref.refresh(recentSalesProvider);
      final _ = ref.refresh(customerSalesProvider(sale.customerId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill reversed successfully')),
        );
      }
    } on AppFailure catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isReversing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final saleAsync = ref.watch(saleDetailProvider(widget.saleId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(saleAsync.value?.receiptNo ?? 'Bill Detail'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.shopDashboard);
            }
          },
        ),
      ),
      body: saleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (sale) {
          if (sale == null) {
            return const Center(child: Text('Bill record not found'));
          }

          final customersAsync = ref.watch(customerListProvider);
          final customerName = customersAsync.maybeWhen(
            data: (list) {
              final c = list.where((item) => item.id == sale.customerId);
              return c.isNotEmpty ? c.first.name : 'Customer (${sale.customerId})';
            },
            orElse: () => 'Customer (${sale.customerId})',
          );

          final dateStr =
              DateFormat('dd MMM yyyy, hh:mm a').format(sale.createdAt.toLocal());

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Receipt Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            sale.receiptNo,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          _StatusChip(status: sale.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Date: $dateStr',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customer: $customerName',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Offline Sync Status indicator
                      Row(
                        children: [
                          Icon(
                            sale.syncStatus == SyncStatus.accepted
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_queue_outlined,
                            size: 16,
                            color: sale.syncStatus == SyncStatus.accepted
                                ? Colors.green
                                : Colors.amber.shade800,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sale.syncStatus == SyncStatus.accepted
                                ? 'Synced to Cloud'
                                : 'Offline (Pending Cloud Sync)',
                            style: TextStyle(
                              fontSize: 12,
                              color: sale.syncStatus == SyncStatus.accepted
                                  ? Colors.green
                                  : Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                      if (sale.note != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Note: ${sale.note!}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Line Items Table
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Itemized Purchased Products',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      ...sale.items.map((line) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      line.description,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${line.quantity.format()} ${line.unit} × ${line.unitPrice.format()}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  line.lineTotal.format(),
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Amount:',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            sale.total.format(),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Type:'),
                          Text(
                            sale.isCredit ? 'Credit (Udhar)' : 'Cash Paid',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: sale.isCredit ? Colors.red : Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 3. Actions: Share PDF receipt, Reverse Bill
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/shop/sales/${sale.id}/receipt'),
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Share Receipt'),
                    ),
                  ),
                  if (sale.isPosted) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          foregroundColor: Colors.red.shade800,
                        ),
                        onPressed: _isReversing ? null : () => _reverseSale(sale),
                        icon: const Icon(Icons.history_toggle_off_rounded),
                        label: const Text('Reverse Bill'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final SaleStatus status;

  @override
  Widget build(BuildContext context) {
    final isReversed = status == SaleStatus.reversed;
    return Chip(
      avatar: Icon(
        isReversed ? Icons.cancel_outlined : Icons.check_circle_outline,
        size: 16,
        color: isReversed ? Colors.red : Colors.green,
      ),
      label: Text(
        isReversed ? 'Reversed' : 'Posted',
        style: TextStyle(
          color: isReversed ? Colors.red.shade900 : Colors.green.shade900,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: isReversed ? Colors.red.shade50 : Colors.green.shade50,
      visualDensity: VisualDensity.compact,
    );
  }
}
