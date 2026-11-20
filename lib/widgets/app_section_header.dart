import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Left-aligned section heading with optional trailing action link.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.appColors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: textTheme.titleMedium,
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x8,
                vertical: AppSpacing.x4,
              ),
              minimumSize: const Size(48, 36),
              foregroundColor: colors.primary,
            ),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}
