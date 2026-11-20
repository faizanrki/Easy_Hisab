import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/app_router.dart';
import '../../../../core/domain/money.dart';
import '../../application/customer_token_service.dart';
import '../customer_portal_providers.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen>
    with SingleTickerProviderStateMixin {
  final _shopCodeController = TextEditingController();
  final _tokenController = TextEditingController();
  bool _isResolvingToken = false;
  String? _tokenError;
  ResolvedCustomerToken? _resolvedToken;

  late final AnimationController _entryController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    ));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _shopCodeController.dispose();
    _tokenController.dispose();
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
      setState(() => _tokenError = 'Please enter your Receipt Token.');
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
              'Invalid or expired token. Every new bill generates a new token and expires the old one. Please check your latest receipt.';
        });
        return;
      }

      setState(() {
        _isResolvingToken = false;
        _resolvedToken = res;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResolvingToken = false;
          _tokenError = 'Error verifying token: $e';
        });
      }
    }
  }

  void _resetLookup() {
    setState(() {
      _resolvedToken = null;
      _tokenError = null;
      _shopCodeController.clear();
      _tokenController.clear();
    });
  }

  Future<void> _launchWhatsApp(ResolvedCustomerToken resolved) async {
    final phone = resolved.shopPhone;
    if (phone == null || phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop phone number is not available.')),
      );
      return;
    }

    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final internationalPhone =
        cleanPhone.startsWith('0') ? '92${cleanPhone.substring(1)}' : cleanPhone;

    final balance = Money.paisa(resolved.balancePaisa.abs()).format();
    final msg = Uri.encodeComponent(
      'Assalam-o-Alaikum, I am ${resolved.customerName} inquiring about my EasyHisab balance ($balance) at ${resolved.shopName} (${resolved.shopCode}).',
    );
    final url = Uri.parse('https://wa.me/$internationalPhone?text=$msg');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open WhatsApp.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Hisaab Portal'),
        centerTitle: true,
        leading: IconButton(
          tooltip: 'Switch Role / Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go(AppRoutes.chooseRole),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _resolvedToken != null
                ? _buildInstantBalanceView(theme, _resolvedToken!)
                : _buildTokenLookupForm(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildTokenLookupForm(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('token_lookup_form'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Modern Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.vpn_key_rounded,
                    size: 26,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check Balance with Token',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Enter the Shop ID and 6-digit Receipt Token printed on your latest bill to view your balance.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_tokenError != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _tokenError!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
          TextFormField(
            key: const Key('token_shop_code_field'),
            controller: _shopCodeController,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Shop ID / Code *',
              hintText: 'e.g. SHOP-4F29A1',
              prefixIcon: const Icon(Icons.storefront_rounded),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              helperText: 'Printed at the top/bottom of your receipt',
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            key: const Key('token_code_field'),
            controller: _tokenController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) {
              if (!_isResolvingToken) _checkTokenLedger();
            },
            decoration: InputDecoration(
              labelText: 'Receipt Token *',
              hintText: 'e.g. 849201',
              prefixIcon: const Icon(Icons.password_rounded),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              helperText: '6-digit code from your latest bill',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('token_submit_button'),
            onPressed: _isResolvingToken ? null : _checkTokenLedger,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: _isResolvingToken
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.account_balance_wallet_rounded),
            label: Text(
              _isResolvingToken ? 'Checking Balance...' : 'Check My Balance',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Each new bill issues a fresh token and expires the previous one to keep your account private.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstantBalanceView(
    ThemeData theme,
    ResolvedCustomerToken resolved,
  ) {
    final isDue = resolved.balancePaisa > 0;
    final isAdvance = resolved.balancePaisa < 0;
    final formattedBalance =
        Money.paisa(resolved.balancePaisa.abs()).format();

    final Color statusColor = isDue
        ? theme.colorScheme.error
        : isAdvance
            ? Colors.teal
            : Colors.green.shade700;

    final Color statusBg = isDue
        ? theme.colorScheme.errorContainer
        : isAdvance
            ? Colors.teal.shade50
            : Colors.green.shade50;

    final String statusLabel = isDue
        ? 'Outstanding Udhar Due'
        : isAdvance
            ? 'Advance Balance'
            : 'Account Cleared';

    final IconData statusIcon = isDue
        ? Icons.pending_actions_rounded
        : isAdvance
            ? Icons.savings_rounded
            : Icons.verified_rounded;

    return SingleChildScrollView(
      key: const ValueKey('instant_balance_view'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Animated Balance Card
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.94, end: 1.0),
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(scale: scale, child: child);
            },
            child: Card(
              elevation: 2,
              shadowColor: statusColor.withValues(alpha: 0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: statusColor.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Shop Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: 16,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            resolved.shopCode,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onPrimaryContainer,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      resolved.shopName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Customer: ${resolved.customerName}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Prominent Balance Box
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Icon(statusIcon, size: 36, color: statusColor),
                          const SizedBox(height: 10),
                          Text(
                            statusLabel,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            formattedBalance,
                            key: const Key('customer_instant_balance_text'),
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (resolved.lastBillAt != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 15,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Last Bill: ${DateFormat('dd MMM yyyy, hh:mm a').format(resolved.lastBillAt!.toLocal())}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (resolved.shopPhone != null &&
              resolved.shopPhone!.trim().isNotEmpty) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _launchWhatsApp(resolved),
              icon: const Icon(Icons.chat_bubble_rounded),
              label: const Text(
                'WhatsApp Shopkeeper',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            key: const Key('check_another_token_button'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _resetLookup,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'Check Another Bill / Token',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
