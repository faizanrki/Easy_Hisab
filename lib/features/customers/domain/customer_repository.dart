import 'customer.dart';

/// Storage port for Customer entities.
abstract interface class CustomerRepository {
  Future<void> save(Customer customer);

  Future<void> update(Customer customer);

  Future<Customer?> findById(String shopId, String customerId);

  Future<List<Customer>> listForShop(
    String shopId, {
    String? searchQuery,
    bool includeArchived = false,
  });

  /// Archive customer without deleting financial history.
  Future<void> setArchivedStatus(
    String shopId,
    String customerId, {
    required bool archived,
    required DateTime timestamp,
  });
}
