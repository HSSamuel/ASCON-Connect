import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ Required to check if running on Web
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ✅ Services & Config
import 'services/notification_service.dart';
import 'config/theme.dart';

// ✅ Screens (REQUIRED FOR ROUTES)
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

// Global Key for Notification Navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load the .env file
  await dotenv.load(fileName: ".env");

  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY'] ?? "",
        appId: dotenv.env['FIREBASE_APP_ID'] ?? "",
        messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? "",
        projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? "",
        storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? "",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }

  // ✅ Initialize Notifications (Robust Setup)
  if (!kIsWeb) {
    try {
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
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ASCON Alumni',
      debugShowCheckedModeBanner: false,

      // ✅ 1. THEMES
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, 

      // ✅ 2. HOME
      home: const SplashScreen(),

      // ✅ 3. CRITICAL: NAMED ROUTES (Restored)
      // These are required for Navigator.pushNamed to work
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}