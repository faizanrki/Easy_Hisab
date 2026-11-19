import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
import '../../../../core/domain/app_failure.dart';
import '../../../../core/domain/phone_number.dart';
import '../../domain/shop.dart';
import '../shop_providers.dart';

class ShopEditScreen extends ConsumerStatefulWidget {
  const ShopEditScreen({super.key});

  @override
  ConsumerState<ShopEditScreen> createState() => _ShopEditScreenState();
}

class _ShopEditScreenState extends ConsumerState<ShopEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;
  bool _initialized = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _populate(Shop shop) {
    if (!_initialized) {
      _nameController.text = shop.name;
      _addressController.text = shop.address ?? '';
      _phoneController.text = shop.contactPhone ?? '';
      _initialized = true;
    }
  }

  Future<void> _save(String shopId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final details = ShopDetails.create(
        name: _nameController.text,
        address: _addressController.text,
        contactPhone: _phoneController.text,
      );

      await ref.read(activeShopProvider.notifier).updateShop(shopId, details);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shop profile updated successfully')),
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
          _errorMessage = 'An unexpected error occurred.';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeShopAsync = ref.watch(activeShopProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Shop Profile'),
      ),
      body: activeShopAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (shop) {
          if (shop == null) {
            return const Center(child: Text('No active shop found.'));
          }

          _populate(shop);

          return SafeArea(
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
                        labelText: 'Shop Name *',
                        prefixIcon: Icon(Icons.storefront_outlined),
                      ),
                      validator: ShopDetails.validateName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Contact Phone',
                        hintText: 'e.g. 03001234567',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: PhoneNumber.validate,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: ShopDetails.validateAddress,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isSubmitting ? null : () => _save(shop.id),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => context.push(AppRoutes.backup),
                      icon: const Icon(Icons.backup_outlined),
                      label: const Text('Database Backup & Safety'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
