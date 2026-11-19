import 'package:easy_hisab/core/domain/app_failure.dart';
import 'package:easy_hisab/core/domain/phone_number.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PhoneNumber', () {
    test('normalizes standard Pakistani formats to E.164', () {
      expect(PhoneNumber.normalize('03001234567'), '+923001234567');
      expect(PhoneNumber.normalize('0300-1234567'), '+923001234567');
      expect(PhoneNumber.normalize('3001234567'), '+923001234567');
      expect(PhoneNumber.normalize('+92 300 1234567'), '+923001234567');
      expect(PhoneNumber.normalize('00923001234567'), '+923001234567');
    });

    test('returns null for empty or null string', () {
      expect(PhoneNumber.normalize(null), isNull);
      expect(PhoneNumber.normalize(''), isNull);
      expect(PhoneNumber.normalize('   '), isNull);
    });

    test('rejects invalid numbers', () {
      for (final bad in ['123', 'abc', '0300', '++923001234567']) {
        expect(
          () => PhoneNumber.normalize(bad),
          throwsA(isA<ValidationFailure>()),
          reason: 'Failed on $bad',
        );
      }
    });

    test('validator helper returns error string or null', () {
      expect(PhoneNumber.validate('03001234567'), isNull);
      expect(PhoneNumber.validate(''), isNull);
      expect(PhoneNumber.validate('abc'), isNotNull);
    });
  });
}
