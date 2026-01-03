import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart'; // ✅ Import Data Service
import 'login_screen.dart';
import 'edit_profile_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  final String userName;
  const ProfileScreen({super.key, required this.userName});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DataService _dataService = DataService(); // ✅ Use DataService
  final AuthService _authService = AuthService(); // ✅ Use AuthService for logout
  
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    // Uses the safe service method
    final profile = await _dataService.fetchProfile();
    
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
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
      await _authService.logout();
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
    if (imagePath.startsWith('http')) return NetworkImage(imagePath);
    try { return MemoryImage(base64Decode(imagePath)); } catch (e) { return null; }
  }

  @override
  Widget build(BuildContext context) {
    // Safely extract data with fallbacks
    final String fullName = _userProfile?['fullName'] ?? widget.userName;
    final String jobTitle = _userProfile?['jobTitle'] ?? '';
    final String org = _userProfile?['organization'] ?? '';
    final String programme = (_userProfile?['programmeTitle']?.toString().isNotEmpty ?? false)
        ? _userProfile!['programmeTitle'] : 'Add Programme';
    final String year = _userProfile?['yearOfAttendance']?.toString() ?? 'N/A';
    final String email = _userProfile?['email'] ?? 'No Email';
    final String phone = (_userProfile?['phoneNumber']?.toString().isNotEmpty ?? false)
        ? _userProfile!['phoneNumber'] : 'Add Phone Number';

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
            onPressed: _logout,
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E3A))) 
          : RefreshIndicator(
              onRefresh: _loadProfile, 
              color: const Color(0xFF1B5E3A),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
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
                        Positioned(
                          top: 90, 
                          child: Text("My Profile", style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18, fontWeight: FontWeight.w600)),
                        ),
                        Positioned(
                          top: 140, 
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8))],
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
                    const SizedBox(height: 60), 
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16), 
                      child: Column(
                        children: [
                          Text(fullName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 4), 
                          if (jobTitle.isNotEmpty || org.isNotEmpty)
                            Text("$jobTitle ${org.isNotEmpty ? 'at $org' : ''}", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          const SizedBox(height: 12), 
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8, runSpacing: 8,
                            children: [
                              _buildBadge(Icons.school, programme, isPlaceholder: programme == 'Add Programme'),
                              _buildBadge(Icons.calendar_today, "Class of $year", isPlaceholder: year == 'N/A'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20), 
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 45, 
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfileScreen(userData: _userProfile ?? {}),
                              ),
                            );
                            if (result == true) _loadProfile(); 
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
                    const SizedBox(height: 20), 
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16), 
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), 
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Contact Information", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B5E3A))),
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

  Widget _buildBadge(IconData icon, String text, {bool isPlaceholder = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPlaceholder ? Colors.orange[50] : const Color(0xFF1B5E3A).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isPlaceholder ? Colors.orange.withOpacity(0.3) : const Color(0xFF1B5E3A).withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isPlaceholder ? Colors.orange[800] : const Color(0xFF1B5E3A)),
          const SizedBox(width: 5),
          Flexible(child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isPlaceholder ? Colors.orange[800] : const Color(0xFF1B5E3A)), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8), 
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.grey[600], size: 18), 
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }
}