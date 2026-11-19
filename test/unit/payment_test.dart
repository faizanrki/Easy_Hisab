import 'package:easy_hisab/core/domain/app_failure.dart';
import 'package:easy_hisab/core/domain/money.dart';
import 'package:easy_hisab/features/payments/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Payment Validation', () {
    test('validates valid payment', () {
      expect(
        () => Payment.validate(
          shopId: 'shop-1',
          customerId: 'cust-1',
          amount: const Money.rupees(1000),
        ),
        returnsNormally,
      );
    });

    test('rejects zero or negative payment amount', () {
      expect(
        () => Payment.validate(
          shopId: 'shop-1',
          customerId: 'cust-1',
          amount: Money.zero,
        ),
        throwsA(isA<ValidationFailure>()),
      );

      expect(
        () => Payment.validate(
          shopId: 'shop-1',
          customerId: 'cust-1',
          amount: const Money.paisa(-100),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects empty shopId or customerId', () {
      expect(
        () => Payment.validate(
          shopId: '',
          customerId: 'cust-1',
          amount: const Money.rupees(500),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      expect(
        () => Payment.validate(
          shopId: 'shop-1',
          customerId: '',
          amount: const Money.rupees(500),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('PaymentMethod', () {
    test('parses common payment methods correctly', () {
      expect(PaymentMethod.fromString('cash'), PaymentMethod.cash);
      expect(PaymentMethod.fromString('easypaisa'), PaymentMethod.easypaisa);
      expect(PaymentMethod.fromString('jazzcash'), PaymentMethod.jazzcash);
      expect(PaymentMethod.fromString('bank'), PaymentMethod.bankTransfer);
      expect(PaymentMethod.fromString('bank_transfer'), PaymentMethod.bankTransfer);
      expect(PaymentMethod.fromString('unknown_val'), PaymentMethod.other);
      expect(PaymentMethod.fromString(null), PaymentMethod.cash);
    });

    test('exposes user-friendly display names', () {
      expect(PaymentMethod.cash.displayName, 'Cash');
      expect(PaymentMethod.easypaisa.displayName, 'EasyPaisa');
      expect(PaymentMethod.jazzcash.displayName, 'JazzCash');
      expect(PaymentMethod.bankTransfer.displayName, 'Bank Transfer');
      expect(PaymentMethod.other.displayName, 'Other');
    });
  });

  group('Customer Balance Invariants (Spec Example)', () {
    test('Rs 2,500 credit sale minus Rs 1,000 repayment leaves Rs 1,500 due', () {
      const saleAmount = Money.rupees(2500);
      const paymentAmount = Money.rupees(1000);

      final balance = Money.paisa(saleAmount.paisa - paymentAmount.paisa);
      expect(balance, const Money.rupees(1500));
      expect(balance.format(), 'Rs 1,500');
    });
  });
}
