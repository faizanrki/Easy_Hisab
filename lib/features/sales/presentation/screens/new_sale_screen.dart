import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/domain/app_failure.dart';
import '../../../../core/domain/money.dart';
import '../../../../core/domain/quantity.dart';
import '../../../customer_portal/presentation/customer_portal_providers.dart';
import '../../../customers/customers_public.dart';
import '../../../products/products_public.dart';
import '../../../shop/shop_public.dart';
import '../../application/create_sale.dart';
import '../../domain/sale.dart';
import '../cart_state.dart';
import '../sale_providers.dart';

class NewSaleScreen extends ConsumerStatefulWidget {
  const NewSaleScreen({super.key, this.initialCustomerId});

  final String? initialCustomerId;

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  CartState _cart = const CartState();
  final _initialPaymentController = TextEditingController();
  final _noteController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialCustomerId != null) {
      _cart = _cart.copyWith(customerId: widget.initialCustomerId);
    }
  }

  @override
  void dispose() {
    _initialPaymentController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showItemDialog(
    List<Product> products, {
    required String shopId,
    CartLine? editItem,
    int? editIndex,
  }) {
    Product? selectedProduct;
    if (products.isNotEmpty) {
      if (editItem?.productId != null) {
        selectedProduct = products
            .where((p) => p.id == editItem!.productId)
            .firstOrNull ?? products.first;
      } else {
        selectedProduct = products.first;
      }
    }

    final nameController = TextEditingController(
      text: editItem?.description ?? selectedProduct?.name ?? '',
    );
    final priceController = TextEditingController(
      text: editItem != null
          ? (editItem.unitPrice.paisa / 100).toStringAsFixed(
              editItem.unitPrice.paisa % 100 == 0 ? 0 : 2,
            )
          : selectedProduct != null
              ? (selectedProduct.unitPrice.paisa / 100).toStringAsFixed(
                  selectedProduct.unitPrice.paisa % 100 == 0 ? 0 : 2,
                )
              : '',
    );
    final qtyController = TextEditingController(
      text: editItem?.quantity.format() ?? '1',
    );
    String selectedUnit =
        editItem?.unit ?? selectedProduct?.unit ?? StandardGroceryUnits.kg;
    bool saveToCatalog = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Money? computedTotal;
            try {
              final q = Quantity.parse(qtyController.text);
              final p = Money.parse(priceController.text);
              computedTotal = q.times(p);
            } catch (_) {
              computedTotal = null;
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          editIndex != null
                              ? 'Edit Bill Item'
                              : 'Add Item to Cart',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quick Select from Catalog if catalog has products
                    if (products.isNotEmpty) ...[
                      DropdownButtonFormField<Product>(
                        isExpanded: true,
                        initialValue: selectedProduct,
                        decoration: const InputDecoration(
                          labelText: 'Select Product',
                          prefixIcon: Icon(Icons.shopping_basket_outlined),
                          border: OutlineInputBorder(),
                        ),
                        items: products.map((p) => DropdownMenuItem<Product>(
                                value: p,
                                child: Text(
                                  '${p.name} (${p.unitPrice.format()}/${p.unit})',
                                ),
                              )).toList(),
                        onChanged: (p) {
                          setModalState(() {
                            selectedProduct = p;
                            if (p != null) {
                              nameController.text = p.name;
                              priceController.text = (p.unitPrice.paisa / 100)
                                  .toStringAsFixed(
                                      p.unitPrice.paisa % 100 == 0 ? 0 : 2);
                              selectedUnit = p.unit;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Item Name
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product / Item Name',
                        hintText: 'e.g. Sugar, Flour, Daal Chana, Milk',
                        prefixIcon: Icon(Icons.shopping_bag_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Unit Price & Unit Row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: priceController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Price / $selectedUnit (Rs)',
                              hintText: 'e.g. 50, 150',
                              prefixIcon:
                                  const Icon(Icons.price_change_outlined),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => setModalState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue:
                                StandardGroceryUnits.all.contains(selectedUnit)
                                    ? selectedUnit
                                    : StandardGroceryUnits.kg,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              border: OutlineInputBorder(),
                            ),
                            items: StandardGroceryUnits.all
                                .map((u) => DropdownMenuItem(
                                      value: u,
                                      child: Text(u),
                                    ))
                                .toList(),
                            onChanged: (u) {
                              if (u != null) {
                                setModalState(() => selectedUnit = u);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quantity Input with Fractional Decimal support
                    TextFormField(
                      controller: qtyController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Quantity ($selectedUnit)',
                        hintText: 'e.g. 1, 1.5, 1.25, 0.5',
                        prefixIcon: const Icon(Icons.scale_outlined),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 8),

                    // Quick Quantity Presets
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('+0.5'),
                          onPressed: () {
                            try {
                              final current =
                                  num.tryParse(qtyController.text) ?? 0;
                              qtyController.text = (current + 0.5).toString();
                              setModalState(() {});
                            } catch (_) {}
                          },
                        ),
                        ActionChip(
                          label: const Text('+1'),
                          onPressed: () {
                            try {
                              final current =
                                  num.tryParse(qtyController.text) ?? 0;
                              qtyController.text = (current + 1).toString();
                              setModalState(() {});
                            } catch (_) {}
                          },
                        ),
                        ActionChip(
                          label: Text('1.25 $selectedUnit'),
                          onPressed: () {
                            qtyController.text = '1.25';
                            setModalState(() {});
                          },
                        ),
                        ActionChip(
                          label: Text('1.5 $selectedUnit'),
                          onPressed: () {
                            qtyController.text = '1.5';
                            setModalState(() {});
                          },
                        ),
                        ActionChip(
                          label: Text('2 $selectedUnit'),
                          onPressed: () {
                            qtyController.text = '2';
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Live Computed Total Banner
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: computedTotal != null
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Item Total:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: computedTotal != null
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Colors.black87,
                            ),
                          ),
                          Text(
                            computedTotal != null
                                ? computedTotal.format()
                                : 'Enter price & qty',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: computedTotal != null
                                  ? Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Save to Catalog Checkbox
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: saveToCatalog,
                      title: const Text('Save / Update in Product Catalog'),
                      subtitle: const Text(
                        'Keep this price and product saved for future bills',
                        style: TextStyle(fontSize: 12),
                      ),
                      onChanged: (val) {
                        setModalState(() => saveToCatalog = val ?? false);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Submit Action Button
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter product name'),
                            ),
                          );
                          return;
                        }

                        Quantity qty;
                        try {
                          qty = Quantity.parse(qtyController.text);
                        } catch (e) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Please enter a valid quantity (e.g. 1.5)'),
                            ),
                          );
                          return;
                        }

                        Money price;
                        try {
                          price = Money.parse(priceController.text);
                        } catch (e) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content:
                                  Text('Please enter a valid price (e.g. 50)'),
                            ),
                          );
                          return;
                        }

                        String? prodId =
                            selectedProduct?.id ?? editItem?.productId;

                        if (saveToCatalog) {
                          try {
                            final details = ProductDetails.create(
                              name: name,
                              unit: selectedUnit,
                              unitPrice: price,
                            );

                            if (selectedProduct != null) {
                              // Update catalog price
                              await ref
                                  .read(updateProductUseCaseProvider)
                                  .execute(
                                    shopId: shopId,
                                    productId: selectedProduct!.id,
                                    details: details,
                                  );
                            } else {
                              // Create in catalog
                              final newProd = await ref
                                  .read(createProductUseCaseProvider)
                                  .execute(
                                    shopId: shopId,
                                    details: details,
                                  );
                              prodId = newProd.id;
                            }
                            ref.invalidate(productListProvider);
                          } catch (e) {
                            debugPrint('Could not save to catalog: $e');
                          }
                        }

                        final line = CartLine(
                          productId: prodId,
                          description: name,
                          unit: selectedUnit,
                          quantity: qty,
                          unitPrice: price,
                        );

                        if (!ctx.mounted) return;
                        setState(() {
                          final items = List<CartLine>.from(_cart.items);
                          if (editIndex != null && editIndex < items.length) {
                            items[editIndex] = line;
                          } else {
                            items.add(line);
                          }
                          _cart = _cart.copyWith(items: items);
                        });

                        Navigator.pop(ctx);
                      },
                      child: Text(
                        editIndex != null ? 'Update Item' : 'Add to Bill',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submit(String shopId) async {
    if (_cart.customerId == null) {
      setState(() => _errorMessage = 'Please select a customer for this bill');
      return;
    }
    if (_cart.items.isEmpty) {
      setState(() => _errorMessage = 'Please add at least one product');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      Money? initPay;
      if (_initialPaymentController.text.trim().isNotEmpty) {
        initPay = Money.parse(_initialPaymentController.text);
      }

      final createSale = ref.read(createSaleUseCaseProvider);
      final cmd = CreateSaleCommand(
        shopId: shopId,
        customerId: _cart.customerId!,
        saleType: _cart.saleType,
        items: _cart.items.map((i) => i.toInput()).toList(),
        initialPayment: initPay,
        note: _noteController.text,
      );

      final sale = await createSale.execute(cmd);

      // Rotate customer token so previous token expires and new token is active
      await ref.read(customerTokenServiceProvider).rotateToken(
            shopId: shopId,
            customerId: _cart.customerId!,
          );

      final _ = ref.refresh(recentSalesProvider);
      final _ = ref.refresh(customerSalesProvider(_cart.customerId!));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bill ${sale.receiptNo} posted (${sale.total.format()})',
            ),
          ),
        );
        context.pushReplacement('/shop/sales/${sale.id}');
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
          _errorMessage = 'An error occurred while posting the bill.';
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopContext = ref.watch(activeShopContextProvider);
    final customersAsync = ref.watch(customerListProvider);
    final productsAsync = ref.watch(productListProvider);
    final theme = Theme.of(context);

    if (shopContext == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Bill')),
        body: const Center(child: Text('No active shop selected')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Bill'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
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

                  // 1. Customer Selection
                  customersAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Text('Error loading customers: $err'),
                    data: (customers) {
                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _cart.customerId,
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
                            _cart = _cart.copyWith(customerId: val);
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // 2. Sale Type Toggle (Credit vs Paid)
                  SegmentedButton<SaleType>(
                    segments: const [
                      ButtonSegment(
                        value: SaleType.credit,
                        icon: Icon(Icons.credit_card_outlined),
                        label: Text('Credit (Udhar)'),
                      ),
                      ButtonSegment(
                        value: SaleType.paid,
                        icon: Icon(Icons.check_circle_outline),
                        label: Text('Cash Paid'),
                      ),
                    ],
                    selected: {_cart.saleType},
                    onSelectionChanged: (selected) {
                      setState(() {
                        _cart = _cart.copyWith(saleType: selected.first);
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 3. Products Cart Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          'Items in Bill (${_cart.items.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Add Product'),
                        onPressed: () => _showItemDialog(
                          productsAsync.value ?? [],
                          shopId: shopContext.shopId,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_cart.items.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.shopping_cart_outlined,
                                size: 40, color: theme.colorScheme.primary),
                            const SizedBox(height: 8),
                            const Text('Cart is empty'),
                            const SizedBox(height: 4),
                            Text(
                              'Tap "Add Product / Item" to add groceries with customizable price & weight.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._cart.items.asMap().entries.map((entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          onTap: () => _showItemDialog(
                            productsAsync.value ?? [],
                            shopId: shopContext.shopId,
                            editItem: item,
                            editIndex: index,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.description,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                            ],
                          ),
                          subtitle: Text(
                            '${item.quantity.format()} ${item.unit} @ ${item.unitPrice.format()} • Tap to edit',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.lineTotal.format(),
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: Colors.red.shade400,
                                onPressed: () {
                                  final updated =
                                      List<CartLine>.from(_cart.items);
                                  updated.removeAt(index);
                                  setState(() {
                                    _cart = _cart.copyWith(items: updated);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 16),

                  // 4. Initial Payment (only for credit bills)
                  if (_cart.saleType == SaleType.credit) ...[
                    TextFormField(
                      controller: _initialPaymentController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Initial Payment at Checkout (Optional)',
                        hintText: 'e.g. 1000',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      onChanged: (val) {
                        setState(() {
                          try {
                            _cart = _cart.copyWith(
                              initialPayment:
                                  val.trim().isEmpty ? null : Money.parse(val),
                            );
                          } catch (_) {}
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 5. Notes
                  TextFormField(
                    controller: _noteController,
                    decoration: const InputDecoration(
                      labelText: 'Bill Note (Optional)',
                      hintText: 'e.g. Bought for wedding function',
                      prefixIcon: Icon(Icons.edit_note_outlined),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom checkout bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Bill:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        _cart.total.format(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  if (_cart.saleType == SaleType.credit &&
                      _cart.initialPayment != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Remaining Udhar Due:'),
                        Text(
                          _cart.balanceDue.format(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : () => _submit(shopContext.shopId),
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
                              _cart.saleType == SaleType.credit
                                  ? 'Post Credit Bill (${_cart.total.format()})'
                                  : 'Post Cash Bill (${_cart.total.format()})',
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
