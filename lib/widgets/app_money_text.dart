import 'package:flutter/material.dart';

import '../core/domain/money.dart';
import '../theme/app_tokens.dart';

enum MoneyTone { neutral, due, paid }

/// Tabular-aligned PKR currency text using semantic ledger tones.
class AppMoneyText extends StatelessWidget {
  const AppMoneyText({
    super.key,
    required this.money,
    this.tone = MoneyTone.neutral,
    this.style,
    this.showAbsolute = false,
  });

  final Money money;
  final MoneyTone tone;
  final TextStyle? style;
  final bool showAbsolute;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final baseStyle = style ?? Theme.of(context).textTheme.titleMedium;
    final Color color = switch (tone) {
      MoneyTone.due => colors.due,
      MoneyTone.paid => colors.paid,
      MoneyTone.neutral => colors.textPrimary,
    };

    final formatted = showAbsolute
        ? Money.paisa(money.paisa.abs()).format()
        : money.format();

    return Text(
      formatted,
      style: baseStyle?.copyWith(
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
