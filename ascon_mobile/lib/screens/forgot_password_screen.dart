import 'package:flutter/material.dart';
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
          const SnackBar(content: Text("Email verified! Enter new password.")),
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
          const SnackBar(content: Text("Success! Login with new password.")),
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
      appBar: AppBar(
        title: const Text("Reset Password"),
        backgroundColor: const Color(0xFF1B5E3A),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_reset, size: 80, color: Color(0xFFD4AF37)),
            const SizedBox(height: 20),
            
            // IF NOT VERIFIED: Show Email Field
            if (!_isVerified) ...[
              const Text(
                "Enter your registered email to reset password.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email Address",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : verifyEmail,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E3A),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("VERIFY EMAIL"),
                ),
              ),
            ] 
            // IF VERIFIED: Show New Password Field
            else ...[
              const Text(
                "Identity Verified. Create a new password.",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "New Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : resetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E3A),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("RESET PASSWORD"),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}