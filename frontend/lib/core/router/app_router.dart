import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_page.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/investors/presentation/pages/investor_detail_page.dart';
import '../../features/companies/presentation/pages/company_detail_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/landing/presentation/pages/landing_page.dart';
import '../../features/landing/presentation/pages/pricing_page.dart';
import '../widgets/main_scaffold.dart';

// Auth state notifier for router refresh
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier(Ref ref) {
    ref.listen(authStateProvider, (previous, next) {
      // Only notify if authentication status actually changed
      if (previous?.isAuthenticated != next.isAuthenticated) {
        debugPrint('>>> Auth changed: ${previous?.isAuthenticated} -> ${next.isAuthenticated}');
        notifyListeners();
      }
    });
  }
}

final _authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  return AuthChangeNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final authChangeNotifier = ref.watch(_authChangeNotifierProvider);

  debugPrint('>>> Router created (once)');

  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: authChangeNotifier,
    redirect: (context, state) {
      // Read auth state directly (don't watch - that causes router recreation)
      final container = ProviderScope.containerOf(context);
      final authState = container.read(authStateProvider);

      final isAuthenticated = authState.isAuthenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';
      final isLandingPage = state.matchedLocation == '/';
      final isPublicRoute = isLandingPage || state.matchedLocation == '/pricing';

      debugPrint('>>> Redirect check: location=${state.matchedLocation}, isAuth=$isAuthenticated, isAuthRoute=$isAuthRoute');

      // If user is not authenticated and trying to access protected route
      if (!isAuthenticated && !isAuthRoute && !isPublicRoute) {
        debugPrint('>>> Redirecting to /login (protected route)');
        return '/login';
      }

      // If user is authenticated and on landing page or auth routes, redirect to home
      if (isAuthenticated && (isAuthRoute || isLandingPage)) {
        debugPrint('>>> Redirecting to /home (already authenticated)');
        return '/home';
      }

      debugPrint('>>> No redirect needed');
      return null;
    },
    routes: [
      // Public routes
      GoRoute(
        path: '/',
        builder: (context, state) => const LandingPage(),
      ),
      GoRoute(
        path: '/pricing',
        builder: (context, state) => const PricingPage(),
      ),

      // Auth routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
      ),

      // App shell with navigation (minimalist: only Home and Settings)
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          // Home - primary destination
          GoRoute(
            path: '/home',
            builder: (context, state) {
              final locale = Localizations.localeOf(context);
              return HomePage(key: ValueKey('home_${locale.languageCode}'));
            },
          ),
          // Investor detail page (singular URL)
          GoRoute(
            path: '/investor/:id',
            builder: (context, state) {
              final id = state.pathParameters['id']!;
              // Use locale in key to force rebuild when language changes
              final locale = Localizations.localeOf(context);
              return InvestorDetailPage(
                key: ValueKey('investor_${id}_${locale.languageCode}'),
                investorId: id,
              );
            },
          ),
          // Company detail page
          GoRoute(
            path: '/companies/:ticker',
            builder: (context, state) {
              final ticker = state.pathParameters['ticker']!;
              final investorId = state.uri.queryParameters['investor'];
              final locale = Localizations.localeOf(context);
              return CompanyDetailPage(
                key: ValueKey('company_${ticker}_${locale.languageCode}'),
                ticker: ticker,
                investorId: investorId,
              );
            },
          ),
          // Settings
          GoRoute(
            path: '/settings',
            builder: (context, state) {
              final locale = Localizations.localeOf(context);
              return SettingsPage(key: ValueKey('settings_${locale.languageCode}'));
            },
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.matchedLocation}'),
      ),
    ),
  );
});
