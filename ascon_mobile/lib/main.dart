import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ Required to check if running on Web
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ FIX: Conditionally initialize Firebase
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        // Copy these exact strings from your Firebase Console > Project Settings > General > Your Web App
        apiKey: "AIzaSyBBteJZoirarB77b3Cgo67njG6meoGNq_U", 
        appId: "1:826004672204:web:4352aaeba03118fb68fc69", 
        messagingSenderId: "826004672204", 
        projectId: "ascon-alumni-91df2",
        
        // These are optional but good to have if provided:
        storageBucket: "ascon-alumni-91df2.firebasestorage.app", 
      ),
    );
  } else {
    // Android/iOS uses google-services.json automatically
    await Firebase.initializeApp();
  }

  // Initialize Notifications (Skip on Web for now to avoid errors until configured)
  if (!kIsWeb) {
    await NotificationService().init();
  }

  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('auth_token');
  final String? savedName = prefs.getString('user_name');

  runApp(MyApp(
    isLoggedIn: token != null, 
    userName: savedName ?? "Alumnus", 
  ));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final String userName;

  const MyApp({
    super.key, 
    required this.isLoggedIn, 
    required this.userName
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'ASCON Alumni',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto', 
        primaryColor: const Color(0xFF1B5E3A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E3A),
          primary: const Color(0xFF1B5E3A),
        ),
        useMaterial3: true,
      ),
      home: isLoggedIn ? HomeScreen(userName: userName) : const LoginScreen(),
    );
  }
}