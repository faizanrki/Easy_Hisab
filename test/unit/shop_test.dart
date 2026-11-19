import 'package:easy_hisab/core/domain/app_failure.dart';
import 'package:easy_hisab/features/shop/domain/shop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShopDetails', () {
    test('creates valid shop details with normalized values', () {
      final details = ShopDetails.create(
        name: '  Al-Madina   Grocery ',
        address: '  Main Bazaar, Lahore  ',
        contactPhone: '03001234567',
      );

      expect(details.name, 'Al-Madina Grocery');
      expect(details.address, 'Main Bazaar, Lahore');
      expect(details.contactPhone, '+923001234567');
    });

    test('accepts optional null/empty address and phone', () {
      final details = ShopDetails.create(
        name: 'Bismillah Store',
        address: '',
        contactPhone: null,
      );

      expect(details.name, 'Bismillah Store');
      expect(details.address, isNull);
      expect(details.contactPhone, isNull);
    });

    test('rejects empty or whitespace-only name', () {
      expect(
        () => ShopDetails.create(name: '   '),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects excessively long name or address', () {
      expect(
        () => ShopDetails.create(name: 'A' * 81),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => ShopDetails.create(
          name: 'Store',
          address: 'A' * 201,
        ),
        throwsA(isA<ValidationFailure>()),
      );
    });
  });
}
