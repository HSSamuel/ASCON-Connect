import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ Required to check if running on Web
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // ✅ Required for Channel Setup

// ✅ Services & Config
import 'services/notification_service.dart';
import 'config/theme.dart';

// ✅ Screens (REQUIRED FOR ROUTES)
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

// Global Key for Notification Navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✅ DEFINE CHANNEL ID (Must match what you use in NotificationService)
const String channelId = 'ascon_high_importance'; 
const String channelName = 'ASCON Notifications';

// ✅ GLOBAL THEME CONTROLLER
// This allows the Home Screen to toggle Dark/Light mode dynamically.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  // ✅ MUST BE FIRST
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load the .env file
  await dotenv.load(fileName: ".env");

  if (kIsWeb) {
    // ✅ FIX: Ensure Firebase for Web is initialized only once
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: dotenv.env['FIREBASE_API_KEY'] ?? "",
            appId: dotenv.env['FIREBASE_APP_ID'] ?? "",
            messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? "",
            projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? "",
            storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? "",
          ),
        );
        debugPrint("✅ Firebase Web Initialized Successfully");
      }
    } catch (e) {
      debugPrint("⚠️ Firebase Web Init Error: $e");
    }
  } else {
    await Firebase.initializeApp();
  }

  // ✅ Initialize Notifications (Robust Setup - strictly for mobile)
  if (!kIsWeb) {
    try {
      // 1. SETUP CHANNEL EXPLICITLY
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId, 
        channelName, 
        description: 'This channel is used for important ASCON updates.',
        importance: Importance.max, 
        playSound: true,
        enableVibration: true,
      );

      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // 2. Init Service
      await NotificationService().init();
      debugPrint("✅ Notifications Initialized Successfully");
    } catch (e) {
      debugPrint("⚠️ Notification Init Failed: $e");
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ✅ Wrap MaterialApp in a builder that listens to theme changes
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'ASCON Alumni',
          debugShowCheckedModeBanner: false,

          // Themes
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          
          // ✅ This connects to the Toggle Button on Home Screen
          themeMode: currentMode, 

          home: const SplashScreen(),

          routes: {
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const HomeScreen(),
          },
        );
      },
    );
  }
}