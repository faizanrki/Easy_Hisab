import '../../../core/domain/money.dart';
import '../domain/payment.dart';
import '../domain/payment_repository.dart';

final class GetCustomerLedger {
  const GetCustomerLedger(this._payments);

  final PaymentRepository _payments;

  Future<List<LedgerEntry>> execute({
    required String shopId,
    required String customerId,
  }) {
    return _payments.getCustomerLedger(shopId, customerId);
  }
}

final class GetCustomerBalance {
  const GetCustomerBalance(this._payments);

  final PaymentRepository _payments;

  Future<Money> execute({
    required String shopId,
    required String customerId,
  }) {
    return _payments.getCustomerBalance(shopId, customerId);
  }
}
