import '../../../core/domain/app_failure.dart';
import '../../../core/domain/clock.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

final class UpdateCustomer {
  const UpdateCustomer(this._customers, this._clock);

  final CustomerRepository _customers;
  final Clock _clock;

  Future<Customer> execute({
    required String shopId,
    required String customerId,
    required CustomerDetails details,
  }) async {
    final existing = await _customers.findById(shopId, customerId);
    if (existing == null) {
      throw const NotFoundFailure('Customer not found');
    }

    final updated = existing.copyWith(
      details: details,
      updatedAt: _clock.nowUtc(),
    );

    await _customers.update(updated);
    return updated;
  }
}
