import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';
import 'edit_profile_screen.dart'; 
import '../config.dart';

class ProfileScreen extends StatefulWidget {
  final String userName;
  const ProfileScreen({super.key, required this.userName});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProfile(); 
  }

  Future<void> fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // Ensure this endpoint returns the 'programmeTitle' field in the JSON response
      final url = Uri.parse('${AppConfig.baseUrl}/api/profile/me');
      final response = await http.get(
        url,
        headers: {'auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _userProfile = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> logout() async {
    // Show confirmation dialog
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Logout", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // Helper to handle Image Logic
  ImageProvider? getProfileImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http')) {
      return NetworkImage(imagePath); 
    } else {
      try {
        return MemoryImage(base64Decode(imagePath)); 
      } catch (e) {
        return null; 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract values for cleaner code
    final String fullName = _userProfile?['fullName'] ?? widget.userName;
    final String jobTitle = _userProfile?['jobTitle'] ?? '';
    final String org = _userProfile?['organization'] ?? '';
    
    // ✅ Logic for Programme Title:
    // If fetched, show it. If null/empty, show "Add Programme" to prompt user.
    final String programme = (_userProfile?['programmeTitle'] != null && _userProfile!['programmeTitle'].toString().isNotEmpty)
        ? _userProfile!['programmeTitle']
        : 'Add Programme';

    final String year = _userProfile?['yearOfAttendance']?.toString() ?? 'N/A';
    final String email = _userProfile?['email'] ?? 'No Email';
    final String phone = (_userProfile?['phoneNumber'] != null && _userProfile!['phoneNumber'].toString().isNotEmpty) 
        ? _userProfile!['phoneNumber'] 
        : 'Add Phone Number';

    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for contrast
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: "Logout",
            onPressed: logout,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E3A))) 
          : RefreshIndicator(
              onRefresh: fetchProfile, 
              color: const Color(0xFF1B5E3A),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // --- 1. HEADER & AVATAR SECTION ---
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Green Gradient Background
                        Container(
                          height: 220,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1B5E3A), Color(0xFF2E8B57)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                          ),
                        ),
                        
                        // Page Title
                        Positioned(
                          top: 100,
                          child: Text(
                            "My Profile",
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.9), 
                              fontSize: 18, 
                              fontWeight: FontWeight.w600
                            ),
                          ),
                        ),

                        // The Overlapping Avatar
                        Positioned(
                          top: 160,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.grey[200],
                              backgroundImage: getProfileImage(_userProfile?['profilePicture']),
                              child: getProfileImage(_userProfile?['profilePicture']) == null
                                  ? const Icon(Icons.person, size: 60, color: Colors.grey)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 70), // Spacer for the overlapping avatar

                    // --- 2. IDENTITY SECTION ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Text(
                            fullName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 24, 
                              fontWeight: FontWeight.bold,
                              color: Colors.black87
                            ),
                          ),
                          const SizedBox(height: 6),
                          
                          // Job & Org
                          if (jobTitle.isNotEmpty || org.isNotEmpty)
                            Text(
                              "$jobTitle ${org.isNotEmpty ? 'at $org' : ''}",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 14, 
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500
                              ),
                            ),
                          
                          const SizedBox(height: 16),
                          
                          // Badges Row (Programme & Class)
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              // ✅ Programme Badge
                              _buildBadge(
                                Icons.school, 
                                programme, 
                                isPlaceholder: programme == 'Add Programme'
                              ),
                              
                              // Class Year Badge
                              _buildBadge(
                                Icons.calendar_today, 
                                "Class of $year",
                                isPlaceholder: year == 'N/A'
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // --- 3. EDIT BUTTON ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(userData: _userProfile ?? {}),
                              ),
                            );
                            if (result == true) fetchProfile(); // Refresh if updated
                          },
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          label: const Text("Edit Details"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E3A),
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // --- 4. CONTACT INFO CARD ---
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03), 
                            blurRadius: 10, 
                            offset: const Offset(0, 4)
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Contact Information",
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E3A)),
                          ),
                          const SizedBox(height: 15),
                          _buildContactRow(Icons.email_outlined, "Email", email),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                          _buildContactRow(Icons.phone_outlined, "Phone", phone),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildBadge(IconData icon, String text, {bool isPlaceholder = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isPlaceholder ? Colors.orange[50] : const Color(0xFF1B5E3A).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPlaceholder ? Colors.orange.withOpacity(0.3) : const Color(0xFF1B5E3A).withOpacity(0.1)
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon, 
            size: 14, 
            color: isPlaceholder ? Colors.orange[800] : const Color(0xFF1B5E3A)
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12, 
              fontWeight: FontWeight.w600, 
              color: isPlaceholder ? Colors.orange[800] : const Color(0xFF1B5E3A)
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.grey[600], size: 20),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }
}