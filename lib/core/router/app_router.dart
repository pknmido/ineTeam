import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_provider.dart';
import '../../presentation/screens/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/signup_screen.dart';
import '../../presentation/screens/profile/profile_setup_screen.dart';
import '../../presentation/screens/main_shell.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/match/match_detail_screen.dart';
import '../../presentation/screens/match/create_match_screen.dart';
import '../../presentation/screens/match/my_matches_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/notifications/notification_screen.dart';
import '../../presentation/screens/friends/friends_screen.dart';
import '../../presentation/screens/friends/chat_screen.dart';
import '../../presentation/screens/profile/user_detail_screen.dart';

/// Application router configuration using GoRouter.
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter router(AuthProvider authProvider) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/splash',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isAuthenticated = authProvider.isAuthenticated;
        final hasProfile = authProvider.hasCompletedProfile;
        final isProfileLoading = authProvider.isProfileLoading;
        final currentPath = state.matchedLocation;

        // Allow splash screen always
        if (currentPath == '/splash') return null;

        // Not authenticated → go to login
        if (!isAuthenticated) {
          if (currentPath == '/login' || currentPath == '/signup') return null;
          return '/login';
        }

        // If authenticated but we are still verifying profile in Firestore, WAIT.
        if (isProfileLoading) {
          return null; // stay on splash/current page until we know
        }

        // Authenticated but no profile → go to profile setup
        if (!hasProfile) {
          if (currentPath == '/profile-setup') return null;
          return '/profile-setup';
        }

        // Authenticated + has profile, but on auth pages → go to My Matches natively
        if (currentPath == '/login' ||
            currentPath == '/signup') {
          return '/my-matches';
        }

        return null;
      },
      routes: [
        // Splash
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),

        // Auth routes
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignupScreen(),
        ),

        // Profile setup (first time)
        GoRoute(
          path: '/profile-setup',
          builder: (context, state) => const ProfileSetupScreen(),
        ),

        // Main shell with bottom navigation
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/my-matches',
              builder: (context, state) => const MyMatchesScreen(),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),

        // Full-screen routes (outside shell)
        GoRoute(
          path: '/match/:matchId',
          builder: (context, state) {
            final matchId = state.pathParameters['matchId']!;
            return MatchDetailScreen(matchId: matchId);
          },
        ),
        GoRoute(
          path: '/create-match',
          builder: (context, state) => const CreateMatchScreen(),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationScreen(),
        ),
        GoRoute(
          path: '/friends',
          builder: (context, state) => const FriendsScreen(),
        ),
        GoRoute(
          path: '/chat/:chatId',
          builder: (context, state) {
            final chatId = state.pathParameters['chatId']!;
            return ChatScreen(chatId: chatId);
          },
        ),
        GoRoute(
          path: '/user/:userId',
          builder: (context, state) {
            final userId = state.pathParameters['userId']!;
            return UserDetailScreen(userId: userId);
          },
        ),
      ],
    );
  }
}
