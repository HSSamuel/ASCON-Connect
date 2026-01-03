import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; 
import '../services/auth_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'welcome_dialog.dart'; 
import 'home_screen.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
  // ✅ WEB: Uses the Web Client ID
  clientId: kIsWeb 
      ? '641176201184-3q7t2hp3kej2vvei41tpkivn7j206bf7.apps.googleusercontent.com' 
      : null,
  
  // ✅ ANDROID: ALSO asks for a token for the Web Client ID (so Backend accepts it)
  serverClientId: kIsWeb 
      ? null 
      : '641176201184-3q7t2hp3kej2vvei41tpkivn7j206bf7.apps.googleusercontent.com',
);
  
  bool _isLoading = false;
  bool _obscurePassword = true; 

  // ✅ PERMANENT DATABASE CHECK
  // This replaces the old SharedPreferences logic.
  Future<void> _handleLoginSuccess(Map<String, dynamic> user) async {
    // 1. Check the Database Flag directly from the User Object
    // If the field is missing (e.g. old user record), default to false.
    bool hasSeenWelcome = user['hasSeenWelcome'] ?? false;

    if (hasSeenWelcome) {
      // ⏩ OLD USER (Already seen it): Go Straight to Home
      print("🚀 LOGIN: User has already seen welcome dialog. Skipping.");
      _navigateToHome(user['fullName']);
    } else {
      // 👋 NEW USER (Or hasn't seen it): Show Dialog
      print("👋 LOGIN: First time (or reset). Showing Welcome Dialog.");
      
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return WelcomeDialog(
            userName: user['fullName'],
            // ✅ Pass callback to update the Database when they click "Get Started"
            onGetStarted: _markWelcomeAsSeen, 
          );
        },
      );
    }
  }

  // ✅ CALL BACKEND TO UPDATE FLAG
  Future<void> _markWelcomeAsSeen() async {
    try {
      // This calls the method you added to AuthService
      await _authService.markWelcomeSeen(); 
      print("✅ DATABASE: Welcome status marked as seen.");
    } catch (e) {
      print("❌ ERROR: Failed to mark welcome as seen: $e");
    }
  }

  // ✅ HELPER: Navigate to Home
  void _navigateToHome(String userName) {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen(userName: userName)),
      (route) => false,
    );
  }

  // --- CLEAN EMAIL LOGIN ---
  Future<void> loginUser() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields"), backgroundColor: Colors.orange)
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    
    final result = await _authService.login(
      _emailController.text.trim(), 
      _passwordController.text
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      // ✅ SUCCESS: Check DB flag
      _handleLoginSuccess(result['data']['user']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result['message']), 
        backgroundColor: Colors.red
      ));
    }
  }

  // --- ROBUST GOOGLE LOGIN ---
  Future<void> signInWithGoogle() async {
    try {
      setState(() => _isLoading = true);
      
      // 1. Try Standard Login
      GoogleSignInAccount? googleUser;
      try {
        googleUser = await _googleSignIn.signIn();
      } catch (error) {
        print("⚠️ Popup closed (Normal behavior on some browsers). Trying recovery...");
      }

      // 2. RECOVERY: If popup failed, check if we are secretly logged in already
      if (googleUser == null) {
        googleUser = await _googleSignIn.signInSilently();
      }

      // 3. If STILL null, then the user really cancelled.
      if (googleUser == null) { 
        setState(() => _isLoading = false); 
        return; 
      }
      
      print("✅ Google User Found: ${googleUser.email}");

      // ✅ 4. GET AUTHENTICATION (The part you were missing)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // ✅ 5. SEND TO BACKEND (The part you were missing)
      final result = await _authService.googleLogin(googleAuth.idToken);

      if (!mounted) return;
      setState(() => _isLoading = false);

      // 6. Handle Backend Response
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
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      print("❌ CRITICAL ERROR: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    height: 100, width: 100,
                    decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]),
                    child: Image.asset('assets/logo.png', errorBuilder: (c,o,s) => const Icon(Icons.school, size: 80, color: Color(0xFF1B5E3A))),
                  ),
                ),
                const SizedBox(height: 16), 

                const Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1B5E3A)),
                ),
                const SizedBox(height: 4),
                Text('Sign in to access your alumni network', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 24), 

                SizedBox(
                  height: 48,
                  child: TextFormField(
                    controller: _emailController,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: const TextStyle(fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1B5E3A), width: 1.5)),
                      prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1B5E3A), size: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 12), 

                SizedBox(
                  height: 48,
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(fontSize: 13),
                      filled: true,
                      fillColor: Colors.grey[50],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1B5E3A), width: 1.5)),
                      prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF1B5E3A), size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                ),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    child: const Text("Forgot Password?", style: TextStyle(color: Color(0xFF1B5E3A), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  height: 45, 
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : loginUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E3A),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('LOGIN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 45, 
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : signInWithGoogle,
                    icon: const Icon(Icons.login, color: Color(0xFF1B5E3A), size: 20),
                    label: const Text("Continue with Google", style: TextStyle(color: Color(0xFF1B5E3A), fontWeight: FontWeight.bold, fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF1B5E3A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("New here? ", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    GestureDetector(
                      onTap: () {
                        if (!_isLoading) Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                      },
                      child: const Text("Create Account", style: TextStyle(color: Color(0xFF1B5E3A), fontWeight: FontWeight.bold, fontSize: 13)),
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