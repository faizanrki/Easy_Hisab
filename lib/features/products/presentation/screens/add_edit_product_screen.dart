import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/app_failure.dart';
import '../../../../core/domain/money.dart';
import '../../../shop/shop_public.dart';
import '../../domain/product.dart';
import '../product_providers.dart';

class AddEditProductScreen extends ConsumerStatefulWidget {
  const AddEditProductScreen({super.key, this.productId});

  final String? productId;

  bool get isEditing => productId != null;

  @override
  ConsumerState<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _AddEditProductScreenState extends ConsumerState<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedUnit = StandardGroceryUnits.kg;
  bool _initialized = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _populate(Product product) {
    if (!_initialized) {
      _nameController.text = product.name;
      _selectedUnit = product.unit;
      // Show in rupees format (e.g. 150 or 150.50)
      final paisa = product.unitPrice.paisa;
      final rupees = paisa ~/ 100;
      final frac = paisa % 100;
      _priceController.text = frac == 0 ? '$rupees' : '$rupees.${frac.toString().padLeft(2, '0')}';
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
      final money = Money.parse(_priceController.text);
      final details = ProductDetails.create(
        name: _nameController.text,
        unit: _selectedUnit,
        unitPrice: money,
      );

      if (widget.isEditing) {
        final update = ref.read(updateProductUseCaseProvider);
        await update.execute(
          shopId: shopId,
          productId: widget.productId!,
          details: details,
        );
      } else {
        final create = ref.read(createProductUseCaseProvider);
        await create.execute(
          shopId: shopId,
          details: details,
        );
      }

      if (widget.isEditing) {
        final _ = ref.refresh(productDetailProvider(widget.productId!));
      }
      final _ = ref.refresh(productListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Product updated in catalog'
                  : 'Product added to catalog',
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
          _errorMessage = 'An error occurred while saving product.';
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _toggleArchive(String shopId, Product product) async {
    final shouldArchive = !product.isArchived;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(shouldArchive ? 'Archive Product?' : 'Restore Product?'),
        content: Text(
          shouldArchive
              ? 'Archived products will not be suggested for new sales, but past sales remain unaffected.'
              : 'Restore this product to the active catalog?',
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

    final archiveUseCase = ref.read(archiveProductUseCaseProvider);
    await archiveUseCase.execute(
      shopId: shopId,
      productId: product.id,
      archive: shouldArchive,
    );

    final _ = ref.refresh(productDetailProvider(product.id));
    final _ = ref.refresh(productListProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shouldArchive
                ? 'Product archived'
                : 'Product restored to active catalog',
          ),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopContext = ref.watch(activeShopContextProvider);
    final theme = Theme.of(context);

    if (shopContext == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Product')),
        body: const Center(child: Text('No active shop selected')),
      );
    }

    if (widget.isEditing) {
      final productAsync = ref.watch(productDetailProvider(widget.productId!));
      return productAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Scaffold(
          body: Center(child: Text('Error: $err')),
        ),
        data: (product) {
          if (product == null) {
            return const Scaffold(
              body: Center(child: Text('Product not found')),
            );
          }
          _populate(product);
          return _buildForm(context, shopContext.shopId, theme, product);
        },
      );
    }

    return _buildForm(context, shopContext.shopId, theme, null);
  }

  Widget _buildForm(
    BuildContext context,
    String shopId,
    ThemeData theme,
    Product? existingProduct,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Product' : 'Add New Product'),
        actions: [
          if (existingProduct != null)
            IconButton(
              tooltip: existingProduct.isArchived ? 'Restore' : 'Archive',
              icon: Icon(
                existingProduct.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              onPressed: () => _toggleArchive(shopId, existingProduct),
            ),
        ],
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
                    labelText: 'Product Name *',
                    hintText: 'e.g. Sugar, Cooking Oil, Atta',
                    prefixIcon: Icon(Icons.shopping_bag_outlined),
                  ),
                  validator: ProductDetails.validateName,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedUnit,
                  decoration: const InputDecoration(
                    labelText: 'Selling Unit *',
                    prefixIcon: Icon(Icons.scale_outlined),
                  ),
                  items: StandardGroceryUnits.all.map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedUnit = val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: 'Unit Price (Rupees) *',
                    hintText: 'e.g. 150 or 150.50',
                    prefixIcon: const Icon(Icons.currency_rupee_rounded),
                    suffixText: 'per $_selectedUnit',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Unit price is required';
                    }
                    try {
                      final m = Money.parse(val);
                      if (m.isNegative) return 'Price cannot be negative';
                      return null;
                    } catch (e) {
                      return 'Enter a valid amount, e.g. 150 or 150.50';
                    }
                  },
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
                      Icon(Icons.lock_clock_outlined,
                          size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Price snapshots are saved when sales are posted. Updating prices here will never alter past bills.',
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
                          : 'Save Product'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
