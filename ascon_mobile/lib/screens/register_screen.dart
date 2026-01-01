import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config.dart';
import 'welcome_dialog.dart';

class RegisterScreen extends StatefulWidget {
  final String? prefilledName;
  final String? prefilledEmail;

  const RegisterScreen({super.key, this.prefilledName, this.prefilledEmail});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _yearController = TextEditingController();
  final _certificateController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledName != null) {
      _nameController.text = widget.prefilledName!;
    }
    if (widget.prefilledEmail != null) {
      _emailController.text = widget.prefilledEmail!;
    }
  }

  Future<void> registerUser() async {
    // 1. Check Empty Fields
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty ||
        _yearController.text.isEmpty ||
        _certificateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields"), backgroundColor: Colors.red),
      );
      return;
    }

    // 2. Check Passwords Match
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    final url = Uri.parse('${AppConfig.baseUrl}/api/auth/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'yearOfAttendance': int.parse(_yearController.text),
          'certificateNumber': _certificateController.text.trim(),
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (!mounted) return;
        // Trigger the Welcome Dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const WelcomeDialog(),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? "Registration failed"), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection failed. Check internet."), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 40, // Compact AppBar height
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B5E3A), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Compact padding for mobile
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- ✅ LOGO RE-INSERTED & CENTERED ---
                Center(
                  child: Container(
                    height: 80, // Slightly smaller than login for compactness
                    width: 80,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset(
                      'assets/logo.png', 
                      errorBuilder: (c,o,s) => const Icon(Icons.school, size: 60, color: Color(0xFF1B5E3A)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- ✅ HEADER TEXT CENTERED ---
                Text(
                  'Create Account',
                  textAlign: TextAlign.center, // Center alignment
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B5E3A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Join the Alumni Network',
                  textAlign: TextAlign.center, // Center alignment
                  style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
                ),

                const SizedBox(height: 20), // Compact Gap

                // --- FORM FIELDS (Compact Style) ---
                
                // Full Name
                _buildCompactField(_nameController, "Full Name", Icons.person_outline),
                const SizedBox(height: 12),

                // Email
                _buildCompactField(_emailController, "Email Address", Icons.email_outlined),
                const SizedBox(height: 12),

                // Password
                _buildCompactField(_passwordController, "Password", Icons.lock_outline, isPassword: true, isConfirm: false),
                const SizedBox(height: 12),

                // Confirm Password
                _buildCompactField(_confirmPasswordController, "Confirm Password", Icons.lock_outline, isPassword: true, isConfirm: true),
                const SizedBox(height: 12),

                // Year of Attendance
                _buildCompactField(_yearController, "Year of Attendance (e.g., 2023)", Icons.calendar_today_outlined, isNumber: true),
                const SizedBox(height: 12),

                // Certificate Number
                _buildCompactField(_certificateController, "Certificate Number", Icons.verified_user_outlined),
                
                const SizedBox(height: 24),

                // --- SUBMIT BUTTON ---
                SizedBox(
                  width: double.infinity,
                  height: 45, // Compact height
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E3A),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      disabledBackgroundColor: const Color(0xFF1B5E3A).withOpacity(0.6),
                    ),
                    child: _isLoading
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('CREATE ACCOUNT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 16),

                // --- FOOTER ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Already have an account? ", style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        "Login",
                        style: TextStyle(
                          color: Color(0xFF1B5E3A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper for Compact Input Fields
  Widget _buildCompactField(TextEditingController controller, String label, IconData icon, {bool isPassword = false, bool isConfirm = false, bool isNumber = false}) {
    return SizedBox(
      height: 48,
      child: TextFormField(
        controller: controller,
        obscureText: isPassword ? (isConfirm ? _obscureConfirmPassword : _obscurePassword) : false,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
          filled: true,
          fillColor: Colors.grey[50], // Very light grey fill
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1B5E3A), width: 1.5)),
          prefixIcon: Icon(icon, color: const Color(0xFF1B5E3A), size: 20),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    (isConfirm ? _obscureConfirmPassword : _obscurePassword) ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      if (isConfirm) {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      } else {
                        _obscurePassword = !_obscurePassword;
                      }
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }
}