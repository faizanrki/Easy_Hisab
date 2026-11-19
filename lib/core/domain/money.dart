import 'package:intl/intl.dart';

import 'app_failure.dart';

/// An amount of Pakistani money stored as an exact integer number of paisa.
///
/// 1 rupee = 100 paisa. Never use `double` for money in EasyHisab; this class
/// is the only place that converts between display rupees and stored paisa.
final class Money implements Comparable<Money> {
  const Money.paisa(this.paisa);

  /// Whole rupees, e.g. `Money.rupees(2500)` == Rs 2,500.
  const Money.rupees(int rupees) : paisa = rupees * 100;

  static const Money zero = Money.paisa(0);

  final int paisa;

  /// Parses user input such as `2500`, `2,500`, `2500.5` or `2,500.50`.
  ///
  /// Throws [ValidationFailure] for malformed input or more than 2 decimals.
  factory Money.parse(String input) {
    var text = input.trim().replaceAll(',', '');
    // Allow an optional "Rs" / "Rs." prefix.
    text = text.replaceFirst(RegExp(r'^rs\.?\s*', caseSensitive: false), '');
    final match = RegExp(r'^(-)?(\d+)(?:\.(\d{1,2}))?$').firstMatch(text);
    if (match == null) {
      throw ValidationFailure('Enter a valid amount, e.g. 2500 or 2500.50');
    }
    final negative = match.group(1) != null;
    final rupees = int.parse(match.group(2)!);
    final fraction = (match.group(3) ?? '').padRight(2, '0');
    final value = rupees * 100 + (fraction.isEmpty ? 0 : int.parse(fraction));
    return Money.paisa(negative ? -value : value);
  }

  bool get isZero => paisa == 0;
  bool get isNegative => paisa < 0;
  bool get isPositive => paisa > 0;

  Money operator +(Money other) => Money.paisa(paisa + other.paisa);
  Money operator -(Money other) => Money.paisa(paisa - other.paisa);
  Money operator -() => Money.paisa(-paisa);
  bool operator <(Money other) => paisa < other.paisa;
  bool operator <=(Money other) => paisa <= other.paisa;
  bool operator >(Money other) => paisa > other.paisa;
  bool operator >=(Money other) => paisa >= other.paisa;

  static Money sum(Iterable<Money> values) =>
      values.fold(Money.zero, (total, m) => total + m);

  static final NumberFormat _whole = NumberFormat('#,##0', 'en_US');

  /// Display text such as `Rs 2,500` or `Rs 2,500.50` (or `-Rs 100`).
  String format() {
    final abs = paisa.abs();
    final rupees = _whole.format(abs ~/ 100);
    final rem = abs % 100;
    final body = rem == 0 ? rupees : '$rupees.${rem.toString().padLeft(2, '0')}';
    return '${paisa < 0 ? '-' : ''}Rs $body';
  }

  @override
  int compareTo(Money other) => paisa.compareTo(other.paisa);

  @override
  bool operator ==(Object other) => other is Money && other.paisa == paisa;

  @override
  int get hashCode => paisa.hashCode;

  @override
  String toString() => format();
}
