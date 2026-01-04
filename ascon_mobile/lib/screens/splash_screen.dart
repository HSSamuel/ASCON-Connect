import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';

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
    // Wait 3 seconds so the user sees the branding
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userName = prefs.getString('user_name');

    bool isValid = false;
    if (token != null) {
       isValid = await _authService.isSessionValid(); 
    }

    if (!mounted) return;

    if (token != null && isValid) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(userName: userName ?? "Alumnus")),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    const asconGreen = Color(0xFF1B5E20); 
    final glowColor = Colors.greenAccent.withOpacity(0.8);

    // Responsive sizing:
    // 1. Get screen width & height
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // 2. Calculate safe logo size
    // Use the SMALLER of width or height to ensure it fits on landscape phones or web
    double logoSize = (screenWidth < screenHeight ? screenWidth : screenHeight) * 0.5; 
    
    // 3. Cap the max size so it doesn't get ridiculously huge on tablets/web
    if (logoSize > 300) logoSize = 300;

    return Scaffold(
      backgroundColor: scaffoldBg, 
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          // ✅ FIX: SingleChildScrollView prevents overflow on small screens
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Shrink to fit content
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
                  "... the natural place for human capacity building",
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