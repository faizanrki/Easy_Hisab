import 'package:easy_hisab/core/domain/app_failure.dart';
import 'package:easy_hisab/core/domain/money.dart';
import 'package:easy_hisab/core/domain/quantity.dart';
import 'package:easy_hisab/features/sales/domain/sale.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SaleLine', () {
    test('creates valid line with calculated total in paisa', () {
      final line = SaleLine.create(
        id: 'line-1',
        saleId: 'sale-1',
        description: '  Rice Super Karnal  ',
        unit: ' KG ',
        quantity: const Quantity.milli(2500),
        unitPrice: const Money.rupees(300),
        position: 0,
      );

      expect(line.description, 'Rice Super Karnal');
      expect(line.unit, 'kg');
      expect(line.lineTotal, const Money.rupees(750));
      expect(line.lineTotal.paisa, 75000);
    });

    test('rejects empty description', () {
      expect(
        () => SaleLine.create(
          id: 'line-1',
          saleId: 'sale-1',
          description: '   ',
          unit: 'kg',
          quantity: const Quantity.whole(1),
          unitPrice: const Money.rupees(100),
          position: 0,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects zero or negative quantity', () {
      expect(
        () => SaleLine.create(
          id: 'line-1',
          saleId: 'sale-1',
          description: 'Sugar',
          unit: 'kg',
          quantity: const Quantity.whole(0),
          unitPrice: const Money.rupees(150),
          position: 0,
        ),
        throwsA(isA<ValidationFailure>()),
      );

      expect(
        () => SaleLine.create(
          id: 'line-1',
          saleId: 'sale-1',
          description: 'Sugar',
          unit: 'kg',
          quantity: const Quantity.whole(-2),
          unitPrice: const Money.rupees(150),
          position: 0,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects negative unit price', () {
      expect(
        () => SaleLine.create(
          id: 'line-1',
          saleId: 'sale-1',
          description: 'Flour',
          unit: 'kg',
          quantity: const Quantity.whole(1),
          unitPrice: const Money.paisa(-500),
          position: 0,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });

  group('Sale Validation', () {
    final item1 = SaleLine.create(
      id: 'item-1',
      saleId: 'sale-1',
      description: 'Sugar',
      unit: 'kg',
      quantity: const Quantity.whole(2),
      unitPrice: const Money.rupees(150), // Rs 300
      position: 0,
    );

    final item2 = SaleLine.create(
      id: 'item-2',
      saleId: 'sale-1',
      description: 'Cooking Oil',
      unit: 'ltr',
      quantity: const Quantity.whole(4),
      unitPrice: const Money.rupees(550), // Rs 2200
      position: 1,
    );

    test('validates matching bill total', () {
      expect(
        () => Sale.validate(
          shopId: 'shop-1',
          customerId: 'cust-1',
          items: [item1, item2],
          total: const Money.rupees(2500), // Rs 300 + 2200 = 2500
        ),
        returnsNormally,
      );
    });

    test('rejects mismatched total', () {
      expect(
        () => Sale.validate(
          shopId: 'shop-1',
          customerId: 'cust-1',
          items: [item1, item2],
          total: const Money.rupees(2400),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects empty items list', () {
      expect(
        () => Sale.validate(
          shopId: 'shop-1',
          customerId: 'cust-1',
          items: [],
          total: Money.zero,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects missing customer or shop', () {
      expect(
        () => Sale.validate(
          shopId: '',
          customerId: 'cust-1',
          items: [item1],
          total: const Money.rupees(300),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      expect(
        () => Sale.validate(
          shopId: 'shop-1',
          customerId: '',
          items: [item1],
          total: const Money.rupees(300),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
