import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'login_screen.dart';
import 'edit_profile_screen.dart'; // Import the new screen
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
    fetchProfile(); // Fetch data as soon as screen loads
  }

  // 1. Fetch Data from Backend
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
        setState(() {
          _userProfile = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching profile: $e");
      setState(() => _isLoading = false);
    }
  }

  // 2. Logout Logic
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Profile"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B5E3A),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : RefreshIndicator(
              onRefresh: fetchProfile, // Pull down to refresh data
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      // PROFILE PICTURE
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: const Color(0xFF1B5E3A),
                        // Logic: If user has a picture, decode and show it. Otherwise show Icon.
                        backgroundImage: (_userProfile?['profilePicture'] != null && 
                                          _userProfile!['profilePicture'].toString().isNotEmpty)
                            ? MemoryImage(base64Decode(_userProfile!['profilePicture']))
                            : null,
                        child: (_userProfile?['profilePicture'] == null || 
                                _userProfile!['profilePicture'].toString().isEmpty)
                            ? const Icon(Icons.person, size: 50, color: Colors.white)
                            : null,
                      ),

                      // NAME & JOB
                      Text(
                        _userProfile?['fullName'] ?? widget.userName,
                        style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _userProfile?['jobTitle'] == null || _userProfile!['jobTitle'] == "" 
                            ? "Alumnus" 
                            : "${_userProfile!['jobTitle']} at ${_userProfile!['organization']}",
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 30),

                      // INFO CARDS
                      _buildInfoCard(Icons.email, _userProfile?['email'] ?? "No Email"),
                      _buildInfoCard(Icons.phone, _userProfile?['phoneNumber'] == "" || _userProfile?['phoneNumber'] == null ? "No Phone Added" : _userProfile!['phoneNumber']),
                      _buildInfoCard(Icons.school, _userProfile?['programmeTitle'] ?? "Programme"),
                      _buildInfoCard(Icons.calendar_today, "Class of ${_userProfile?['yearOfAttendance']}"),

                      const SizedBox(height: 30),

                      // EDIT BUTTON
                      ListTile(
                        leading: const Icon(Icons.edit, color: Color(0xFF1B5E3A)),
                        title: const Text("Edit Details"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () async {
                          // Wait for result from Edit Screen
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditProfileScreen(userData: _userProfile ?? {}),
                            ),
                          );
                          // If saved, refresh the profile
                          if (result == true) {
                            fetchProfile();
                          }
                        },
                      ),
                      const Divider(),

                      // LOGOUT
                      ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text("Logout", style: TextStyle(color: Colors.red)),
                        onTap: () => logout(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard(IconData icon, String text) {
    return Card(
      elevation: 0,
      color: Colors.grey[50],
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF1B5E3A)),
        title: Text(text, style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}