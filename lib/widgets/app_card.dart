import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_tokens.dart';

/// Restrained, flat 1px-bordered surface container on the 8px grid.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.x16),
    this.backgroundColor,
    this.borderColor,
    this.onTap,
    this.haptic = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool haptic;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final radius = BorderRadius.circular(AppRadius.card);

    return Material(
      color: backgroundColor ?? colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor ?? colors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              borderRadius: radius,
              onTap: () {
                if (haptic) HapticFeedback.lightImpact();
                onTap!();
              },
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}
