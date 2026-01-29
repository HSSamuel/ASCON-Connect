import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart'; // ✅ Added for Deep Linking

import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/socket_service.dart';
import '../config/storage_config.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'chat_screen.dart'; // ✅ Added for Navigation

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

    // 1. Setup Animation (Fade In effect)
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    
    _controller.forward();

    // 2. Start Navigation Timer
    _checkSessionAndNavigate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkSessionAndNavigate() async {
    // Wait 2 seconds (reduced slightly) so the user sees the branding but app feels faster
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 1. Check Session Validity
    final bool isValid = await _authService.isSessionValid();
    
    // 2. Get User Name from Standard Preferences
    final prefs = await SharedPreferences.getInstance();
    final userName = prefs.getString('user_name') ?? "Alumnus";

    if (!mounted) return;

    if (isValid) {
      // ✅ FIX: Reconnect Socket immediately on Auto-Login
      try {
        // Just call initSocket(), it handles the connection logic internally
        SocketService().initSocket();
        debugPrint("🔌 Socket Initialized from Splash");
      } catch (e) {
        debugPrint("⚠️ Failed to reconnect socket on splash: $e");
      }

      // 3. Initialize Notifications (Mobile Only)
      if (!kIsWeb) {
         try {
           // We don't necessarily need to re-init here if main.dart did it, 
           // but it's safe to ensure permission/channels are ready.
           await NotificationService().init();
         } catch (e) {
           debugPrint("Error starting notifications: $e");
         }
      }

      // ✅ 4. Check for Notification Launch (Deep Link)
      RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();

      if (initialMessage != null && _isChatMessage(initialMessage)) {
        _navigateToChat(initialMessage, userName);
      } else {
        // Normal Navigation
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(userName: userName)),
        );
      }
    } else {
      // No Session -> Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // ✅ Helper: Check if notification is for chat
  bool _isChatMessage(RemoteMessage message) {
    return message.data['type'] == 'chat_message' ||
           message.data['route'] == 'chat_screen';
  }

  // ✅ Helper: Navigate to Home then Chat
  void _navigateToChat(RemoteMessage message, String userName) {
    final data = message.data;
    
    // 1. Go to Home first (so the user has a "Back" button context)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(userName: userName)),
    );
    
    // 2. Then push Chat Screen on top
    if (data['conversationId'] != null) {
      // Small delay to ensure Home is mounted
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: data['conversationId'],
              receiverId: data['senderId'] ?? '',
              receiverName: data['senderName'] ?? 'Alumni',
              receiverProfilePic: data['senderProfilePic'],
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    const asconGreen = Color(0xFF1B5E20); 
    final glowColor = Colors.greenAccent.withOpacity(0.8);

    // Responsive sizing
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
                // 1. THE LOGO
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
                    child: Image.asset(
                      'assets/logo.png',
                      fit: BoxFit.cover, 
                    ),
                  ),
                ),
                
                const SizedBox(height: 30), 

                // 2. THE GLOWING TEXT
                Text(
                  "... the natural place for human capacity building.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16, 
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white.withOpacity(0.9) : asconGreen,
                    shadows: [
                      Shadow(
                        blurRadius: 15.0, 
                        color: glowColor, 
                        offset: const Offset(0, 0), 
                      ),
                       Shadow(
                        blurRadius: 5.0, 
                        color: glowColor,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 50),

                // 3. LOADING INDICATOR
                CircularProgressIndicator(
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}