import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Added for consistent fonts
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  
  bool _isLoading = false;
  bool _isVerified = false; // Tracks if we found the email
  String? _userId; // Stores the ID temporarily to reset password
  bool _obscurePassword = true; // Added visibility toggle

  // Step 1: Verify Email
  Future<void> verifyEmail() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/auth/forgot-password');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        setState(() {
          _isVerified = true; // Show password field
          _userId = data['userId']; // Save ID for next step
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Email verified! Enter new password."), backgroundColor: Colors.green),
        );
      } else {
        _showError(data['message'] ?? "Email not found");
      }
    } catch (e) {
      _showError("Connection Error");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Step 2: Reset Password
  Future<void> resetPassword() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/auth/reset-password');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _userId,
          'newPassword': _passController.text.trim()
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Success! Login with new password."), backgroundColor: Colors.green),
        );
        Navigator.pop(context); // Go back to Login
      } else {
        _showError("Failed to reset password");
      }
    } catch (e) {
      _showError("Connection Error");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ Clean White Background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B5E3A), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- ✅ LOGO ADDED ---
                Center(
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: Image.asset(
                      'assets/logo.png',
                      errorBuilder: (c, o, s) => const Icon(Icons.lock_reset, size: 80, color: Color(0xFF1B5E3A)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- HEADER TEXT ---
                Text(
                  _isVerified ? "Create New Password" : "Forgot Password?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E3A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isVerified 
                    ? "Please enter a strong new password."
                    : "Enter your registered email to verify your identity.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                ),
                
                const SizedBox(height: 30),
                
                // --- STEP 1: VERIFY EMAIL ---
                if (!_isVerified) ...[
                  SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _emailController,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "Email Address",
                        labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
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
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : verifyEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E3A),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text("VERIFY EMAIL", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] 
                
                // --- STEP 2: RESET PASSWORD ---
                else ...[
                  SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _passController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: "New Password",
                        labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
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
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : resetPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E3A),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text("RESET PASSWORD", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}