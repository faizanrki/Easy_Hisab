import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';

/// Customer home: linked shops and per-shop balances (read-only).
/// Placeholder until modules 08-09 (sign-in and approved ledger linking).
class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shops'),
        leading: IconButton(
          tooltip: 'Change role',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.chooseRole),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.link_rounded,
                  size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Sign in and connect to your shop to see your bills.\n'
                '(Customer sign-in arrives in a later module.)',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
