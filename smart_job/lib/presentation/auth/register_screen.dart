import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../application/controllers/auth_controller.dart';
import '../../application/controllers/smart_job_controller.dart';
import '../../router/app_router.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isSubmitting) {
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final name = _nameController.text.trim();
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    try {
      final response = await AuthService.signUp(email, password);

      if (!mounted) {
        return;
      }

      if (response.session != null) {
        ref.read(authControllerProvider.notifier).signIn(email);
        ref.read(smartJobControllerProvider.notifier).registerAccount(
              fullName: name,
              email: email,
            );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Signup succeeded. Check your email to confirm your account before logging in.',
            ),
          ),
        );
      }
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signup failed. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SmartJobBackground(
        child: SmartJobScrollPage(
          maxWidth: 1180,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 940;

              if (isWide) {
                return ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 760),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _RegisterHero(isWide: true)),
                      const SizedBox(width: 32),
                      SizedBox(
                        width: 450,
                        child: _buildFormCard(context),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  const _RegisterHero(isWide: false),
                  const SizedBox(height: 24),
                  _buildFormCard(context),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SmartJobPanel(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create account', style: textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Create your SmartJob workspace and start a one-time onboarding flow for CV setup.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.subtext(Theme.of(context).brightness),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Full name is required'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(LucideIcons.user),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(LucideIcons.mail),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              validator: _validatePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(LucideIcons.lock),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                  icon: Icon(
                    _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmController,
              obscureText: _obscureConfirm,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords must match';
                }
                return null;
              },
              decoration: InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: const Icon(LucideIcons.shieldCheck),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscureConfirm = !_obscureConfirm;
                    });
                  },
                  icon: Icon(
                    _obscureConfirm ? LucideIcons.eyeOff : LucideIcons.eye,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Password rules: 8+ characters, one uppercase letter, one number, and one special character.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: Text(_isSubmitting ? 'Creating account...' : 'Create account'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSubmitting ? null : () => context.go(AppRoute.login),
              child: const Text('I already have an account'),
            ),
          ],
        ),
      ),
    ).animate().fade(delay: 120.ms).slideY(begin: 0.04);
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Minimum 8 characters';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Add an uppercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Add a number';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Add a special character';
    }
    return null;
  }
}

class _RegisterHero extends StatelessWidget {
  const _RegisterHero({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final alignment = isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = isWide ? TextAlign.left : TextAlign.center;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        if (!isWide) const SmartJobAppLogo(centered: true),
        if (isWide) const SmartJobAppLogo(),
        const SizedBox(height: 24),
        if (isWide)
          const SmartJobHeroLabel(label: 'Onboarding happens once')
        else
          const Center(
            child: SmartJobHeroLabel(label: 'Onboarding happens once'),
          ),
        const SizedBox(height: 24),
        Text(
          'Find jobs faster. Apply smarter. Track everything in one place.',
          textAlign: textAlign,
          style: textTheme.displayLarge,
        ).animate().fade().slideY(begin: 0.04),
        const SizedBox(height: 16),
        Text(
          'After signup, SmartJob will take you straight to a one-time CV setup where you can upload a real file or build one from scratch.',
          textAlign: textAlign,
          style: textTheme.bodyLarge?.copyWith(
            color: AppColors.subtext(Theme.of(context).brightness),
          ),
        ).animate().fade(delay: 80.ms),
        const SizedBox(height: 24),
        Wrap(
          alignment: isWide ? WrapAlignment.start : WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: const [
            SmartJobMetricPill(
              label: 'steps',
              value: '2',
              icon: LucideIcons.sparkles,
            ),
            SmartJobMetricPill(
              label: 'builder',
              value: 'CV',
              icon: LucideIcons.penTool,
            ),
            SmartJobMetricPill(
              label: 'tracking',
              value: 'Live',
              icon: LucideIcons.barChart3,
            ),
          ],
        ).animate().fade(delay: 140.ms),
      ],
    );
  }
}

