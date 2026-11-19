import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
import '../../domain/customer.dart';
import '../customer_providers.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    ref.read(customerFilterProvider.notifier).updateFilter(query: value);
  }

  @override
  Widget build(BuildContext context) {
    final customerListAsync = ref.watch(customerListProvider);
    final filter = ref.watch(customerFilterProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Khata'),
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
              hintText: 'Search by name or phone...',
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
                  label: const Text('Active Customers'),
                  selected: !filter.includeArchived,
                  onSelected: (selected) {
                    if (selected) {
                      ref
                          .read(customerFilterProvider.notifier)
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
                        .read(customerFilterProvider.notifier)
                        .updateFilter(includeArchived: selected);
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: customerListAsync.when(
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
                        onPressed: () => ref.refresh(customerListProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (customers) {
                if (customers.isEmpty) {
                  return _EmptyCustomersView(
                    isSearching: filter.query.isNotEmpty,
                    onAddCustomer: () => context.push(AppRoutes.customerNew),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: customers.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    return _CustomerCard(customer: customer);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.customerNew),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Customer'),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?';

    return Card(
      child: ListTile(
        onTap: () => context.push('/shop/customers/${customer.id}'),
        leading: CircleAvatar(
          backgroundColor: customer.isArchived
              ? Colors.grey.shade400
              : theme.colorScheme.primaryContainer,
          child: Text(
            initial,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: customer.isArchived
                  ? Colors.white
                  : theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(
          customer.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: customer.isArchived
                ? TextDecoration.lineThrough
                : TextDecoration.none,
          ),
        ),
        subtitle: Text(
          customer.phone ?? 'No phone recorded',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: customer.isArchived
            ? const Chip(
                label: Text('Archived', style: TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              )
            : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _EmptyCustomersView extends StatelessWidget {
  const _EmptyCustomersView({
    required this.isSearching,
    required this.onAddCustomer,
  });

  final bool isSearching;
  final VoidCallback onAddCustomer;

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
              const Text('No customers match your search'),
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
              child: Icon(Icons.people_outline_rounded,
                  size: 38, color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text(
              'No Customers Yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add local customers to record grocery udhar and track repayments.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddCustomer,
              icon: const Icon(Icons.person_add_rounded),
              label: const Text('Add First Customer'),
            ),
          ],
        ),
      ),
    );
  }
}
