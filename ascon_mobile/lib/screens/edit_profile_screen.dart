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
  late TextEditingController _otherProgrammeController;

  String? _selectedProgramme;
  Uint8List? _selectedImageBytes; 
  XFile? _pickedFile; 
  String? _currentUrl; 

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
    _otherProgrammeController = TextEditingController(text: widget.userData['customProgramme'] ?? '');

    String existingProg = widget.userData['programmeTitle'] ?? '';
    
    if (_programmeOptions.contains(existingProg)) {
      _selectedProgramme = existingProg;
    } else {
      _selectedProgramme = null;
    }
    
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

      request.fields['bio'] = _bioController.text;
      request.fields['jobTitle'] = _jobController.text;
      request.fields['organization'] = _orgController.text;
      request.fields['linkedin'] = _linkedinController.text;
      request.fields['phoneNumber'] = _phoneController.text;
      request.fields['yearOfAttendance'] = _yearController.text;

      if (_selectedProgramme == "Other") {
        request.fields['programmeTitle'] = "Other";
        request.fields['customProgramme'] = _otherProgrammeController.text.trim();
      } else if (_selectedProgramme != null) {
        request.fields['programmeTitle'] = _selectedProgramme!;
        request.fields['customProgramme'] = ""; 
      }

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

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully!")),
        );
      } else if (response.statusCode == 400 || response.statusCode == 401) {
        if (!mounted) return;
        await prefs.clear(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Session expired. Please login again."), backgroundColor: Colors.red),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      } else {
        throw Exception("Failed to update: ${response.body}");
      }
    } catch (e) {
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
        // 1. Reduced Padding from 20 to 16
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // --- AVATAR (Unchanged size) ---
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
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
              // 2. Reduced spacing from 30 to 20
              const SizedBox(height: 20),

              // --- FIELDS ---
              // 3. Compact Job & Org
              _buildTextField("Job Title", _jobController, Icons.work),
              const SizedBox(height: 12), // Reduced from 15
              _buildTextField("Organization", _orgController, Icons.business),
              const SizedBox(height: 12),
              
              // --- PROGRAMME DROPDOWN (Compact) ---
              DropdownButtonFormField<String>(
                value: _selectedProgramme,
                isExpanded: true,
                isDense: true, // Makes the dropdown height smaller
                decoration: const InputDecoration(
                  labelText: "Programme Attended",
                  prefixIcon: Icon(Icons.school, color: Colors.grey, size: 20),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12), // Reduced padding
                ),
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

              if (_selectedProgramme == "Other") ...[
                const SizedBox(height: 12),
                _buildTextField(
                  "Specify Programme Name", 
                  _otherProgrammeController, 
                  Icons.edit_note,
                ),
              ],
              
              const SizedBox(height: 12),
              
              // 4. SIDE-BY-SIDE: Class Year & Phone Number
              Row(
                children: [
                  Expanded(
                    child: _buildTextField("Class Year", _yearController, Icons.calendar_today, isNumber: true),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField("Phone", _phoneController, Icons.phone, isNumber: true),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              _buildTextField("LinkedIn URL", _linkedinController, Icons.link),
              const SizedBox(height: 12),
              _buildTextField("Short Bio", _bioController, Icons.person, maxLines: 3),
              
              // 5. Reduced spacing before button
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                height: 45, // Slightly reduced height from 50
                child: ElevatedButton(
                  onPressed: _isLoading ? null : saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E3A),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
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
      style: const TextStyle(fontSize: 14), // Slightly smaller font for compact feel
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20), // Smaller icon
        border: const OutlineInputBorder(),
        isDense: true, // Removes extra vertical space inside the field
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12), // Tighter padding
        alignLabelWithHint: maxLines > 1, 
      ),
      validator: (value) {
        if (label == "Specify Programme Name" && _selectedProgramme == "Other" && (value == null || value.isEmpty)) {
          return "Please specify";
        }
        return null;
      },
    );
  }
}