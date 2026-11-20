import 'package:flutter/material.dart';

/// 8px spacing grid tokens.
abstract final class AppSpacing {
  static const double x4 = 4;
  static const double x8 = 8;
  static const double x12 = 12;
  static const double x16 = 16;
  static const double x24 = 24;
  static const double x32 = 32;

  static const double screen = 16;
  static const double screenWide = 20;
}

/// Consistent shape radius tokens (10-12px restrained geometry).
abstract final class AppRadius {
  static const double button = 10;
  static const double card = 12;
  static const double input = 12;
  static const double dialog = 16;
}

/// Motion tokens: 150-250ms ease-out only.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 220);
  static const Curve curve = Curves.easeOut;
}

/// Semantic color tokens for EasyHisab light & dark themes.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.primary,
    required this.primaryMuted,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.due,
    required this.dueBg,
    required this.paid,
    required this.paidBg,
    required this.warning,
    required this.warningBg,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color primary;
  final Color primaryMuted;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color due;
  final Color dueBg;
  final Color paid;
  final Color paidBg;
  final Color warning;
  final Color warningBg;

  static const light = AppColors(
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEEF1F4),
    border: Color(0xFFE5E7EB),
    primary: Color(0xFF0F6B5C),
    primaryMuted: Color(0xFFE6F2EF),
    onPrimary: Color(0xFFF7F9F9),
    textPrimary: Color(0xFF12181F),
    textSecondary: Color(0xFF5B6672),
    due: Color(0xFFB83232),
    dueBg: Color(0xFFFDF0F0),
    paid: Color(0xFF1F7A4D),
    paidBg: Color(0xFFEDF7F1),
    warning: Color(0xFFB46914),
    warningBg: Color(0xFFFCF4E8),
  );

  static const dark = AppColors(
    background: Color(0xFF0F1115),
    surface: Color(0xFF171A20),
    surfaceMuted: Color(0xFF1F242D),
    border: Color(0xFF262A32),
    primary: Color(0xFF1FA38A),
    primaryMuted: Color(0xFF132A25),
    onPrimary: Color(0xFF0B1413),
    textPrimary: Color(0xFFE8EAED),
    textSecondary: Color(0xFF9AA3AE),
    due: Color(0xFFE07070),
    dueBg: Color(0xFF2A181A),
    paid: Color(0xFF52B788),
    paidBg: Color(0xFF14261E),
    warning: Color(0xFFE29A4A),
    warningBg: Color(0xFF292014),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? primary,
    Color? primaryMuted,
    Color? onPrimary,
    Color? textPrimary,
    Color? textSecondary,
    Color? due,
    Color? dueBg,
    Color? paid,
    Color? paidBg,
    Color? warning,
    Color? warningBg,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryMuted: primaryMuted ?? this.primaryMuted,
      onPrimary: onPrimary ?? this.onPrimary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      due: due ?? this.due,
      dueBg: dueBg ?? this.dueBg,
      paid: paid ?? this.paid,
      paidBg: paidBg ?? this.paidBg,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryMuted: Color.lerp(primaryMuted, other.primaryMuted, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      due: Color.lerp(due, other.due, t)!,
      dueBg: Color.lerp(dueBg, other.dueBg, t)!,
      paid: Color.lerp(paid, other.paid, t)!,
      paidBg: Color.lerp(paidBg, other.paidBg, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get appColors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
