import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/app_failure.dart';
import '../../../../core/domain/phone_number.dart';
import '../../../shop/shop_public.dart';
import '../../domain/customer.dart';
import '../customer_providers.dart';

class AddEditCustomerScreen extends ConsumerStatefulWidget {
  const AddEditCustomerScreen({super.key, this.customerId});

  final String? customerId;

  bool get isEditing => customerId != null;

  @override
  ConsumerState<AddEditCustomerScreen> createState() =>
      _AddEditCustomerScreenState();
}

class _AddEditCustomerScreenState
    extends ConsumerState<AddEditCustomerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _initialized = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _populate(Customer customer) {
    if (!_initialized) {
      _nameController.text = customer.name;
      _phoneController.text = customer.phone ?? '';
      _emailController.text = customer.email ?? '';
      _initialized = true;
    }
  }

  Future<void> _submit(String shopId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final details = CustomerDetails.create(
        name: _nameController.text,
        phone: _phoneController.text,
        email: _emailController.text,
      );

      if (widget.isEditing) {
        final update = ref.read(updateCustomerUseCaseProvider);
        await update.execute(
          shopId: shopId,
          customerId: widget.customerId!,
          details: details,
        );
      } else {
        final create = ref.read(createCustomerUseCaseProvider);
        await create.execute(
          shopId: shopId,
          details: details,
        );
      }

      if (widget.isEditing) {
        final _ = ref.refresh(customerDetailProvider(widget.customerId!));
      }
      final _ = ref.refresh(customerListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Customer details updated'
                  : 'Customer added to ledger',
            ),
          ),
        );
        context.pop();
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
          _errorMessage = 'An error occurred while saving customer.';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopContext = ref.watch(activeShopContextProvider);
    final theme = Theme.of(context);

    if (shopContext == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Customer')),
        body: const Center(child: Text('No active shop selected')),
      );
    }

    if (widget.isEditing) {
      final customerAsync =
          ref.watch(customerDetailProvider(widget.customerId!));
      return customerAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Scaffold(
          body: Center(child: Text('Error loading customer: $err')),
        ),
        data: (customer) {
          if (customer == null) {
            return const Scaffold(
              body: Center(child: Text('Customer not found')),
            );
          }
          _populate(customer);
          return _buildForm(context, shopContext.shopId, theme);
        },
      );
    }

    return _buildForm(context, shopContext.shopId, theme);
  }

  Widget _buildForm(BuildContext context, String shopId, ThemeData theme) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Customer' : 'Add New Customer'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Customer Name *',
                    hintText: 'e.g. Muhammad Ali',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: CustomerDetails.validateName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    hintText: 'e.g. 03001234567',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: PhoneNumber.validate,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Email Address (Optional)',
                    hintText: 'e.g. ali@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: CustomerDetails.validateEmail,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'No customer app account needed. They will be immediately available for udhar recording.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSubmitting ? null : () => _submit(shopId),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(widget.isEditing
                          ? 'Save Changes'
                          : 'Save Customer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
