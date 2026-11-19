import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
import '../../domain/product.dart';
import '../product_providers.dart';

class ProductListScreen extends ConsumerStatefulWidget {
  const ProductListScreen({super.key});

  @override
  ConsumerState<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends ConsumerState<ProductListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(productFilterProvider.notifier).updateFilter(query: value);
  }

  @override
  Widget build(BuildContext context) {
    final productListAsync = ref.watch(productListProvider);
    final filter = ref.watch(productFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Catalog'),
        leading: IconButton(
          tooltip: 'Dashboard',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.shopDashboard),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Search grocery products...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  ),
              ],
              onChanged: _onSearchChanged,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Active Products'),
                  selected: !filter.includeArchived,
                  onSelected: (selected) {
                    if (selected) {
                      ref
                          .read(productFilterProvider.notifier)
                          .updateFilter(includeArchived: false);
                    }
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Include Archived'),
                  selected: filter.includeArchived,
                  onSelected: (selected) {
                    ref
                        .read(productFilterProvider.notifier)
                        .updateFilter(includeArchived: selected);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: productListAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 40, color: theme.colorScheme.error),
                      const SizedBox(height: 8),
                      Text('Error: $err'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => ref.refresh(productListProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return _EmptyProductsView(
                    isSearching: filter.query.isNotEmpty,
                    onAddProduct: () => context.push(AppRoutes.productNew),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: products.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _ProductCard(product: product);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.productNew),
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('Add Product'),
      ),
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        onTap: () => context.push('/shop/products/${product.id}/edit'),
        leading: CircleAvatar(
          backgroundColor: product.isArchived
              ? Colors.grey.shade400
              : theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.inventory_2_outlined,
            color: product.isArchived
                ? Colors.white
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          product.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: product.isArchived
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
        subtitle: Text('Unit: ${product.unit}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  product.unitPrice.format(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: product.isArchived
                        ? Colors.grey
                        : theme.colorScheme.primary,
                  ),
                ),
                Text(
                  'per ${product.unit}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            if (product.isArchived)
              const Chip(
                label: Text('Archived', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              )
            else
              const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _EmptyProductsView extends StatelessWidget {
  const _EmptyProductsView({
    required this.isSearching,
    required this.onAddProduct,
  });

  final bool isSearching;
  final VoidCallback onAddProduct;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (isSearching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off_rounded,
                  size: 48, color: theme.colorScheme.secondary),
              const SizedBox(height: 12),
              const Text('No products match your search'),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(Icons.shopping_basket_outlined,
                  size: 38, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
              'No Products in Catalog',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add grocery items with units and prices to easily add them to customer udhar bills.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddProduct,
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('Add First Product'),
            ),
          ],
        ),
      ),
    );
  }
}
