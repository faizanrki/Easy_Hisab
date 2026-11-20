import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_tokens.dart';
import '../theme/theme_controller.dart';

/// Reusable AppBar icon button to toggle between Dark and Light themes.
class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key, this.iconColor});

  final Color? iconColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final colors = context.appColors;

    return IconButton(
      tooltip: isDark ? 'Light mode' : 'Dark mode',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      onPressed: () {
        HapticFeedback.selectionClick();
        ref.read(themeModeProvider.notifier).toggle(brightness);
      },
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: AppMotion.curve,
        switchOutCurve: AppMotion.curve,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: RotationTransition(
              turns: Tween<double>(begin: 0.92, end: 1.0).animate(animation),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                child: child,
              ),
            ),
          );
        },
        child: Icon(
          isDark ? LucideIcons.sun : LucideIcons.moon,
          key: ValueKey<bool>(isDark),
          size: 22,
          color: iconColor ?? colors.textPrimary,
        ),
      ),
    );
  }
}
