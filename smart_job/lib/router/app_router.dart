import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/controllers/auth_controller.dart';
import '../application/controllers/smart_job_controller.dart';
import '../presentation/applications/applications_screen.dart';
import '../presentation/auth/login_screen.dart';
import '../presentation/auth/register_screen.dart';
import '../presentation/cv/cv_page.dart';
import '../presentation/cv/cv_setup_screen.dart';
import '../presentation/home/home_screen.dart';
import '../presentation/main_shell/main_shell.dart';
import '../presentation/onboarding/onboarding_screen.dart';
import '../presentation/profile/profile_screen.dart';

abstract class AppRoute {
  static const login = '/login';
  static const register = '/register';
  static const onboarding = '/onboarding';
  static const main = '/main';
  static const cv = '/cv';
  static const cvSetup = '/cv-setup';
  static const applications = '/applications';
  static const profile = '/profile';
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final onboardingComplete = ref.watch(
    smartJobControllerProvider.select(
      (state) => state.profile.hasCompletedOnboarding,
    ),
  );

  return GoRouter(
    initialLocation: AppRoute.login,
    redirect: (context, state) {
      final location = state.uri.path;
      final isAuthRoute =
          location == AppRoute.login || location == AppRoute.register;

      if (!auth.isAuthenticated) {
        return isAuthRoute ? null : AppRoute.login;
      }

      if (!onboardingComplete &&
          location != AppRoute.onboarding &&
          location != AppRoute.cvSetup) {
        return AppRoute.onboarding;
      }

      if (onboardingComplete &&
          (isAuthRoute || location == AppRoute.onboarding || location == '/')) {
        return AppRoute.main;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoute.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoute.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoute.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoute.cvSetup,
        builder: (context, state) => const CvSetupScreen(),
      ),

      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: AppRoute.main,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRoute.cv,
            builder: (context, state) => const CVScreen(),
          ),
          GoRoute(
            path: AppRoute.applications,
            builder: (context, state) => const ApplicationsScreen(),
          ),
          GoRoute(
            path: AppRoute.profile,
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
    ],
  );
});









