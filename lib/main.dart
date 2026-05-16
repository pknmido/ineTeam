import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/auth/auth_provider.dart';
import 'features/profile/user_provider.dart';
import 'features/matches/match_provider.dart';
import 'features/notifications/notification_provider.dart';
import 'features/chat/chat_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const IneTeamApp());
}

class IneTeamApp extends StatelessWidget {
  const IneTeamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Theme mode notifier for dark/light toggle
        ChangeNotifierProvider<ValueNotifier<ThemeMode>>(
          create: (_) => ValueNotifier<ThemeMode>(ThemeMode.light),
        ),

        // Auth provider — manages login/signup state
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),

        // User provider — manages profile state
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(),
        ),

        // Match provider — manages matches state
        ChangeNotifierProvider<MatchProvider>(
          create: (_) => MatchProvider(),
        ),

        // Notification provider
        ChangeNotifierProvider<NotificationProvider>(
          create: (_) => NotificationProvider(),
        ),

        // Chat provider
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(),
        ),
      ],
      child: const _AppWithTheme(),
    );
  }
}

/// Extracted widget so it can read providers from the tree.
class _AppWithTheme extends StatefulWidget {
  const _AppWithTheme();

  @override
  State<_AppWithTheme> createState() => _AppWithThemeState();
}

class _AppWithThemeState extends State<_AppWithTheme> {
  @override
  void initState() {
    super.initState();
    // Listen to auth changes to initialize dependent providers
    final auth = context.read<AuthProvider>();
    auth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      // Load user profile and match streams once authenticated
      context.read<UserProvider>().loadProfile(auth.userId);
      context.read<MatchProvider>().initStreams(auth.userId);
      context.read<NotificationProvider>().initialize(auth.userId);
      context.read<ChatProvider>().initialize(auth.userId);
    } else {
      context.read<NotificationProvider>().initialize(null);
      context.read<ChatProvider>().initialize(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final themeMode = context.watch<ValueNotifier<ThemeMode>>().value;
    final router = AppRouter.router(authProvider);

    return MaterialApp.router(
      title: 'ineTeam',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}