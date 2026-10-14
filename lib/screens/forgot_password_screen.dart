import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() { _loading = true; _message = null; });
    try {
      await ref.read(authServiceProvider).sendPasswordReset(_emailController.text);
      setState(() {
        _sent = true;
        _message = 'Reset link bhej diya gaya. Email check karein.';
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _message = ref.read(authServiceProvider).getErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Reset Password', style: AppTextStyles.headingLarge),
                  const SizedBox(height: 6),
                  Text('Email daalein, hum reset link bhej denge',
                    style: AppTextStyles.bodySmall),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: AppTextStyles.bodyMedium,
                    decoration: const InputDecoration(
                      hintText: 'your@email.com',
                      prefixIcon: Icon(LucideIcons.mail, size: 16)),
                  ),
                  const SizedBox(height: 20),
                  if (_message != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _sent ? AppColors.primarySoft : AppColors.errorSoft,
                        borderRadius: BorderRadius.circular(8)),
                      child: Text(_message!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: _sent ? AppColors.primary : AppColors.error)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  ElevatedButton(
                    onPressed: _loading ? null : _send,
                    child: _loading
                        ? const SizedBox(height: 18, width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black))
                        : const Text('Send Reset Link'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Wapas Login pe'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
