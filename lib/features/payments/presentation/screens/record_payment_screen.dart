import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/app_failure.dart';
import '../../../../core/domain/money.dart';
import '../../../customers/customers_public.dart';
import '../../../shop/shop_public.dart';
import '../../application/record_payment.dart';
import '../../domain/payment.dart';
import '../payment_providers.dart';

class RecordPaymentScreen extends ConsumerStatefulWidget {
  const RecordPaymentScreen({super.key, this.initialCustomerId});

  final String? initialCustomerId;

  @override
  ConsumerState<RecordPaymentScreen> createState() =>
      _RecordPaymentScreenState();
}

class _RecordPaymentScreenState extends ConsumerState<RecordPaymentScreen> {
  String? _selectedCustomerId;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  PaymentMethod _selectedMethod = PaymentMethod.cash;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedCustomerId = widget.initialCustomerId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Money? _enteredAmount() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    try {
      return Money.parse(text);
    } catch (_) {
      return null;
    }
  }

  Future<void> _submit(String shopId) async {
    if (_selectedCustomerId == null) {
      setState(() => _errorMessage = 'Please select a customer');
      return;
    }

    final amount = _enteredAmount();
    if (amount == null || amount <= Money.zero) {
      setState(() => _errorMessage = 'Please enter a valid payment amount');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final record = ref.read(recordPaymentUseCaseProvider);
      final payment = await record.execute(
        RecordPaymentCommand(
          shopId: shopId,
          customerId: _selectedCustomerId!,
          amount: amount,
          method: _selectedMethod,
          note: _noteController.text,
        ),
      );

      final _ = ref.refresh(customerBalanceProvider(_selectedCustomerId!));
      final _ = ref.refresh(customerLedgerProvider(_selectedCustomerId!));
      final _ = ref.refresh(recentPaymentsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recorded repayment of ${payment.amount.format()}',
            ),
          ),
        );
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/shop/customers/$_selectedCustomerId');
        }
      }
    } on AppFailure catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred while saving the payment.';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopContext = ref.watch(activeShopContextProvider);
    final customersAsync = ref.watch(customerListProvider);
    final theme = Theme.of(context);

    if (shopContext == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Record Payment')),
        body: const Center(child: Text('No active shop selected')),
      );
    }

    final entered = _enteredAmount();
    final balanceAsync = _selectedCustomerId != null
        ? ref.watch(customerBalanceProvider(_selectedCustomerId!))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Repayment'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 1. Customer Selector
            customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Text('Error loading customers: $err'),
              data: (customers) {
                return DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedCustomerId,
                  decoration: const InputDecoration(
                    labelText: 'Select Customer *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  hint: const Text('Choose customer from khata...'),
                  items: customers.map((c) {
                    return DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '${c.name} ${c.phone != null ? "(${c.phone})" : ""}',
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCustomerId = val;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 16),

            // 2. Current Outstanding Balance Card
            if (_selectedCustomerId != null)
              balanceAsync?.when(
                    data: (balance) {
                      final projected = entered != null
                          ? Money.paisa(balance.paisa - entered.paisa)
                          : balance;

                      return Card(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.35,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Current Udhar Due:',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    balance.format(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: balance > Money.zero
                                          ? Colors.red.shade800
                                          : Colors.green.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              if (entered != null && entered > Money.zero) ...[
                                const Divider(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Projected Remaining Due:'),
                                    Text(
                                      projected.format(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: projected > Money.zero
                                            ? Colors.red.shade800
                                            : Colors.green.shade800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, _) => const SizedBox.shrink(),
                  ) ??
                  const SizedBox.shrink(),
            const SizedBox(height: 16),

            // 3. Amount Field
            TextFormField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount Received (PKR) *',
                hintText: 'e.g. 1000',
                prefixIcon: Icon(Icons.payments_outlined),
                prefixText: 'Rs ',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // 4. Payment Method
            Text(
              'Payment Method',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: PaymentMethod.values.map((method) {
                final isSelected = _selectedMethod == method;
                return ChoiceChip(
                  label: Text(method.displayName),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedMethod = method);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // 5. Note Field
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Notes / Reference (Optional)',
                hintText: 'e.g. Cash handed over in shop',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // 6. Submit Button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting
                    ? null
                    : () => _submit(shopContext.shopId),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        entered != null && entered > Money.zero
                            ? 'Record Payment (${entered.format()})'
                            : 'Record Payment',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
