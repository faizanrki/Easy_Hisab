import '../../../core/domain/clock.dart';
import '../../../core/domain/entity_id.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

final class CreateCustomer {
  const CreateCustomer(this._customers, this._ids, this._clock);

  final CustomerRepository _customers;
  final IdGenerator _ids;
  final Clock _clock;

  Future<Customer> execute({
    required String shopId,
    required CustomerDetails details,
  }) async {
    final now = _clock.nowUtc();
    final customer = Customer(
      id: _ids.newId(),
      shopId: shopId,
      details: details,
      createdAt: now,
      updatedAt: now,
    );
    await _customers.save(customer);
    return customer;
  }
}
