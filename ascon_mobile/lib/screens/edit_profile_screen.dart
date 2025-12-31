import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data'; // ✅ REQUIRED for Web Image handling
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

  // ✅ FIX: Use Uint8List for cross-platform (Web & Mobile) image support
  Uint8List? _selectedImageBytes; 
  String? _base64Image; 

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.userData['bio'] ?? '');
    _jobController = TextEditingController(text: widget.userData['jobTitle'] ?? '');
    _orgController = TextEditingController(text: widget.userData['organization'] ?? '');
    _linkedinController = TextEditingController(text: widget.userData['linkedin'] ?? '');
    _phoneController = TextEditingController(text: widget.userData['phoneNumber'] ?? '');
    
    _base64Image = widget.userData['profilePicture']; 
  }

  // ✅ FIX: Read bytes directly from XFile (Works on Web & Mobile)
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes(); // Read into memory
      setState(() {
        _selectedImageBytes = bytes; // For display
        _base64Image = base64Encode(bytes); // For upload
      });
    }
  }

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      // Ensure you are using the correct URL (localhost for web)
      final url = Uri.parse('${AppConfig.baseUrl}/api/profile/update');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'auth-token': token ?? '',
        },
        body: jsonEncode({
          'bio': _bioController.text,
          'jobTitle': _jobController.text,
          'organization': _orgController.text,
          'linkedin': _linkedinController.text,
          'phoneNumber': _phoneController.text,
          'profilePicture': _base64Image,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully!")),
        );
      } else {
        throw Exception("Failed to update");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error updating profile.")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // --- AVATAR PICKER ---
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: const Color(0xFF1B5E3A),
                      // ✅ FIX: Use MemoryImage for the new selection
                      backgroundImage: _selectedImageBytes != null
                          ? MemoryImage(_selectedImageBytes!) // Show local selection
                          : (_base64Image != null && _base64Image!.isNotEmpty)
                              ? MemoryImage(base64Decode(_base64Image!)) // Show DB image
                              : null,
                      child: (_selectedImageBytes == null && (_base64Image == null || _base64Image!.isEmpty))
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
                            color: Color(0xFFD4AF37), // Gold
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

              // --- TEXT FIELDS ---
              _buildTextField("Job Title", _jobController, Icons.work),
              const SizedBox(height: 15),
              _buildTextField("Organization", _orgController, Icons.business),
              const SizedBox(height: 15),
              _buildTextField("Phone Number", _phoneController, Icons.phone),
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

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey),
        border: const OutlineInputBorder(),
      ),
    );
  }
}