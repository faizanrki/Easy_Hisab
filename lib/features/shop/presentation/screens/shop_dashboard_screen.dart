import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';

/// Shopkeeper home. Placeholder until modules 02-06 (shop setup, customers,
/// products, sales, payments) are implemented.
class ShopDashboardScreen extends StatelessWidget {
  const ShopDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shop'),
        leading: IconButton(
          tooltip: 'Change role',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.chooseRole),
        ),
      ),
      body: const _ComingSoon(
        icon: Icons.storefront_rounded,
        message: 'Set up your shop to start recording udhar.\n'
            '(Shop setup arrives in the next module.)',
      ),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
