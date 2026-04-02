import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../application/controllers/auth_controller.dart';
import '../../application/controllers/smart_job_controller.dart';
import '../../router/app_router.dart';
import '../../theme/app_colors.dart';
import '../shared/widgets/smart_job_ui.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final email = _emailController.text.trim().toLowerCase();

    ref.read(authControllerProvider.notifier).signIn(email);
    ref.read(smartJobControllerProvider.notifier).loadAccountForLogin(email);
    final hasCompletedOnboarding = ref
        .read(smartJobControllerProvider)
        .profile
        .hasCompletedOnboarding;
    context.go(
      hasCompletedOnboarding ? AppRoute.main : AppRoute.onboarding,
    );
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
                  constraints: const BoxConstraints(minHeight: 720),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: _AuthHero(isWide: true)),
                      const SizedBox(width: 32),
                      SizedBox(
                        width: 430,
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
                  const _AuthHero(isWide: false),
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
            Text('Login', style: textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Use your SmartJob account to jump back into applications, CV editing, and recruiter updates.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.subtext(Theme.of(context).brightness),
              ),
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Login'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.go(AppRoute.register),
              child: const Text('Create account'),
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
    return null;
  }
}

class _AuthHero extends StatelessWidget {
  const _AuthHero({required this.isWide});

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
          const SmartJobHeroLabel(label: 'Student-first career workspace')
        else
          const Center(
            child: SmartJobHeroLabel(label: 'Student-first career workspace'),
          ),
        const SizedBox(height: 24),
        Text(
          'Find jobs faster. Apply smarter. Track everything in one place.',
          textAlign: textAlign,
          style: textTheme.displayLarge,
        ).animate().fade().slideY(begin: 0.04),
        const SizedBox(height: 16),
        Text(
          'SmartJob combines your CV builder, personalized job feed, application tracker, and recruiter inbox into one calm, polished workflow.',
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
            _FeaturePill(
              icon: LucideIcons.fileSpreadsheet,
              text: 'Modular CV builder',
            ),
            _FeaturePill(
              icon: LucideIcons.briefcase,
              text: 'Smarter job matching',
            ),
            _FeaturePill(
              icon: LucideIcons.mailCheck,
              text: 'Unified recruiter inbox',
            ),
          ],
        ).animate().fade(delay: 140.ms),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(Theme.of(context).brightness).withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.stroke(Theme.of(context).brightness)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.teal),
          const SizedBox(width: 8),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
