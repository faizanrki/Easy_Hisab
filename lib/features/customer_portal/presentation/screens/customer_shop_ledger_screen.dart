import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/domain/money.dart';
import '../customer_portal_providers.dart';

class CustomerShopLedgerScreen extends ConsumerWidget {
  const CustomerShopLedgerScreen({
    super.key,
    required this.shopId,
    required this.customerId,
    this.shopName = 'Shop Ledger',
    this.shopPhone,
  });

  final String shopId;
  final String customerId;
  final String shopName;
  final String? shopPhone;

  Future<void> _launchWhatsApp(BuildContext context, Money balance) async {
    if (shopPhone == null || shopPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop phone number not provided.')),
      );
      return;
    }

    final cleanPhone = shopPhone!.replaceAll(RegExp(r'\D'), '');
    final internationalPhone = cleanPhone.startsWith('0')
        ? '92${cleanPhone.substring(1)}'
        : cleanPhone;

    final msg = Uri.encodeComponent(
      'Assalam-o-Alaikum, I am inquiring about my EasyHisab account at $shopName. Current balance: ${balance.format()}.',
    );
    final url = Uri.parse('https://wa.me/$internationalPhone?text=$msg');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ledgerAsync = ref.watch(
      customerShopLedgerProvider((shopId: shopId, customerId: customerId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(shopName),
      ),
      body: ledgerAsync.when(
        loading: () => const Center(child: SizedBox(width: 24, height: 24)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (items) {
          // Calculate balance
          int netPaisa = 0;
          for (final item in items) {
            if (item.isSale) {
              netPaisa += item.amount.paisa;
            } else if (item.isPayment) {
              netPaisa -= item.amount.paisa;
            }
          }
          final balance = Money.paisa(netPaisa);

          return Column(
            children: [
              // Balance & WhatsApp inquiry card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: balance.paisa > 0
                      ? theme.colorScheme.errorContainer
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            balance.paisa > 0
                                ? 'Outstanding Udhar'
                                : 'Account Cleared',
                            style: TextStyle(
                              color: balance.paisa > 0
                                  ? theme.colorScheme.onErrorContainer
                                  : theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            balance.format(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: balance.paisa > 0
                                  ? theme.colorScheme.onErrorContainer
                                  : theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (shopPhone != null && shopPhone!.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () => _launchWhatsApp(context, balance),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.chat_rounded, size: 18),
                        label: const Text('WhatsApp'),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Ledger Timeline
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          'No transactions recorded yet.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final formattedDate = DateFormat('dd MMM yyyy, hh:mm a')
                              .format(item.date);

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: item.isSale
                                  ? theme.colorScheme.errorContainer
                                  : theme.colorScheme.primaryContainer,
                              child: Icon(
                                item.isSale
                                    ? Icons.shopping_bag_outlined
                                    : Icons.payments_outlined,
                                color: item.isSale
                                    ? theme.colorScheme.onErrorContainer
                                    : theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.description,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item.isSale ? "+" : "-"}${item.amount.format()}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: item.isSale
                                        ? theme.colorScheme.error
                                        : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              formattedDate,
                              style: theme.textTheme.bodySmall,
                            ),
                            trailing: item.saleId != null
                                ? const Icon(Icons.chevron_right_rounded)
                                : null,
                            onTap: item.saleId != null
                                ? () {
                                    // Open read-only receipt
                                    context.push('/shop/sales/${item.saleId}/receipt');
                                  }
                                : null,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
