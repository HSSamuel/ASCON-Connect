import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; 
import 'dart:convert';
import 'dart:typed_data'; 
import 'package:image_picker/image_picker.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late TextEditingController _bioController;
  late TextEditingController _jobController;
  late TextEditingController _orgController;
  late TextEditingController _linkedinController;
  late TextEditingController _phoneController;
  late TextEditingController _yearController;
  
  // ✅ Controller for custom input when "Other" is selected
  late TextEditingController _otherProgrammeController;

  String? _selectedProgramme;
  
  Uint8List? _selectedImageBytes; 
  XFile? _pickedFile; 
  String? _currentUrl; 

  // ✅ Matches Backend Enum exactly
  final List<String> _programmeOptions = [
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

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.userData['bio'] ?? '');
    _jobController = TextEditingController(text: widget.userData['jobTitle'] ?? '');
    _orgController = TextEditingController(text: widget.userData['organization'] ?? '');
    _linkedinController = TextEditingController(text: widget.userData['linkedin'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phoneNumber'] ?? '');
    _yearController = TextEditingController(text: widget.userData['yearOfAttendance']?.toString() ?? '');
    
    // Load existing custom text (if any)
    _otherProgrammeController = TextEditingController(text: widget.userData['customProgramme'] ?? '');

    // ✅ Logic: Determine Dropdown Selection
    String existingProg = widget.userData['programmeTitle'] ?? '';
    
    if (_programmeOptions.contains(existingProg)) {
      _selectedProgramme = existingProg;
    } else {
      _selectedProgramme = null;
    }
    
    // If "Other" was saved, or we have custom text, set dropdown to "Other"
    if (existingProg == "Other" || (widget.userData['customProgramme'] != null && widget.userData['customProgramme'].toString().isNotEmpty)) {
       _selectedProgramme = "Other";
    }

    _currentUrl = widget.userData['profilePicture'];
  }

  @override
  void dispose() {
    _bioController.dispose();
    _jobController.dispose();
    _orgController.dispose();
    _linkedinController.dispose();
    _phoneController.dispose();
    _yearController.dispose();
    _otherProgrammeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _pickedFile = pickedFile; 
        _selectedImageBytes = bytes; 
      });
    }
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final url = Uri.parse('${AppConfig.baseUrl}/api/profile/update');

      var request = http.MultipartRequest('PUT', url);
      request.headers['auth-token'] = token ?? '';

      // Add Standard Fields
      request.fields['bio'] = _bioController.text;
      request.fields['jobTitle'] = _jobController.text;
      request.fields['organization'] = _orgController.text;
      request.fields['linkedin'] = _linkedinController.text;
      request.fields['phoneNumber'] = _phoneController.text;
      request.fields['yearOfAttendance'] = _yearController.text;

      // ✅ LOGIC: Handle "Other" vs Standard
      if (_selectedProgramme == "Other") {
        // 1. Send "Other" to satisfy the enum validation
        request.fields['programmeTitle'] = "Other";
        // 2. Send the typed text to the custom field
        request.fields['customProgramme'] = _otherProgrammeController.text.trim();
      } else if (_selectedProgramme != null) {
        request.fields['programmeTitle'] = _selectedProgramme!;
        request.fields['customProgramme'] = ""; // Clear custom if they switched back
      }

      // Add Image (if changed)
      if (_pickedFile != null && _selectedImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'profilePicture', 
            _selectedImageBytes!,
            filename: _pickedFile!.name,
            contentType: MediaType('image', 'jpeg'), 
          ),
        );
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print("Status: ${response.statusCode}");
      print("Body: ${response.body}");

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully!")),
        );
      } 
      // ✅ FIX: Handle Expired Token (400/401)
      else if (response.statusCode == 400 || response.statusCode == 401) {
        if (!mounted) return;
        await prefs.clear(); // Clear bad token
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Session expired. Please login again."), backgroundColor: Colors.red),
        );
        // Navigate to Login (Replace '/login' with your login route name or MaterialPageRoute)
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
      else {
        throw Exception("Failed to update: ${response.body}");
      }
    } catch (e) {
      print("Upload Error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error updating profile."), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? getImageProvider() {
      if (_selectedImageBytes != null) return MemoryImage(_selectedImageBytes!);
      if (_currentUrl != null && _currentUrl!.startsWith('http')) return NetworkImage(_currentUrl!);
      return null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: const Color(0xFF1B5E3A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- AVATAR ---
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: const Color(0xFF1B5E3A),
                      backgroundImage: getImageProvider(),
                      child: getImageProvider() == null
                          ? const Icon(Icons.person, size: 60, color: Colors.white)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFD4AF37),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // --- FIELDS ---
              _buildTextField("Job Title", _jobController, Icons.work),
              const SizedBox(height: 15),
              _buildTextField("Organization", _orgController, Icons.business),
              const SizedBox(height: 15),
              
              // --- PROGRAMME DROPDOWN ---
              DropdownButtonFormField<String>(
                value: _selectedProgramme,
                decoration: const InputDecoration(
                  labelText: "Programme Attended",
                  prefixIcon: Icon(Icons.school, color: Colors.grey),
                  border: OutlineInputBorder(),
                ),
                isExpanded: true, 
                items: _programmeOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _selectedProgramme = newValue;
                  });
                },
                validator: (value) => value == null ? 'Please select a programme' : null,
              ),

              // ✅ CONDITIONAL INPUT FOR "OTHER"
              if (_selectedProgramme == "Other") ...[
                const SizedBox(height: 15),
                _buildTextField(
                  "Specify Programme Name", 
                  _otherProgrammeController, 
                  Icons.edit_note,
                ),
              ],
              
              const SizedBox(height: 15),
              _buildTextField("Class Year", _yearController, Icons.calendar_today, isNumber: true),
              const SizedBox(height: 15),
              _buildTextField("Phone Number", _phoneController, Icons.phone, isNumber: true),
              const SizedBox(height: 15),
              _buildTextField("LinkedIn URL", _linkedinController, Icons.link),
              const SizedBox(height: 15),
              _buildTextField("Short Bio", _bioController, Icons.person, maxLines: 3),
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E3A),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SAVE CHANGES"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: const OutlineInputBorder(),
        alignLabelWithHint: maxLines > 1, 
      ),
      // Validation for "Other" field
      validator: (value) {
        if (label == "Specify Programme Name" && _selectedProgramme == "Other" && (value == null || value.isEmpty)) {
          return "Please specify the programme name";
        }
        return null;
      },
    );
  }
}