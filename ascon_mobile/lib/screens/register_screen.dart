import 'dart:convert'; // To send JSON data
import 'package:http/http.dart' as http; // To connect to the internet
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // 1. Controllers to capture text
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _yearController = TextEditingController();
  
  // 2. Variable for the Dropdown Menu
  String? _selectedProgramme;
  
  // The list of options exactly as they are in your Database
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
        title: Text("New Registration"),
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF006400), // Green Back Arrow
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
                  color: Color(0xFF006400),
                ),
              ),
              Text(
                'Enter your details for Admin verification.',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
              SizedBox(height: 30),

              // FULL NAME
              _buildLabel("Full Name"),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration("Director Samuel"),
              ),
              SizedBox(height: 15),

              // EMAIL
              _buildLabel("Email Address"),
              TextFormField(
                controller: _emailController,
                decoration: _inputDecoration("samuel@ascon.gov.ng"),
              ),
              SizedBox(height: 15),

              // PASSWORD
              _buildLabel("Password"),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: _inputDecoration("******"),
              ),
              SizedBox(height: 15),

              // YEAR OF ATTENDANCE
              _buildLabel("Year of Attendance"),
              TextFormField(
                controller: _yearController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration("2023"),
              ),
              SizedBox(height: 15),

              // PROGRAMME DROPDOWN
              _buildLabel("Programme Attended"),
              DropdownButtonFormField<String>(
                value: _selectedProgramme,
                decoration: _inputDecoration("Select Programme"),
                items: _programmes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: TextStyle(fontSize: 14)),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedProgramme = newValue;
                  });
                },
              ),
              SizedBox(height: 40),

              // REGISTER BUTTON
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
  registerUser(); // Call the function we just wrote
},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF006400),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
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

  // Helper functions to keep code clean
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    );
  }

  // Function to talk to the Backend
  Future<void> registerUser() async {
    // 1. Validation: Make sure they filled everything
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _passwordController.text.isEmpty || 
        _yearController.text.isEmpty || 
        _selectedProgramme == null) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields"), backgroundColor: Colors.red),
      );
      return;
    }

    // 2. Prepare the Data
    // Note: If testing on Android Emulator, use 'https://ascon.onrender.com/api/auth/register'
    // Since you are on Chrome/Web, localhost is fine.
    final url = Uri.parse('https://ascon.onrender.com/api/auth/register');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': _nameController.text,
          'email': _emailController.text,
          'password': _passwordController.text,
          'yearOfAttendance': int.parse(_yearController.text),
          'programmeTitle': _selectedProgramme,
        }),
      );

      // 3. Check the Server Response
      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // SUCCESS!
        // Show success message
        showDialog(
          context: context, 
          builder: (ctx) => AlertDialog(
            title: Text("Registration Successful"),
            content: Text(responseData['message']), // "Please wait for Admin approval"
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // Close dialog
                  Navigator.pop(context); // Go back to Login Screen
                }, 
                child: Text("OK")
              )
            ],
          )
        );
      } else {
        // FAILURE (e.g., Email already exists)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message']), backgroundColor: Colors.red),
        );
      }
    } catch (error) {
      // INTERNET ERROR
      print(error);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection failed. Is the server running?"), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}