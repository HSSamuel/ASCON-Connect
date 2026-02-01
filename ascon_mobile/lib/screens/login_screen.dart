import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; 
import '../services/auth_service.dart';
import '../services/notification_service.dart'; 
import '../services/socket_service.dart'; // ✅ Import Socket Service
import '../config.dart'; // ✅ Import AppConfig
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'welcome_dialog.dart'; 
import 'home_screen.dart'; 

class LoginScreen extends StatefulWidget {
  // ✅ Accept pending notification payload to handle redirection after login
  final Map<String, dynamic>? pendingNavigation;

  const LoginScreen({super.key, this.pendingNavigation});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  // ✅ Use AppConfig for dynamic Client ID (Clean & Secure)
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb ? AppConfig.googleWebClientId : null,
    serverClientId: kIsWeb ? null : AppConfig.googleWebClientId,
  );
  
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true; 

  // --- HELPER METHODS ---

  Future<void> _handleLoginSuccess(Map<String, dynamic> user) async {
    _syncNotificationToken();

    // ✅ Connect Socket for Online Presence immediately
    if (user['_id'] != null) {
      SocketService().connectUser(user['_id']);
    }

    String safeName = user['fullName'] ?? "Alumni"; 

    // ✅ SMART REDIRECTION LOGIC
    // If this login was triggered by a notification click...
    if (widget.pendingNavigation != null) {
      debugPrint("🚀 Handling Pending Navigation after Login...");
      
      // 1. Navigate to Home first (to set the root of the stack)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(userName: safeName)),
        (route) => false,
      );
      
      // 2. Wait briefly for Home to initialize, then push the specific screen
      Future.delayed(const Duration(milliseconds: 600), () {
        NotificationService().handleNavigation(widget.pendingNavigation!);
      });
      return; // Exit early, skipping Welcome Dialog
    }

    // Standard Login Flow
    bool hasSeenWelcome = user['hasSeenWelcome'] ?? false;

    if (hasSeenWelcome) {
      _navigateToHome(safeName);
    } else {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WelcomeDialog(
          userName: safeName,
          onGetStarted: _markWelcomeAsSeen, 
        ),
      );
    }
  }

  Future<void> _syncNotificationToken() async {
    try {
      await NotificationService().syncToken();
      debugPrint("🔔 Token sync triggered after login");
    } catch (e) {
      debugPrint("⚠️ Failed to sync token on login: $e");
    }
  }

  Future<void> _markWelcomeAsSeen() async {
    try {
      await _authService.markWelcomeSeen(); 
    } catch (e) {
      debugPrint("❌ Failed to mark welcome as seen: $e");
    }
  }

  void _navigateToHome(String userName) {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(userName: userName)),
      (route) => false,
    );
  }

  // --- LOGIN LOGIC ---

  Future<void> loginUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill in all fields"), backgroundColor: Colors.orange));
      return;
    }
    FocusScope.of(context).unfocus();
    
    setState(() => _isEmailLoading = true);
    
    try {
      final result = await _authService.login(_emailController.text.trim(), _passwordController.text);
      if (!mounted) return;

      setState(() => _isEmailLoading = false);

      if (result['success']) {
        _handleLoginSuccess(result['data']['user']);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) setState(() => _isEmailLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Error: ${e.toString()}"), backgroundColor: Colors.red));
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      setState(() => _isGoogleLoading = true);
      
      GoogleSignInAccount? googleUser;

      // 1. Attempt Silent Login first (Web Best Practice)
      if (kIsWeb) {
        try {
          googleUser = await _googleSignIn.signInSilently();
        } catch (e) {
          debugPrint("Silent Sign-In failed or not available: $e");
        }
      }

      // 2. If Silent failed, use Popup (Standard Mobile/Web Fallback)
      if (googleUser == null) {
        try {
          googleUser = await _googleSignIn.signIn();
        } catch (error) {
          debugPrint("⚠️ Google Sign In Popup closed: $error");
          setState(() => _isGoogleLoading = false);
          return; 
        }
      }

      if (googleUser == null) {
        setState(() => _isGoogleLoading = false);
        return;
      }
      
      // 3. Get Token
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? tokenToSend = googleAuth.idToken ?? googleAuth.accessToken;

      if (tokenToSend == null) {
        debugPrint("❌ No valid token found from Google");
        setState(() => _isGoogleLoading = false);
        return;
      }
      
      // 4. Send to Backend
      final result = await _authService.googleLogin(tokenToSend);

      if (!mounted) return;

      setState(() => _isGoogleLoading = false);

      if (result['success']) {
        if (result['statusCode'] == 200) {
          _handleLoginSuccess(result['data']['user']);
        } else if (result['statusCode'] == 404) {
          final googleData = result['data']['googleData'];
          Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(
            prefilledName: googleData['fullName'], 
            prefilledEmail: googleData['email'],
            googleToken: googleAuth.idToken,
          )));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? "Google Login Failed"), backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint("❌ CRITICAL GOOGLE LOGIN ERROR: $e");
      if (mounted) {
        setState(() => _isGoogleLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("An error occurred during Google Login."), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardColor;

    final bool isAnyLoading = _isEmailLoading || _isGoogleLoading;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // LOGO
                Center(
                  child: Container(
                    height: 100, 
                    width: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black38 : Colors.black12,
                          blurRadius: 15,
                          offset: const Offset(0, 8), 
                        )
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png',
                        fit: BoxFit.cover, 
                        errorBuilder: (c, o, s) => Icon(Icons.school, size: 80, color: primaryColor),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16), 

                Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in to access your alumni network', 
                  textAlign: TextAlign.center, 
                  style: TextStyle(fontSize: 13, color: subTextColor)
                ),
                const SizedBox(height: 24), 

                // EMAIL INPUT
                TextFormField(
                  controller: _emailController,
                  enabled: !isAnyLoading,
                  style: TextStyle(fontSize: 14, color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: TextStyle(fontSize: 13, color: subTextColor),
                    prefixIcon: Icon(Icons.email_outlined, color: primaryColor, size: 20),
                  ),
                ),
                const SizedBox(height: 12), 

                // PASSWORD INPUT
                TextFormField(
                  controller: _passwordController,
                  enabled: !isAnyLoading,
                  obscureText: _obscurePassword,
                  style: TextStyle(fontSize: 14, color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: TextStyle(fontSize: 13, color: subTextColor),
                    prefixIcon: Icon(Icons.lock_outline, color: primaryColor, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isAnyLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    child: Text("Forgot Password?", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),

                const SizedBox(height: 8),

                // ✅ EMAIL LOGIN BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 45, 
                  child: ElevatedButton(
                    onPressed: isAnyLoading ? null : loginUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isEmailLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('LOGIN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 12),

                // ✅ GOOGLE LOGIN BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 45, 
                  child: OutlinedButton(
                    onPressed: isAnyLoading ? null : signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: cardColor, 
                    ),
                    child: _isGoogleLoading
                        ? SizedBox(
                            height: 20, 
                            width: 20, 
                            child: CircularProgressIndicator(color: primaryColor, strokeWidth: 2)
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login, color: primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Text("Continue with Google", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("New here? ", style: TextStyle(fontSize: 13, color: subTextColor)),
                    GestureDetector(
                      onTap: () {
                        if (!isAnyLoading) Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                      },
                      child: Text("Create Account", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}