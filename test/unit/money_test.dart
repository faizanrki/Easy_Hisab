import 'package:easy_hisab/core/domain/app_failure.dart';
import 'package:easy_hisab/core/domain/money.dart';
import 'package:easy_hisab/core/domain/quantity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money', () {
    test('stores exact paisa', () {
      expect(const Money.rupees(2500).paisa, 250000);
      expect(Money.parse('2,500.50').paisa, 250050);
      expect(Money.parse('2500.5').paisa, 250050);
      expect(Money.parse('Rs. 1,000').paisa, 100000);
      expect(Money.parse(' 0.07 ').paisa, 7);
    });

    test('rejects malformed input', () {
      for (final bad in ['', 'abc', '1.234', '1..2', '12a']) {
        expect(() => Money.parse(bad), throwsA(isA<ValidationFailure>()),
            reason: bad);
      }
    });

    test('spec example: Rs 2,500 sale - Rs 1,000 payment = Rs 1,500 due', () {
      const sale = Money.rupees(2500);
      const payment = Money.rupees(1000);
      expect(sale - payment, const Money.rupees(1500));
      expect((sale - payment).paisa, 150000);
    });

    test('no floating point drift', () {
      final tenPaisa = Money.parse('0.10');
      final total = Money.sum(List.filled(3, tenPaisa));
      expect(total, Money.parse('0.30'));
    });

    test('formats for display', () {
      expect(const Money.rupees(2500).format(), 'Rs 2,500');
      expect(const Money.paisa(250050).format(), 'Rs 2,500.50');
      expect(const Money.paisa(-10000).format(), '-Rs 100');
      expect(Money.zero.format(), 'Rs 0');
    });
  });

  group('Quantity', () {
    test('parses decimals exactly', () {
      expect(Quantity.parse('2').milli, 2000);
      expect(Quantity.parse('2.5').milli, 2500);
      expect(Quantity.parse('0.250').milli, 250);
      expect(Quantity.parse('0.25').format(), '0.25');
    });

    test('rejects zero and invalid', () {
      for (final bad in ['0', '0.000', '-1', '1.2345', 'x']) {
        expect(() => Quantity.parse(bad), throwsA(isA<ValidationFailure>()),
            reason: bad);
      }
    });

    test('line total: 2.5 kg sugar at Rs 150/kg = Rs 375', () {
      expect(Quantity.parse('2.5').times(const Money.rupees(150)),
          const Money.rupees(375));
    });

    test('line total rounds half-up to the nearest paisa', () {
      // 0.333 x Rs 1.00 = 33.3 paisa -> 33; 0.335 x Rs 1.00 = 33.5 -> 34
      expect(Quantity.parse('0.333').times(const Money.rupees(1)).paisa, 33);
      expect(Quantity.parse('0.335').times(const Money.rupees(1)).paisa, 34);
    });
  });
}
