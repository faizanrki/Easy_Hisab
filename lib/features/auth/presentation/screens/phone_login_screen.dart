import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/app_router.dart';
import '../../../../core/domain/app_failure.dart';
import '../auth_providers.dart';

/// Screen for authenticating via Pakistani Mobile Phone Number and 6-digit SMS OTP.
class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key, this.isCustomer = false});

  final bool isCustomer;

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phoneController = TextEditingController(text: '03001234567');
  final _otpController = TextEditingController();

  bool _isCodeSent = false;
  bool _isLoading = false;
  String? _verificationId;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _formatToE164(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'[\s\-]'), '');
    if (cleaned.startsWith('03')) {
      cleaned = '+92${cleaned.substring(1)}';
    } else if (cleaned.startsWith('3') && cleaned.length == 10) {
      cleaned = '+92$cleaned';
    } else if (!cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    }
    return cleaned;
  }

  Future<void> _handleSendOtp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      setState(() => _errorMessage = 'Please enter your mobile phone number.');
      return;
    }

    final formattedPhone = _formatToE164(rawPhone);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sendOtpUseCase = ref.read(sendPhoneOtpUseCaseProvider);
      await sendOtpUseCase.execute(
        phoneNumber: formattedPhone,
        onCodeSent: (vid) {
          if (mounted) {
            setState(() {
              _verificationId = vid;
              _isCodeSent = true;
              _isLoading = false;
            });
          }
        },
        onFailed: (err) {
          if (mounted) {
            setState(() {
              _errorMessage = err;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the full 6-digit code.');
      return;
    }

    if (_verificationId == null) {
      setState(() => _errorMessage = 'Session missing. Please request a new code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final verifyOtpUseCase = ref.read(verifyPhoneOtpUseCaseProvider);
      await verifyOtpUseCase.execute(
        verificationId: _verificationId!,
        smsCode: code,
      );

      if (mounted) {
        if (widget.isCustomer) {
          context.go(AppRoutes.customerShops);
        } else {
          context.go(AppRoutes.shopDashboard);
        }
      }
    } on AppFailure catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCustomer ? 'Customer Login' : 'Shopkeeper Login'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              CircleAvatar(
                radius: 36,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.phone_android_rounded,
                  size: 40,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isCodeSent ? 'Enter SMS Code' : 'Phone Number Login',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _isCodeSent
                    ? 'Enter the 6-digit code sent to ${_formatToE164(_phoneController.text)}'
                    : 'Log in with your Pakistani mobile number to manage your khata ledger.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              if (_errorMessage != null) ...[
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
                          _errorMessage!,
                          style: TextStyle(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              if (!_isCodeSent) ...[
                TextFormField(
                  key: const Key('phone_number_field'),
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Mobile Phone Number',
                    hintText: '0300 1234567',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    prefixText: '+92 ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'e.g. 03001234567 (Jazz, Zong, Telenor, Ufone)',
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('send_otp_button'),
                  onPressed: _isLoading ? null : _handleSendOtp,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.arrow_forward_rounded),
                  label: Text(_isLoading ? 'Sending SMS...' : 'Send OTP Code'),
                ),
              ] else ...[
                TextFormField(
                  key: const Key('otp_code_field'),
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 8),
                  decoration: InputDecoration(
                    labelText: '6-digit OTP Code',
                    hintText: '123456',
                    prefixIcon: const Icon(Icons.lock_clock_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    helperText: 'For testing, enter 123456',
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('verify_otp_button'),
                  onPressed: _isLoading ? null : _handleVerifyOtp,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_isLoading ? 'Verifying...' : 'Verify & Continue'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          setState(() {
                            _isCodeSent = false;
                            _otpController.clear();
                            _errorMessage = null;
                          });
                        },
                  child: const Text('Change Phone Number'),
                ),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () => context.push(AppRoutes.login),
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Sign In with Email & Password instead'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
