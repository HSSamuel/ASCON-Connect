import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:go_router/go_router.dart'; 

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';
import 'edit_profile_screen.dart'; // ✅ Added Import

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    
    _controller.forward();
    _checkSessionAndNavigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkSessionAndNavigate() async {
    // 1. Wait for animation
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // 2. Check Session Validity
    final bool isValid = await _authService.isSessionValid();
    
    // 3. Determine Next Destination
    final String nextPath = isValid ? '/home' : '/login';

    if (isValid) {
      try {
        SocketService().initSocket();
        // Initialize notifications if possible
        NotificationService().init();
      } catch (e) {
        debugPrint("⚠️ Init error: $e");
      }

      // ✅ 3b. SPLASH GUARD: CHECK PROFILE COMPLETENESS
      // If the user has no Year of Attendance, force them to complete profile now.
      final user = await _authService.getCachedUser();
      var year = user?['yearOfAttendance'];
      
      // Check for null, 0, string "null", or empty string
      bool isProfileIncomplete = year == null || 
                                 year == 0 || 
                                 year == "null" || 
                                 year.toString().trim().isEmpty;

      if (isProfileIncomplete) {
        debugPrint("⚠️ Splash Guard: Incomplete Profile Detected. Redirecting to Edit Profile.");
        if (!mounted) return;
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EditProfileScreen(
              userData: user ?? {},
              isFirstTime: true, // Forces "Onboarding Mode" (No back button)
            ),
          ),
        );
        return; // 🛑 STOP EXECUTION HERE
      }
    }

    if (!mounted) return;

    // ✅ 4. CHECK NOTIFICATION PERMISSION STATE
    final prefs = await SharedPreferences.getInstance();
    
    // ⚠️ FOR TESTING ONLY: Uncomment the line below to reset the "seen" status
    // await prefs.remove('has_seen_notification_prompt'); 

    bool hasSeenPrompt = prefs.getBool('has_seen_notification_prompt') ?? false;
    
    // Check system permission status
    final status = await NotificationService().getAuthorizationStatus();
    bool isAuthorized = status == AuthorizationStatus.authorized;

    // If never seen prompt AND not already authorized -> Go to Permission Screen
    // (Removed !kIsWeb check so you can test on Chrome)
    if (!hasSeenPrompt && !isAuthorized) {
      context.go('/notification_permission', extra: nextPath);
      return;
    }

    // 5. Normal Navigation (Deep Link or Next Path)
    if (isValid) {
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null && _isChatMessage(initialMessage)) {
        context.go('/home');
      } else {
        context.go('/home');
      }
    } else {
      context.go('/login');
    }
  }

  bool _isChatMessage(RemoteMessage message) {
    return message.data['type'] == 'chat_message' ||
           message.data['route'] == 'chat_screen';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    const asconGreen = Color(0xFF1B5E20); 
    final glowColor = Colors.greenAccent.withOpacity(0.8);

    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;
    double logoSize = (screenWidth < screenHeight ? screenWidth : screenHeight) * 0.5; 
    if (logoSize > 300) logoSize = 300;

    return Scaffold(
      backgroundColor: scaffoldBg, 
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.grey[900] : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black54 : Colors.black26,
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 30), 
                Text(
                  "... the natural place for human capacity building.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16, 
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white.withOpacity(0.9) : asconGreen,
                    shadows: [
                      Shadow(blurRadius: 15.0, color: glowColor, offset: const Offset(0, 0)),
                      Shadow(blurRadius: 5.0, color: glowColor, offset: const Offset(0, 0)),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
                CircularProgressIndicator(color: Theme.of(context).primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}