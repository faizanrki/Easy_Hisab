import 'package:flutter/material.dart';

/// EasyHisab visual identity: calm ledger green, large readable text and
/// generous touch targets for busy shopkeepers.
abstract final class AppTheme {
  static const Color brand = Color(0xFF00695C);
  static const Color credit = Color(0xFFC62828); // money owed (udhar)
  static const Color paid = Color(0xFF2E7D32); // money received

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: brand);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        centerTitle: false,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
    );
  }
}
