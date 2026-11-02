import 'package:go_router/go_router.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/closet/closet_screen.dart';
import 'features/dress_up/dress_up_screen.dart';
import 'features/home/home_screen.dart';
import 'features/looks/looks_screen.dart';
import 'features/onboarding/onboarding_flow.dart';
import 'features/recreate/recreate_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/try_on/try_on_screen.dart';
import 'features/welcome/splash_screen.dart';
import 'features/welcome/welcome_screen.dart';
import 'models/models.dart';
import 'providers/auth_controller.dart';

GoRouter createRouter(AuthController auth) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (auth.initializing) return loc == '/splash' ? null : '/splash';

      final isPublic = loc == '/' || loc == '/login' || loc == '/signup';
      if (!auth.isSignedIn) return isPublic ? null : '/';
      // Don't route on a half-loaded session: returning users would be treated as new and sent to onboarding.
      if (auth.profileLoading) return isPublic || loc == '/splash' ? null : '/splash';
      if (isPublic || loc == '/splash') return auth.onboardingComplete ? '/app' : '/onboarding';
      if (!auth.onboardingComplete && loc != '/onboarding') return '/onboarding';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingFlow()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(
        path: '/recreate',
        builder: (_, state) =>
            RecreateScreen(initial: state.extra is RecreateResult ? state.extra as RecreateResult : null),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/app', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/app/closet', builder: (_, _) => const ClosetScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/app/dress-up', builder: (_, _) => const DressUpScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/app/try-on', builder: (_, _) => const TryOnScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/app/looks', builder: (_, _) => const LooksScreen())],
          ),
        ],
      ),
    ],
  );
}
