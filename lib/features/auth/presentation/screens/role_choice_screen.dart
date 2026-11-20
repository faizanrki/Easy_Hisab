import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../app/app_router.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/app_button.dart';
import '../../../../widgets/app_card.dart';
import '../../../../widgets/theme_toggle_button.dart';
import '../auth_providers.dart';

/// Entry role selector for Shopkeepers and Customers.
class RoleChoiceScreen extends ConsumerWidget {
  const RoleChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenWide),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: AppMotion.normal,
                curve: AppMotion.curve,
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _BrandMark(colors: colors),
                        const ThemeToggleButton(),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.x16),
                    Text(
                      'EasyHisab',
                      style: textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.x4),
                    Text(
                      'Digital udhar register for your shop and customers.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x32),
                    Text(
                      'Choose how you want to continue',
                      style: textTheme.labelMedium,
                    ),
                    const SizedBox(height: AppSpacing.x12),
                    _RoleOptionCard(
                      icon: LucideIcons.store,
                      title: 'I am a Shopkeeper',
                      subtitle: user != null
                          ? 'Signed in as ${user.phoneNumber ?? user.displayName ?? 'Shopkeeper'}'
                          : 'Manage bills, payments, and customer udhar',
                      onTap: () {
                        if (user != null) {
                          context.go(AppRoutes.shopDashboard);
                        } else {
                          context.push(AppRoutes.phoneLogin);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.x12),
                    _RoleOptionCard(
                      icon: LucideIcons.receiptText,
                      title: 'I am a Customer',
                      subtitle:
                          'Check your balance with Shop ID and bill token',
                      onTap: () => context.go(AppRoutes.customerShops),
                    ),
                    const SizedBox(height: AppSpacing.x32),
                    if (user == null) ...[
                      AppButton(
                        label: 'Login with Mobile Number (OTP)',
                        icon: LucideIcons.smartphone,
                        onPressed: () => context.push(AppRoutes.phoneLogin),
                      ),
                      const SizedBox(height: AppSpacing.x12),
                      AppButton(
                        label: 'Sign In with Email',
                        icon: LucideIcons.mail,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => context.push(AppRoutes.login),
                      ),
                    ] else ...[
                      AppButton(
                        label: 'Sign Out',
                        icon: LucideIcons.logOut,
                        variant: AppButtonVariant.secondary,
                        onPressed: () async {
                          await ref.read(signOutUseCaseProvider).execute();
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.x16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.border, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/images/easyhisab_logo.png',
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          LucideIcons.bookOpen,
          size: 24,
          color: colors.primary,
        ),
      ),
    );
  }
}

class _RoleOptionCard extends StatelessWidget {
  const _RoleOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      haptic: true,
      padding: const EdgeInsets.all(AppSpacing.x16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primaryMuted,
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Icon(icon, size: 22, color: colors.primary),
          ),
          const SizedBox(width: AppSpacing.x16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  subtitle,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x8),
          Icon(
            LucideIcons.chevronRight,
            size: 20,
            color: colors.textSecondary,
          ),
        ],
      ),
    );
  }
}
