import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_tokens.dart';

/// Strict Inter type scale: 12 / 14 / 16 / 20 / 24 / 32
/// Weights: 400 / 500 / 600 | Body line height: 1.45
abstract final class AppTypography {
  static TextTheme buildTextTheme(AppColors colors) {
    TextStyle inter({
      required double size,
      required FontWeight weight,
      required Color color,
      double height = 1.35,
      double letterSpacing = 0,
      List<FontFeature>? fontFeatures,
    }) {
      return GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        fontFeatures: fontFeatures,
      );
    }

    return TextTheme(
      // 32px — Large ledger balances
      displaySmall: inter(
        size: 32,
        weight: FontWeight.w600,
        color: colors.textPrimary,
        height: 1.2,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      // 24px — Screen headings & KPI totals
      headlineMedium: inter(
        size: 24,
        weight: FontWeight.w600,
        color: colors.textPrimary,
        height: 1.25,
        letterSpacing: -0.3,
      ),
      // 20px — Section / card major figures
      headlineSmall: inter(
        size: 20,
        weight: FontWeight.w600,
        color: colors.textPrimary,
        height: 1.3,
        letterSpacing: -0.2,
      ),
      // 16px — Card titles, list primary labels
      titleMedium: inter(
        size: 16,
        weight: FontWeight.w600,
        color: colors.textPrimary,
        height: 1.4,
      ),
      // 14px — Subheadings, button labels
      titleSmall: inter(
        size: 14,
        weight: FontWeight.w600,
        color: colors.textPrimary,
        height: 1.4,
      ),
      // 16px — Primary body
      bodyLarge: inter(
        size: 16,
        weight: FontWeight.w400,
        color: colors.textPrimary,
        height: 1.45,
      ),
      // 14px — Standard body & inputs
      bodyMedium: inter(
        size: 14,
        weight: FontWeight.w400,
        color: colors.textPrimary,
        height: 1.45,
      ),
      // 12px — Secondary metadata, timestamps
      bodySmall: inter(
        size: 12,
        weight: FontWeight.w400,
        color: colors.textSecondary,
        height: 1.4,
      ),
      // 14px — Medium interactive labels
      labelLarge: inter(
        size: 14,
        weight: FontWeight.w500,
        color: colors.textPrimary,
        height: 1.3,
      ),
      // 12px — Badges, chips, captions
      labelMedium: inter(
        size: 12,
        weight: FontWeight.w500,
        color: colors.textSecondary,
        height: 1.3,
      ),
      labelSmall: inter(
        size: 12,
        weight: FontWeight.w500,
        color: colors.textSecondary,
        height: 1.3,
      ),
    );
  }
}
