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
import 'core/theme/theme_provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

late AndroidNotificationChannel channel;
late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set the background messaging handler early on, as a named top-level function
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  if (!kIsWeb) {
    channel = const AndroidNotificationChannel(
      'high_importance_channel', // id
      'High Importance Notifications', // title
      description: 'This channel is used for important notifications.', // description
      importance: Importance.max,
    );

    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    /// Create an Android Notification Channel.
    /// We use this channel in the `AndroidManifest.xml` file to override the default FCM channel to enable heads up notifications.
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    /// Update the iOS foreground notification presentation options to allow heads up notifications.
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      // If `onMessage` is triggered with a notification, construct our own local notification
      // to show it while the app is in the foreground.
      if (notification != null && android != null && !kIsWeb) {
        flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: android.smallIcon,
              importance: Importance.max,
              priority: Priority.high,
              ticker: 'ticker',
            ),
          ),
        );
      }
    });
  }

  runApp(const IneTeamApp());
}

class IneTeamApp extends StatelessWidget {
  const IneTeamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Theme provider for persistent dark/light toggle
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider(),
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
    final themeProvider = context.watch<ThemeProvider>();
    final themeMode = themeProvider.themeMode;
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