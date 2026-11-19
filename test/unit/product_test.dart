import 'package:easy_hisab/core/domain/app_failure.dart';
import 'package:easy_hisab/core/domain/money.dart';
import 'package:easy_hisab/features/products/domain/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductDetails', () {
    test('creates valid product details with normalized values', () {
      final details = ProductDetails.create(
        name: '   White   Sugar  ',
        unit: ' KG ',
        unitPrice: const Money.rupees(150),
      );

      expect(details.name, 'White Sugar');
      expect(details.nameSearch, 'white sugar');
      expect(details.unit, 'kg');
      expect(details.unitPrice.paisa, 15000);
      expect(details.unitPrice.format(), 'Rs 150');
    });

    test('rejects empty or whitespace-only name and unit', () {
      expect(
        () => ProductDetails.create(
          name: '   ',
          unit: 'kg',
          unitPrice: const Money.rupees(100),
        ),
        throwsA(isA<ValidationFailure>()),
      );

      expect(
        () => ProductDetails.create(
          name: 'Cooking Oil',
          unit: '   ',
          unitPrice: const Money.rupees(100),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects negative price', () {
      expect(
        () => ProductDetails.create(
          name: 'Atta',
          unit: 'kg',
          unitPrice: const Money.paisa(-100),
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('allows zero price (e.g. promotional item)', () {
      final details = ProductDetails.create(
        name: 'Plastic Bag',
        unit: 'piece',
        unitPrice: Money.zero,
      );
      expect(details.unitPrice.paisa, 0);
    });
  });
}
