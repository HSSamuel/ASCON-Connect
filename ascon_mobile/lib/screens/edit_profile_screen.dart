import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/data_service.dart'; 

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final DataService _dataService = DataService(); 
  bool _isLoading = false;

  late TextEditingController _bioController;
  late TextEditingController _jobController;
  late TextEditingController _orgController;
  late TextEditingController _linkedinController;
  late TextEditingController _phoneController;
  late TextEditingController _yearController;
  late TextEditingController _otherProgrammeController;

  // ✅ NEW: Geolocation Controllers
  late TextEditingController _cityController;
  late TextEditingController _stateController;

  String? _selectedProgramme;
  
  // ✅ Mentorship & Privacy States
  bool _isOpenToMentorship = false; 
  bool _isLocationVisible = false; // ✅ NEW: Location Privacy Toggle

  Uint8List? _selectedImageBytes; 
  XFile? _pickedFile; // ✅ We keep this as XFile
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

    // ✅ NEW: Initialize Geolocation Controllers
    _cityController = TextEditingController(text: widget.userData['city'] ?? '');
    _stateController = TextEditingController(text: widget.userData['state'] ?? '');

    // ✅ Initialize Mentorship & Location Status from User Data
    _isOpenToMentorship = widget.userData['isOpenToMentorship'] == true;
    _isLocationVisible = widget.userData['isLocationVisible'] == true; // ✅ NEW

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
    _cityController.dispose(); // ✅ NEW
    _stateController.dispose(); // ✅ NEW
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 800,
    );

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
      final Map<String, String> fields = {
        'bio': _bioController.text.trim(),
        'jobTitle': _jobController.text.trim(),
        'organization': _orgController.text.trim(),
        'linkedin': _linkedinController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'yearOfAttendance': _yearController.text.trim(),
        
        // ✅ NEW: Include Geolocation Data
        'city': _cityController.text.trim(),
        'state': _stateController.text.trim(),
        'isLocationVisible': _isLocationVisible.toString(),

        // ✅ Send Mentorship Status (converted to string for multipart request)
        'isOpenToMentorship': _isOpenToMentorship.toString(), 
      };

      if (_selectedProgramme == "Other") {
        fields['programmeTitle'] = "Other";
        fields['customProgramme'] = _otherProgrammeController.text.trim();
      } else if (_selectedProgramme != null) {
        fields['programmeTitle'] = _selectedProgramme!;
        fields['customProgramme'] = "";
      }

      // ✅ FIX: PASS XFILE DIRECTLY (Do not convert to File)
      final bool success = await _dataService.updateProfile(fields, _pickedFile);

      if (!mounted) return;

      if (success) {
        Navigator.pop(context, true); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile Updated Successfully!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to update profile. Please try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  ImageProvider? getImageProvider() {
    if (_selectedImageBytes != null) return MemoryImage(_selectedImageBytes!);
    if (_currentUrl != null && _currentUrl!.startsWith('http')) return NetworkImage(_currentUrl!);
    return null;
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, bool isNumber = false}) {
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(fontSize: 14, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: subTextColor),
        prefixIcon: Icon(icon, color: primaryColor, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: primaryColor,
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
              const SizedBox(height: 20),

              _buildTextField("Job Title", _jobController, Icons.work),
              const SizedBox(height: 12),
              _buildTextField("Organization", _orgController, Icons.business),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _selectedProgramme,
                isExpanded: true,
                isDense: true,
                dropdownColor: cardColor,
                decoration: InputDecoration(
                  labelText: "Programme Attended",
                  labelStyle: TextStyle(fontSize: 13, color: subTextColor),
                  prefixIcon: Icon(Icons.school, color: primaryColor, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                ),
                items: _programmeOptions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(fontSize: 13, color: textColor),
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

              const SizedBox(height: 24),

              // ==========================================
              // ✅ NEW: GEOLOCATION & PRIVACY SECTION
              // ==========================================
              Align(
                alignment: Alignment.centerLeft,
                child: Text("Location", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor)),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField("City", _cityController, Icons.location_city),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField("State", _stateController, Icons.map_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ✅ NEW: LOCATION PRIVACY TOGGLE
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SwitchListTile(
                  title: const Text("Make Location Visible", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("Allow nearby alumni to find you on the map.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  value: _isLocationVisible,
                  activeColor: Colors.blue,
                  inactiveThumbColor: Colors.grey, 
                  inactiveTrackColor: Colors.grey.withOpacity(0.2),
                  onChanged: (bool value) {
                    setState(() {
                      _isLocationVisible = value;
                    });
                  },
                  secondary: Icon(Icons.location_on, color: _isLocationVisible ? Colors.blue : Colors.grey),
                ),
              ),

              const SizedBox(height: 12),

              // ✅ MENTORSHIP TOGGLE (Existing)
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SwitchListTile(
                  title: const Text("Open to Mentorship", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text("Allow other alumni to contact you for guidance.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  value: _isOpenToMentorship,
                  activeColor: const Color(0xFFD4AF37), // Gold for Mentors
                  
                  // ✅ FIX: Force colors for Inactive State
                  inactiveThumbColor: Colors.grey, 
                  inactiveTrackColor: Colors.grey.withOpacity(0.2),

                  onChanged: (bool value) {
                    setState(() {
                      _isOpenToMentorship = value;
                    });
                  },
                  secondary: Icon(Icons.stars, color: _isOpenToMentorship ? const Color(0xFFD4AF37) : Colors.grey),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
}