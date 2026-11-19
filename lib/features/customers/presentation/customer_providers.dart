import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dependency_providers.dart';
import '../../../core/contracts/customer_lookup_port.dart';
import '../../shop/shop_public.dart';
import '../application/archive_customer.dart';
import '../application/create_customer.dart';
import '../application/get_customers.dart';
import '../application/update_customer.dart';
import '../data/sqlite_customer_repository.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final db = ref.watch(dbTransactionProvider);
  final ids = ref.watch(idGeneratorProvider);
  return SqliteCustomerRepository(db, ids);
});

final customerLookupPortProvider = Provider<CustomerLookupPort>((ref) {
  final db = ref.watch(dbTransactionProvider);
  final ids = ref.watch(idGeneratorProvider);
  return SqliteCustomerRepository(db, ids);
});

final createCustomerUseCaseProvider = Provider<CreateCustomer>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  final ids = ref.watch(idGeneratorProvider);
  final clock = ref.watch(clockProvider);
  return CreateCustomer(repo, ids, clock);
});

final updateCustomerUseCaseProvider = Provider<UpdateCustomer>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  final clock = ref.watch(clockProvider);
  return UpdateCustomer(repo, clock);
});

final archiveCustomerUseCaseProvider = Provider<ArchiveCustomer>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  final clock = ref.watch(clockProvider);
  return ArchiveCustomer(repo, clock);
});

final getCustomersUseCaseProvider = Provider<GetCustomers>((ref) {
  final repo = ref.watch(customerRepositoryProvider);
  return GetCustomers(repo);
});

/// Search query and filter state for Customer List
class CustomerFilter {
  const CustomerFilter({this.query = '', this.includeArchived = false});
  final String query;
  final bool includeArchived;

  CustomerFilter copyWith({String? query, bool? includeArchived}) =>
      CustomerFilter(
        query: query ?? this.query,
        includeArchived: includeArchived ?? this.includeArchived,
      );

  @override
  bool operator ==(Object other) =>
      other is CustomerFilter &&
      other.query == query &&
      other.includeArchived == includeArchived;

  @override
  int get hashCode => Object.hash(query, includeArchived);
}

final customerFilterProvider =
    NotifierProvider<CustomerFilterNotifier, CustomerFilter>(
  CustomerFilterNotifier.new,
);

class CustomerFilterNotifier extends Notifier<CustomerFilter> {
  @override
  CustomerFilter build() => const CustomerFilter();

  void updateFilter({String? query, bool? includeArchived}) {
    state = state.copyWith(query: query, includeArchived: includeArchived);
  }
}

/// List of customers for the currently active shop
final customerListProvider =
    FutureProvider.autoDispose<List<Customer>>((ref) async {
  final shopContext = ref.watch(activeShopContextProvider);
  if (shopContext == null) return [];

  final filter = ref.watch(customerFilterProvider);
  final getCustomers = ref.watch(getCustomersUseCaseProvider);

  return getCustomers.execute(
    shopId: shopContext.shopId,
    searchQuery: filter.query,
    includeArchived: filter.includeArchived,
  );
});

/// Single customer detail provider
final customerDetailProvider =
    FutureProvider.autoDispose.family<Customer?, String>((ref, customerId) async {
  final shopContext = ref.watch(activeShopContextProvider);
  if (shopContext == null) return null;

  final getCustomers = ref.watch(getCustomersUseCaseProvider);
  return getCustomers.getById(
    shopId: shopContext.shopId,
    customerId: customerId,
  );
});
