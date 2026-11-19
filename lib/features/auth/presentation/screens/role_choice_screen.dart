import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
import '../auth_providers.dart';

/// Welcome screen: "I am a Shopkeeper" / "I am a Customer".
///
/// Shopkeepers are required to authenticate via Phone OTP for data security
/// and cloud backup. Customers can access their portal view directly.
class RoleChoiceScreen extends ConsumerWidget {
  const RoleChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authService = ref.watch(authServiceProvider);
    final user = authService.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.menu_book_rounded,
                  size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'EasyHisab',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your digital udhar khata',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              _RoleCard(
                icon: Icons.storefront_rounded,
                title: 'I am a Shopkeeper',
                subtitle: user != null
                    ? 'Logged in as ${user.phoneNumber ?? user.displayName ?? 'Shopkeeper'}'
                    : 'Requires mobile number login (OTP)',
                onTap: () {
                  if (user != null) {
                    context.go(AppRoutes.shopDashboard);
                  } else {
                    context.push(AppRoutes.phoneLogin);
                  }
                },
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.person_rounded,
                title: 'I am a Customer',
                subtitle: 'View your bills and balance at linked shops',
                onTap: () => context.go(AppRoutes.customerShops),
              ),
              const SizedBox(height: 24),
              if (user == null) ...[
                FilledButton.icon(
                  onPressed: () => context.push(AppRoutes.phoneLogin),
                  icon: const Icon(Icons.phone_android_rounded),
                  label: const Text('Login with Mobile Number (OTP)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.login),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Sign In with Email'),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(signOutUseCaseProvider).execute();
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
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
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    size: 32, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
