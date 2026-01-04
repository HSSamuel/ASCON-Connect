import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ Required to check if running on Web
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart'; // ✅ Import the new Splash Screen
import 'config/theme.dart'; // ✅ Import the new Theme File

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ FIX: Conditionally initialize Firebase
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBBteJZoirarB77b3Cgo67njG6meoGNq_U", 
        appId: "1:826004672204:web:4352aaeba03118fb68fc69", 
        messagingSenderId: "826004672204", 
        projectId: "ascon-alumni-91df2",
        storageBucket: "ascon-alumni-91df2.firebasestorage.app", 
      ),
    );
  } else {
    // Android/iOS uses google-services.json automatically
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