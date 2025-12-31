import 'dart:convert'; 
import 'package:http/http.dart' as http; 
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _yearController = TextEditingController();
  
  String? _selectedProgramme;
  bool _isLoading = false;
  bool _obscurePassword = true; // <--- NEW: Tracks password visibility
  
  final List<String> _programmes = [
    'Management Programme',
    'Computer Programme',
    'Financial Management',
    'Leadership Development Programme',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Registration"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF006400),
        elevation: 0,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Join the Network',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF006400),
                ),
              ),
              Text(
                'Enter your details for Admin verification.',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
              const SizedBox(height: 30),

              // FULL NAME
              _buildLabel("Full Name"),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration("Director Samuel"),
              ),
              const SizedBox(height: 15),

              // EMAIL
              _buildLabel("Email Address"),
              TextFormField(
                controller: _emailController,
                decoration: _inputDecoration("samuel@ascon.gov.ng"),
              ),
              const SizedBox(height: 15),

              // PASSWORD WITH EYE ICON
              _buildLabel("Password"),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword, // Use variable
                decoration: InputDecoration(
                  hintText: "******",
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  // EYE ICON:
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // YEAR OF ATTENDANCE
              _buildLabel("Year of Attendance"),
              TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration("2023"),
              ),
              const SizedBox(height: 15),

              // PROGRAMME DROPDOWN
              _buildLabel("Programme Attended"),
              DropdownButtonFormField<String>(
                value: _selectedProgramme,
                decoration: _inputDecoration("Select Programme"),
                items: _programmes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedProgramme = newValue;
                  });
                },
              ),
              const SizedBox(height: 40),

              // REGISTER BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : registerUser, 
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006400),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF006400).withOpacity(0.6),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        height: 24, 
                        width: 24, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'SUBMIT FOR APPROVAL',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: const OutlineInputBorder(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    );
  }

  Future<void> registerUser() async {
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _passwordController.text.isEmpty || 
        _yearController.text.isEmpty || 
        _selectedProgramme == null) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

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
          'programmeTitle': _selectedProgramme,
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (!mounted) return;
        showDialog(
          context: context, 
          barrierDismissible: false, 
          builder: (ctx) => AlertDialog(
            title: const Text("Registration Successful"),
            content: Text(responseData['message']),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); 
                  Navigator.pop(context); 
                }, 
                child: const Text("OK", style: TextStyle(color: Color(0xFF006400)))
              )
            ],
          )
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'] ?? "Registration failed"), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      print(error);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection failed. Check internet."), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}