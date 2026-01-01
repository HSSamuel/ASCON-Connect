import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  // 1. Initialize Flutter Bindings before running app
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Check Local Storage for existing Token
  final prefs = await SharedPreferences.getInstance();
  final String? token = prefs.getString('auth_token');
  final String? savedName = prefs.getString('user_name');

  // 3. Run App with the initial Auth State
  runApp(MyApp(
    isLoggedIn: token != null, 
    userName: savedName ?? "Alumnus", // Default fallback name
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
      title: 'ASCON Alumni',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Using ASCON Green as primary color
        primaryColor: const Color(0xFF1B5E3A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E3A),
          primary: const Color(0xFF1B5E3A),
        ),
        useMaterial3: true,
        fontFamily: 'Inter', // Ensure you have this font or remove this line
      ),
      
      // ✅ LOGIC: If Logged In -> Go to Dashboard. Else -> Go to Login.
      home: isLoggedIn ? HomeScreen(userName: userName) : const LoginScreen(),
    );
  }
}