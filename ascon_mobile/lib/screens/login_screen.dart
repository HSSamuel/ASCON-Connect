import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart'; // ✅ Required for kIsWeb check
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'home_screen.dart'; 
import '../config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ✅ PRODUCTION READY INITIALIZATION
  // On Web: Passes null (plugin uses index.html <meta> tag).
  // On Mobile: Passes the Web Client ID (so backend gets a valid token).
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: kIsWeb 
        ? null 
        : '641176201184-3q7t2hp3kej2vvei41tpkivn7j206bf7.apps.googleusercontent.com', 
    scopes: ['email', 'profile'],
  );
  
  bool _isLoading = false;
  bool _obscurePassword = true; 

  // --- EMAIL LOGIN LOGIC ---
  Future<void> loginUser() async {
    setState(() => _isLoading = true);
    // Uses the URL defined in config.dart (Production or Local)
    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/login'); 
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
        }),
      );
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', responseData['token']);
        
        if (responseData['user'] != null && responseData['user']['fullName'] != null) {
             await prefs.setString('user_name', responseData['user']['fullName']);
        }
        
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(userName: responseData['user']['fullName'])));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(responseData['message'] ?? 'Login failed'), 
          backgroundColor: Colors.red
        ));
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Connection Error. Please check your internet."), 
        backgroundColor: Colors.red
      ));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- GOOGLE LOGIN LOGIC ---
  Future<void> signInWithGoogle() async {
    try {
      setState(() => _isLoading = true);
      
      // 1. Trigger Google Sign In (Opens Dialog)
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      // If user cancelled the dialog, stop loading
      if (googleUser == null) { 
        setState(() => _isLoading = false); 
        return; 
      }
      
      // 2. Get the authentication tokens
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final url = Uri.parse('${AppConfig.baseUrl}/api/auth/google');
      
      // 3. Send ID Token to Backend for Verification
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': googleAuth.idToken}),
      );
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Success: Save Token & Navigate Home
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', data['token']);
        
        if (data['user'] != null && data['user']['fullName'] != null) {
             await prefs.setString('user_name', data['user']['fullName']);
        }
        
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen(userName: data['user']['fullName'])));
        
      } else if (response.statusCode == 404) {
        // New User: Navigate to Registration to complete profile
        if (!mounted) return;
        final googleData = data['googleData'];
        Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen(
          prefilledName: googleData['fullName'], 
          prefilledEmail: googleData['email']
        )));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please complete your Alumni details.")));
        
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(data['message'] ?? "Login Failed"), 
          backgroundColor: Colors.red
        ));
      }
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Google Sign-In failed."), 
        backgroundColor: Colors.red
      ));
    } finally {
       if (mounted) setState(() => _isLoading = false);
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
                // --- LOGO ---
                Center(
                  child: Container(
                    height: 100,
                    width: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
                    ),
                    child: Image.asset(
                      'assets/logo.png', 
                      errorBuilder: (c,o,s) => const Icon(Icons.school, size: 80, color: Color(0xFF1B5E3A)),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16), 

                // --- WELCOME TEXT ---
                Text(
                  'Welcome Back',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 24, 
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E3A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Sign in to access your alumni network',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                ),
                
                const SizedBox(height: 24), 

                // --- EMAIL INPUT ---
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12), 

                // --- PASSWORD INPUT ---
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey, size: 20),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                ),
                
                // --- FORGOT PASSWORD ---
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                    child: const Text("Forgot Password?", style: TextStyle(color: Color(0xFF1B5E3A), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),

                const SizedBox(height: 8),

                // --- LOGIN BUTTON ---
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

                // --- GOOGLE BUTTON ---
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
                
                // --- NEW HERE? ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("New here? ", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    GestureDetector(
                      onTap: () {
                        if (!_isLoading) Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                      },
                      child: const Text(
                        "Create Account",
                        style: TextStyle(color: Color(0xFF1B5E3A), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
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