import 'package:easy_hisab/core/domain/app_failure.dart';
import 'package:easy_hisab/features/customers/domain/customer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomerDetails', () {
    test('creates valid customer details with normalized values', () {
      final details = CustomerDetails.create(
        name: '   Muhammad   Ali   ',
        phone: '0300 1234567',
        email: '  ALI@Example.com ',
      );

      expect(details.name, 'Muhammad Ali');
      expect(details.nameSearch, 'muhammad ali');
      expect(details.phone, '+923001234567');
      expect(details.email, 'ALI@Example.com');
    });

    test('accepts optional null or empty phone and email', () {
      final details = CustomerDetails.create(
        name: 'Tariq Mehmood',
        phone: '',
        email: null,
      );

      expect(details.name, 'Tariq Mehmood');
      expect(details.phone, isNull);
      expect(details.email, isNull);
    });

    test('rejects empty or whitespace-only name', () {
      expect(
        () => CustomerDetails.create(name: '   '),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects name shorter than 2 characters or longer than 60', () {
      expect(
        () => CustomerDetails.create(name: 'A'),
        throwsA(isA<ValidationFailure>()),
      );
      expect(
        () => CustomerDetails.create(name: 'A' * 61),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('rejects invalid email formats', () {
      for (final bad in ['not-an-email', 'ali@', '@domain.com', 'a b@c.com']) {
        expect(
          () => CustomerDetails.create(name: 'Valid Name', email: bad),
          throwsA(isA<ValidationFailure>()),
          reason: 'Failed on $bad',
        );
      }
    });
  });
}
