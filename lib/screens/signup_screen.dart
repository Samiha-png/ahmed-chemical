import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authServiceProvider).signUp(
            email: _emailController.text,
            password: _passwordController.text,
            fullName: _nameController.text.trim());
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = ref.read(authServiceProvider).getErrorMessage(e);
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
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Create Super Admin',
                      style: AppTextStyles.headingLarge),
                    const SizedBox(height: 6),
                    Text('Pehla account Super Admin banega',
                      style: AppTextStyles.bodySmall),
                    const SizedBox(height: 24),
                    Text('Full Name', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      style: AppTextStyles.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'Ahmed Khan',
                        prefixIcon: Icon(LucideIcons.user, size: 16)),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Naam zaroori hai' : null,
                    ),
                    const SizedBox(height: 18),
                    Text('Email', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: AppTextStyles.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'admin@ahmedchemical.com',
                        prefixIcon: Icon(LucideIcons.mail, size: 16)),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Email sahi nahi' : null,
                    ),
                    const SizedBox(height: 18),
                    Text('Password', style: AppTextStyles.label),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      style: AppTextStyles.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: Icon(LucideIcons.lock, size: 16)),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Kam az kam 6 characters' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorSoft,
                          borderRadius: BorderRadius.circular(8)),
                        child: Text(_error!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error)),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(height: 18, width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                          : const Text('Create Account'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Pehle se account hai? Login'),
                    ),
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
