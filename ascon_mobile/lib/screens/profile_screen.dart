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
    final String fullName = _userProfile?['fullName'] ?? widget.userName;
    final String jobTitle = _userProfile?['jobTitle'] ?? '';
    final String org = _userProfile?['organization'] ?? '';
    
    final String programme = (_userProfile?['programmeTitle'] != null && _userProfile!['programmeTitle'].toString().isNotEmpty)
        ? _userProfile!['programmeTitle']
        : 'Add Programme';

    final String year = _userProfile?['yearOfAttendance']?.toString() ?? 'N/A';
    final String email = _userProfile?['email'] ?? 'No Email';
    final String phone = (_userProfile?['phoneNumber'] != null && _userProfile!['phoneNumber'].toString().isNotEmpty) 
        ? _userProfile!['phoneNumber'] 
        : 'Add Phone Number';

    return Scaffold(
      backgroundColor: Colors.grey[50], 
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
                        // Green Gradient Background (Reduced Height 220 -> 200)
                        Container(
                          height: 200,
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
                          top: 90, // Adjusted top position
                          child: Text(
                            "My Profile",
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.9), 
                              fontSize: 18, 
                              fontWeight: FontWeight.w600
                            ),
                          ),
                        ),

                        // The Overlapping Avatar (Size Unchanged)
                        Positioned(
                          top: 140, // Moved up slightly to compact
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
                              radius: 45,
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

                    // Spacer for the overlapping avatar (Reduced 70 -> 60)
                    const SizedBox(height: 60), 

                    // --- 2. IDENTITY SECTION ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16), // Reduced side padding
                      child: Column(
                        children: [
                          Text(
                            fullName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 22, // Reduced font size 24 -> 22
                              fontWeight: FontWeight.bold,
                              color: Colors.black87
                            ),
                          ),
                          const SizedBox(height: 4), // Reduced spacing 6 -> 4
                          
                          // Job & Org
                          if (jobTitle.isNotEmpty || org.isNotEmpty)
                            Text(
                              "$jobTitle ${org.isNotEmpty ? 'at $org' : ''}",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13, // Reduced font size 14 -> 13
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500
                              ),
                            ),
                          
                          const SizedBox(height: 12), // Reduced spacing 16 -> 12
                          
                          // Badges Row (Programme & Class)
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8, // Reduced spacing 10 -> 8
                            runSpacing: 8,
                            children: [
                              _buildBadge(
                                Icons.school, 
                                programme, 
                                isPlaceholder: programme == 'Add Programme'
                              ),
                              
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

                    const SizedBox(height: 20), // Reduced spacing 25 -> 20

                    // --- 3. EDIT BUTTON ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 45, // Slimmer button 50 -> 45
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(userData: _userProfile ?? {}),
                              ),
                            );
                            if (result == true) fetchProfile(); 
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text("Edit Details", style: TextStyle(fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E3A),
                            foregroundColor: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20), // Reduced spacing 30 -> 20

                    // --- 4. CONTACT INFO CARD (Compact) ---
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16), // Reduced margin
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), // Reduced padding
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03), 
                            blurRadius: 8, 
                            offset: const Offset(0, 3)
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Contact Information",
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E3A)),
                          ),
                          const SizedBox(height: 12),
                          _buildContactRow(Icons.email_outlined, "Email", email),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
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

  // --- WIDGET BUILDERS (Compact) ---

  Widget _buildBadge(IconData icon, String text, {bool isPlaceholder = false}) {
    return Container(
      // Reduced internal padding
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            size: 13, // Smaller icon
            color: isPlaceholder ? Colors.orange[800] : const Color(0xFF1B5E3A)
          ),
          const SizedBox(width: 5),
          Flexible( // Added Flexible to prevent overflow
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11, // Smaller font
                fontWeight: FontWeight.w600, 
                color: isPlaceholder ? Colors.orange[800] : const Color(0xFF1B5E3A)
              ),
              overflow: TextOverflow.ellipsis,
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
          padding: const EdgeInsets.all(8), // Reduced padding 10 -> 8
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.grey[600], size: 18), // Smaller icon
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]), // Smaller label
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87), // Smaller text
              ),
            ],
          ),
        ),
      ],
    );
  }
}