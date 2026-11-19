import 'app_failure.dart';

/// Phone number helpers shared by shops and customers.
///
/// Phone numbers are contact details only - never identity or authorization.
abstract final class PhoneNumber {
  /// Normalizes to E.164 (`+923001234567`). Returns null for empty input.
  ///
  /// Accepts common Pakistani formats: `0300-1234567`, `3001234567`,
  /// `+92 300 1234567`, `0092...`. Throws [ValidationFailure] otherwise.
  static String? normalize(String? raw) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty) return null;
    if (!RegExp(r'^\+?[\d\s\-()]+$').hasMatch(text)) {
      throw const ValidationFailure('Enter a valid phone number');
    }
    final hasPlus = text.startsWith('+');
    var digits = text.replaceAll(RegExp(r'\D'), '');
    if (!hasPlus) {
      if (digits.startsWith('00')) {
        digits = digits.substring(2);
      } else if (digits.length == 11 && digits.startsWith('0')) {
        digits = '92${digits.substring(1)}';
      } else if (digits.length == 10 && digits.startsWith('3')) {
        digits = '92$digits';
      }
    }
    if (digits.length < 10 || digits.length > 15) {
      throw const ValidationFailure('Enter a valid phone number');
    }
    return '+$digits';
  }

  /// Form-field helper: null when valid, otherwise the error message.
  static String? validate(String? raw) {
    try {
      normalize(raw);
      return null;
    } on ValidationFailure catch (e) {
      return e.message;
    }
  }
}
