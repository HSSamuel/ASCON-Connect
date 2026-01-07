import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; 
import '../services/auth_service.dart';
import '../services/notification_service.dart'; // ✅ Import Notification Service
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
    clientId: kIsWeb 
      ? '641176201184-3q7t2hp3kej2vvei41tpkivn7j206bf7.apps.googleusercontent.com' 
      : null,
    serverClientId: kIsWeb 
      ? null 
      : '641176201184-3q7t2hp3kej2vvei41tpkivn7j206bf7.apps.googleusercontent.com',
  );
  
  bool _isLoading = false;
  bool _obscurePassword = true; 

  // --- HELPER METHODS ---

  Future<void> _handleLoginSuccess(Map<String, dynamic> user) async {
    // ✅ CRITICAL FIX: Force Token Sync immediately after login
    // This ensures the server gets the FCM token now that we have an Auth Token.
    try {
      await NotificationService().init();
      debugPrint("🔔 Token sync triggered after login");
    } catch (e) {
      debugPrint("⚠️ Failed to sync token on login: $e");
    }

    bool hasSeenWelcome = user['hasSeenWelcome'] ?? false;
    if (hasSeenWelcome) {
      _navigateToHome(user['fullName']);
    } else {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WelcomeDialog(
          userName: user['fullName'],
          onGetStarted: _markWelcomeAsSeen, 
        ),
      );
    }
  }

  Future<void> _markWelcomeAsSeen() async {
    try {
      await _authService.markWelcomeSeen(); 
    } catch (e) {
      print("❌ ERROR: Failed to mark welcome as seen: $e");
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
    setState(() => _isLoading = true);
    
    final result = await _authService.login(_emailController.text.trim(), _passwordController.text);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      _handleLoginSuccess(result['data']['user']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message']), backgroundColor: Colors.red));
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      setState(() => _isLoading = true);
      GoogleSignInAccount? googleUser;
      try { googleUser = await _googleSignIn.signIn(); } catch (error) { print("⚠️ Popup closed."); }
      if (googleUser == null) { googleUser = await _googleSignIn.signInSilently(); }
      if (googleUser == null) { setState(() => _isLoading = false); return; }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final result = await _authService.googleLogin(googleAuth.idToken);

      if (!mounted) return;
      setState(() => _isLoading = false);

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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // ✅ UPDATED LOGO
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

                // ✅ EMAIL INPUT
                TextFormField(
                  controller: _emailController,
                  style: TextStyle(fontSize: 14, color: textColor),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle: TextStyle(fontSize: 13, color: subTextColor),
                    prefixIcon: Icon(Icons.email_outlined, color: primaryColor, size: 20),
                  ),
                ),
                const SizedBox(height: 12), 

                // ✅ PASSWORD INPUT
                TextFormField(
                  controller: _passwordController,
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
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    child: Text("Forgot Password?", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),

                const SizedBox(height: 8),

                // ✅ LOGIN BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 45, 
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : loginUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
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

                // ✅ GOOGLE BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 45, 
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : signInWithGoogle,
                    icon: Icon(Icons.login, color: primaryColor, size: 20),
                    label: Text("Continue with Google", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: primaryColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      backgroundColor: cardColor, 
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
                        if (!_isLoading) Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
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