import '../../../core/domain/app_failure.dart';
import '../../../core/domain/clock.dart';
import '../domain/customer_repository.dart';

final class ArchiveCustomer {
  const ArchiveCustomer(this._customers, this._clock);

  final CustomerRepository _customers;
  final Clock _clock;

  Future<void> execute({
    required String shopId,
    required String customerId,
    required bool archive,
  }) async {
    final existing = await _customers.findById(shopId, customerId);
    if (existing == null) {
      throw const NotFoundFailure('Customer not found');
    }

    await _customers.setArchivedStatus(
      shopId,
      customerId,
      archived: archive,
      timestamp: _clock.nowUtc(),
    );
  }
}
