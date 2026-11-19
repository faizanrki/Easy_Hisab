import 'app_failure.dart';
import 'money.dart';

/// A product quantity stored as an exact integer in thousandths (milli-units).
///
/// Examples: 1 packet = 1000, 2.5 kg = 2500, 250 g (0.25 kg) = 250.
/// This avoids floating-point errors for loose groceries sold by weight.
final class Quantity implements Comparable<Quantity> {
  const Quantity.milli(this.milli);
  const Quantity.whole(int units) : milli = units * scale;

  static const int scale = 1000;

  final int milli;

  /// Parses input such as `2`, `2.5` or `0.250` (max 3 decimals, must be > 0).
  factory Quantity.parse(String input) {
    final match = RegExp(r'^(\d+)(?:\.(\d{1,3}))?$').firstMatch(input.trim());
    if (match == null) {
      throw ValidationFailure('Enter a valid quantity, e.g. 2 or 1.5');
    }
    final whole = int.parse(match.group(1)!);
    final fraction = int.parse((match.group(2) ?? '').padRight(3, '0'));
    final q = Quantity.milli(whole * scale + fraction);
    if (q.milli <= 0) throw ValidationFailure('Quantity must be more than 0');
    return q;
  }

  /// Line total = unit price x quantity, rounded half-up to the nearest paisa.
  Money times(Money unitPrice) {
    final raw = unitPrice.paisa * milli;
    final rounded = raw >= 0
        ? (raw + scale ~/ 2) ~/ scale
        : -((-raw + scale ~/ 2) ~/ scale);
    return Money.paisa(rounded);
  }

  String format() {
    final whole = milli ~/ scale;
    final frac = milli % scale;
    if (frac == 0) return '$whole';
    return '$whole.${frac.toString().padLeft(3, '0')}'
        .replaceFirst(RegExp(r'0+$'), '');
  }

  @override
  int compareTo(Quantity other) => milli.compareTo(other.milli);

  @override
  bool operator ==(Object other) => other is Quantity && other.milli == milli;

  @override
  int get hashCode => milli.hashCode;

  @override
  String toString() => format();
}
