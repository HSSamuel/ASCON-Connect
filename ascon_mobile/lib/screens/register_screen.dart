import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String? prefilledName;
  final String? prefilledEmail;
  final String? googleToken;

  const RegisterScreen({
    super.key, 
    this.prefilledName, 
    this.prefilledEmail, 
    this.googleToken
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  final _phoneController = TextEditingController();
  final _yearController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _customProgrammeController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ✅ HARDCODED LIST
  final List<String> _programmes = [
    "Management Programme",
    "Computer Programme",
    "Financial Management",
    "Leadership Development Programme",
    "Public Administration and Management",
    "Public Administration and Policy (Advanced)",
    "Public Sector Management Course",
    "Performance Improvement Course",
    "Creativity and Innovation Course",
    "Mandatory & Executive Programmes",
    "Postgraduate Diploma in Public Administration and Management",
    "Other"
  ];

  String? _selectedProgramme;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.prefilledName ?? '');
    _emailController = TextEditingController(text: widget.prefilledEmail ?? '');
  }

  // ✅ NEW: Beautiful Success Dialog
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must tap button to close
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
                ),
                const SizedBox(height: 20),
                
                // Title
                const Text(
                  "Registration Successful!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1B5E3A)),
                ),
                const SizedBox(height: 10),
                
                // Message
                Text(
                  "Your account has been created successfully.\nPlease login to continue.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 25),
                
                // Login Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close Dialog
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E3A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("GO TO LOGIN", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match"), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Logic: Determine final programme title
    String finalProgrammeTitle;
    if (_selectedProgramme == "Other") {
      finalProgrammeTitle = _customProgrammeController.text.trim();
    } else {
      finalProgrammeTitle = _selectedProgramme!;
    }

    final AuthService authService = AuthService();
    final result = await authService.register(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phoneNumber: _phoneController.text.trim(),
      programmeTitle: finalProgrammeTitle,
      yearOfAttendance: _yearController.text.trim(),
      googleToken: widget.googleToken,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      // ✅ Show Dialog instead of SnackBar
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? "Registration Failed"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1B5E3A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                
                // ✅ 1. LOGO (Centered)
                Center(
                  child: Container(
                    height: 100, width: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle, 
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))]
                    ),
                    child: Image.asset(
                      'assets/logo.png', 
                      errorBuilder: (c,o,s) => const Icon(Icons.school, size: 80, color: Color(0xFF1B5E3A))
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ✅ 2. HEADER TEXT (Centered)
                const Text(
                  "Create Account",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1B5E3A)),
                ),
                const SizedBox(height: 8),
                Text(
                  "Join the ASCON Alumni Network",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 30),

                _buildTextField("Full Name", _nameController, Icons.person_outline),
                const SizedBox(height: 16),
                _buildTextField("Email Address", _emailController, Icons.email_outlined),
                const SizedBox(height: 16),
                _buildTextField("Phone Number", _phoneController, Icons.phone_outlined, isNumber: true),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String>(
                  value: _selectedProgramme,
                  decoration: _inputDecoration("Programme Attended", Icons.school_outlined),
                  items: _programmes.map((prog) {
                    return DropdownMenuItem(
                      value: prog,
                      child: Text(
                        prog,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedProgramme = val),
                  validator: (val) => val == null ? 'Please select a programme' : null,
                  isExpanded: true,
                ),

                if (_selectedProgramme == "Other") ...[
                  const SizedBox(height: 16),
                  _buildTextField("Type Programme Name", _customProgrammeController, Icons.edit_outlined),
                ],

                const SizedBox(height: 16),
                
                _buildTextField("Year of Attendance (e.g. 2015)", _yearController, Icons.calendar_today_outlined, isNumber: true),
                const SizedBox(height: 16),
                
                _buildTextField("Password", _passwordController, Icons.lock_outline, isPassword: true),
                const SizedBox(height: 16),
                _buildTextField("Confirm Password", _confirmPasswordController, Icons.lock_outline, isPassword: true),

                const SizedBox(height: 30),

                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E3A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : const Text("REGISTER", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Already a member? ", style: TextStyle(color: Colors.grey[700])),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: const Text("Login", style: TextStyle(color: Color(0xFF1B5E3A), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isPassword = false, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      validator: (value) => value == null || value.isEmpty ? 'Field required' : null,
      style: const TextStyle(fontSize: 14),
      decoration: _inputDecoration(label, icon).copyWith(
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ) 
          : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      filled: true,
      fillColor: Colors.grey[50],
      prefixIcon: Icon(icon, color: const Color(0xFF1B5E3A), size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey[200]!)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1B5E3A), width: 1.5)),
    );
  }
}