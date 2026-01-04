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

  // ✅ NEW: Beautiful Success Dialog (Dynamic Colors)
  void _showSuccessDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).cardColor;
    // final textColor = Theme.of(context).textTheme.bodyLarge?.color; // Unused variable removed

    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: bgColor, // ✅ Dynamic Background
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.green[900] : Colors.green[50], // ✅ Dynamic
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Colors.green, size: 60),
                ),
                const SizedBox(height: 20),
                
                // Title
                Text(
                  "Registration Successful!",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: 10),
                
                // Message
                Text(
                  "Your account has been created successfully.\nPlease login to continue.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color),
                ),
                const SizedBox(height: 25),
                
                // Login Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); 
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
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
      _showSuccessDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? "Registration Failed"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Dynamic Theme Colors
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Background handled by Theme
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // ✅ Matches background
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: primaryColor),
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
                
                // ✅ UPDATED LOGO: Matches Login Screen (No Padding, Large, Shadowed)
                Center(
                  child: Container(
                    height: 100, width: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // Shadow Effect
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black38 : Colors.black12,
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    // ClipOval for clean circle cut
                    child: ClipOval(
                      child: Image.asset(
                        'assets/logo.png', 
                        fit: BoxFit.cover, // Fills the circle
                        errorBuilder: (c,o,s) => Icon(Icons.school, size: 80, color: primaryColor)
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),

                // 2. HEADER TEXT
                Text(
                  "Create Account",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor),
                ),
                const SizedBox(height: 8),
                Text(
                  "Join the ASCON Alumni Network",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: subTextColor),
                ),
                const SizedBox(height: 30),

                _buildTextField("Full Name", _nameController, Icons.person_outline),
                const SizedBox(height: 16),
                _buildTextField("Email Address", _emailController, Icons.email_outlined),
                const SizedBox(height: 16),
                _buildTextField("Phone Number", _phoneController, Icons.phone_outlined, isNumber: true),
                const SizedBox(height: 16),
                
                // ✅ DROPDOWN (Now Dynamic)
                DropdownButtonFormField<String>(
                  value: _selectedProgramme,
                  dropdownColor: Theme.of(context).cardColor, // ✅ Fixes dropdown background
                  decoration: InputDecoration(
                    labelText: "Programme Attended",
                    labelStyle: TextStyle(fontSize: 13, color: subTextColor),
                    prefixIcon: Icon(Icons.school_outlined, color: primaryColor, size: 20),
                  ),
                  items: _programmes.map((prog) {
                    return DropdownMenuItem(
                      value: prog,
                      child: Text(
                        prog,
                        style: TextStyle(fontSize: 14, color: textColor), // ✅ Dynamic text
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
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text("REGISTER", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Already a member? ", style: TextStyle(color: subTextColor)),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      child: Text("Login", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
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

  // ✅ Updated Helper: Uses Global Theme automatically
  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isPassword = false, bool isNumber = false}) {
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(fontSize: 14, color: textColor), // ✅ Input Text
      validator: (value) => value == null || value.isEmpty ? 'Field required' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: subTextColor),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ) 
          : null,
      ),
    );
  }
}