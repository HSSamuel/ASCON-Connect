import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ Required to check if running on Web
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart'; // ✅ Import the new Splash Screen
import 'config/theme.dart'; // ✅ Import the new Theme File
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

  // NOTE: We removed the SharedPreferences check here because 
  // the SplashScreen now handles the "Are we logged in?" check.
  
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

      // ✅ 1. LIGHT THEME
      theme: AppTheme.lightTheme,

      // ✅ 2. DARK THEME
      darkTheme: AppTheme.darkTheme,

      // ✅ 3. AUTO-SWITCH (Uses System Settings)
      themeMode: ThemeMode.system, 

      // ✅ START APP WITH SPLASH SCREEN
      home: const SplashScreen(),
    );
  }
}