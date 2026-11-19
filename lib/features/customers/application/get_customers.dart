import '../domain/customer.dart';
import '../domain/customer_repository.dart';

final class GetCustomers {
  const GetCustomers(this._customers);

  final CustomerRepository _customers;

  Future<List<Customer>> execute({
    required String shopId,
    String? searchQuery,
    bool includeArchived = false,
  }) {
    return _customers.listForShop(
      shopId,
      searchQuery: searchQuery,
      includeArchived: includeArchived,
    );
  }

  Future<Customer?> getById({
    required String shopId,
    required String customerId,
  }) {
    return _customers.findById(shopId, customerId);
  }
}
