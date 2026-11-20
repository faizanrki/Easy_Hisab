import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
import '../../../../core/domain/money.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../customer_portal_providers.dart';

enum CustomerPortalTab { myStores, trackToken }

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  CustomerPortalTab _activeTab = CustomerPortalTab.myStores;
  final _shopCodeController = TextEditingController();
  final _tokenController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isResolvingToken = false;
  String? _tokenError;

  @override
  void dispose() {
    _shopCodeController.dispose();
    _tokenController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _checkTokenLedger() async {
    FocusScope.of(context).unfocus();
    final shopCode = _shopCodeController.text.trim();
    final token = _tokenController.text.trim();

    if (shopCode.isEmpty) {
      setState(() => _tokenError = 'Please enter Shop ID (e.g. SHOP-4F29A1).');
      return;
    }
    if (token.isEmpty) {
      setState(() => _tokenError = 'Please enter your Bill Token.');
      return;
    }

    setState(() {
      _isResolvingToken = true;
      _tokenError = null;
    });

    try {
      final tokenService = ref.read(customerTokenServiceProvider);
      final res = await tokenService.resolve(
        shopCodeOrId: shopCode,
        token: token,
      );

      if (!mounted) return;

      if (res == null) {
        setState(() {
          _isResolvingToken = false;
          _tokenError =
              'Invalid or expired token. Every new bill generates a new token and expires the old one. Please enter the token from your latest receipt.';
        });
        return;
      }

      setState(() => _isResolvingToken = false);

      final phoneParam = res.shopPhone != null
          ? '&phone=${Uri.encodeComponent(res.shopPhone!)}'
          : '';
      context.push(
        '/customer/shops/${res.shopId}/ledger?customerId=${res.customerId}&shopName=${Uri.encodeComponent(res.shopName)}$phoneParam',
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResolvingToken = false;
          _tokenError = 'Error verifying token: $e';
        });
      }
    }
  }

  void _linkPhone() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    ref.read(customerPhoneNumberProvider.notifier).setPhone(phone);
    ref.invalidate(linkedShopsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shopsAsync = ref.watch(linkedShopsProvider);
    final activePhone = ref.watch(customerPhoneNumberProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Shops'),
        leading: IconButton(
          tooltip: 'Switch Role / Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.chooseRole),
        ),
        actions: [
          IconButton(
            tooltip: 'Sign Out / Switch',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await ref.read(signOutUseCaseProvider).execute();
              if (context.mounted) {
                context.go(AppRoutes.chooseRole);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  key: const Key('tab_my_stores'),
                  avatar: const Icon(Icons.storefront_outlined, size: 16),
                  label: const Text('My Stores'),
                  selected: _activeTab == CustomerPortalTab.myStores,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _activeTab = CustomerPortalTab.myStores);
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  key: const Key('tab_track_token'),
                  avatar: const Icon(Icons.vpn_key_rounded, size: 16),
                  label: const Text('Track with Token'),
                  selected: _activeTab == CustomerPortalTab.trackToken,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _activeTab = CustomerPortalTab.trackToken);
                    }
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _activeTab == CustomerPortalTab.myStores
                ? _buildMyStoresTab(theme, shopsAsync, activePhone)
                : _buildTokenLookupTab(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildMyStoresTab(
    ThemeData theme,
    AsyncValue<List<dynamic>> shopsAsync,
    String? activePhone,
  ) {
    return Column(
      children: [
        if (activePhone != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user_rounded,
                      size: 20, color: Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Verified Customer Account',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        activePhone,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      context.push('${AppRoutes.phoneLogin}?role=customer'),
                  icon: const Icon(Icons.switch_account_outlined, size: 16),
                  label: const Text('Switch', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Enter phone (e.g. 03001234567)',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _linkPhone,
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Find Shops',
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: shopsAsync.when(
            loading: () => const Center(child: SizedBox(width: 24, height: 24)),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 12),
                    Text('Error loading shops: $err'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(linkedShopsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
            data: (shops) {
              if (shops.isEmpty) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 64,
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          activePhone == null
                              ? 'No Connected Shops Yet'
                              : 'No Khata Records Found',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          activePhone == null
                              ? 'Enter your mobile number above or use the "Track with Token" tab to view your bills without a phone number.'
                              : 'No shops have recorded credit or transactions for $activePhone yet.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: shops.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = shops[index];
                  final isDue = item.balance.paisa > 0;
                  final isAdvance = item.balance.paisa < 0;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        final phoneParam = item.shopPhone != null
                            ? '&phone=${Uri.encodeComponent(item.shopPhone!)}'
                            : '';
                        context.push(
                          '/customer/shops/${item.shopId}/ledger?customerId=${item.customerId}&shopName=${Uri.encodeComponent(item.shopName)}$phoneParam',
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Icon(
                                Icons.storefront_rounded,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.shopName,
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (item.shopPhone != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      item.shopPhone!,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    'Customer: ${item.customerName}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  Money.paisa(item.balance.paisa.abs())
                                      .format(),
                                  style:
                                      theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDue
                                        ? theme.colorScheme.error
                                        : isAdvance
                                            ? Colors.green
                                            : theme.colorScheme.onSurface,
                                  ),
                                ),
                                Text(
                                  isDue
                                      ? 'You owe'
                                      : isAdvance
                                          ? 'Advance'
                                          : 'Settled',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDue
                                        ? theme.colorScheme.error
                                        : isAdvance
                                            ? Colors.green
                                            : theme
                                                .colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTokenLookupTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    child: const Icon(Icons.vpn_key_rounded, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Instant Bill Token Lookup',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No phone number or registration needed. Enter the unique Shop ID and Token printed on your bill receipt.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_tokenError != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: theme.colorScheme.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _tokenError!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          TextFormField(
            key: const Key('token_shop_code_field'),
            controller: _shopCodeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Shop ID / Code *',
              hintText: 'e.g. SHOP-4F29A1',
              prefixIcon: const Icon(Icons.storefront_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: 'Found at the top and bottom of your receipt',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('token_code_field'),
            controller: _tokenController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Receipt Token *',
              hintText: 'e.g. 849201',
              prefixIcon: const Icon(Icons.password_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              helperText: '6-digit access code from your latest bill',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('token_submit_button'),
            onPressed: _isResolvingToken ? null : _checkTokenLedger,
            icon: _isResolvingToken
                ? const SizedBox(width: 20, height: 20)
                : const Icon(Icons.receipt_long_rounded),
            label: Text(_isResolvingToken
                ? 'Verifying Token...'
                : 'View My Udhar Ledger'),
          ),
        ],
      ),
    );
  }
}
