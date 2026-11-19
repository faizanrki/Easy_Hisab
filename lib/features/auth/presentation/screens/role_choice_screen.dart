import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';

/// Welcome screen: "I am a Shopkeeper" / "I am a Customer".
///
/// The choice only selects which experience to open. It is NOT authorization;
/// access is decided later by verified identity + shop membership/links.
class RoleChoiceScreen extends StatelessWidget {
  const RoleChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                subtitle: 'Record credit sales, payments and customer balances',
                onTap: () => context.go(AppRoutes.shopDashboard),
              ),
              const SizedBox(height: 16),
              _RoleCard(
                icon: Icons.person_rounded,
                title: 'I am a Customer',
                subtitle: 'View your bills and balance at linked shops',
                onTap: () => context.go(AppRoutes.customerShops),
              ),
              const SizedBox(height: 24),
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
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(icon,
                    size: 30, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
