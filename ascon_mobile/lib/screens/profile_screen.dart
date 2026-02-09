import 'dart:convert';
import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart'; 
import 'package:google_fonts/google_fonts.dart'; 

import '../services/auth_service.dart';
import '../services/data_service.dart'; 
import '../services/socket_service.dart'; 
import '../utils/presence_formatter.dart'; 
import '../widgets/shimmer_utils.dart'; // ✅ Shimmer RESTORED

import 'edit_profile_screen.dart';
import 'document_request_screen.dart'; 
import 'mentorship_dashboard_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  final String? userName; 
  const ProfileScreen({super.key, this.userName}); 

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DataService _dataService = DataService(); 
  final AuthService _authService = AuthService(); 
  
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  double _completionPercent = 0.0; // ✅ For the Ring

  // STATE FOR REAL-TIME PRESENCE
  bool _isOnline = false;
  String? _lastSeen;
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel(); 
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await _dataService.fetchProfile();
    if (mounted) {
      setState(() {
        _userProfile = profile;
        _isLoading = false;
        
        _isOnline = profile?['isOnline'] == true;
        _lastSeen = profile?['lastSeen'];
        
        // ✅ Calculate Completion for the Ring
        _completionPercent = _calculateCompletion(profile ?? {});
      });

      _setupSocketListeners(profile?['_id']);
    }
  }

  // ✅ LOGIC: Profile Strength Calculation
  double _calculateCompletion(Map<String, dynamic> data) {
    int total = 6; 
    int filled = 0;
    if (data['fullName'] != null) filled++;
    if (data['profilePicture'] != null) filled++;
    if (data['jobTitle'] != null) filled++;
    if (data['bio'] != null) filled++;
    if (data['city'] != null) filled++;
    if (data['phoneNumber'] != null) filled++;
    return filled / total;
  }

  void _setupSocketListeners(String? userId) {
    if (userId == null) return;
    _statusSubscription?.cancel();
    _statusSubscription = SocketService().userStatusStream.listen((data) {
      if (!mounted) return;
      if (data['userId'] == userId) {
        setState(() {
          _isOnline = data['isOnline'];
          if (!_isOnline) _lastSeen = data['lastSeen'];
        });
      }
    });
  }

  Future<void> _logout() async {
    final dialogBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text("Logout", style: TextStyle(color: textColor)),
        content: Text("Are you sure you want to logout?", style: TextStyle(color: textColor)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Logout", style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (confirm) {
      SocketService().logoutUser();
      await _authService.logout();
      if (!mounted) return;
      context.go('/login');
    }
  }

  ImageProvider? getProfileImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http')) return NetworkImage(imagePath);
    try { return MemoryImage(base64Decode(imagePath)); } catch (e) { return null; }
  }

  String _formatLastSeen(String? dateString) {
    if (dateString == null) return "Offline";
    final formatted = PresenceFormatter.format(dateString);
    if (formatted == "Just now" || formatted == "Active just now") return "Active just now";
    return "Last seen $formatted";
  }

  String _formatPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return 'Add Phone Number';
    // Basic formatting logic
    return phone; 
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    // ✅ FIX 1: Use Skeleton instead of Spinner
    if (_isLoading) return Scaffold(backgroundColor: scaffoldBg, body: const ProfileSkeleton());

    final String fullName = _userProfile?['fullName'] ?? widget.userName ?? "Alumni";
    final String jobTitle = _userProfile?['jobTitle'] ?? '';
    final String org = _userProfile?['organization'] ?? '';
    final String industry = _userProfile?['industry'] ?? '';

    final String programme = (_userProfile?['programmeTitle']?.toString().isNotEmpty ?? false)
        ? _userProfile!['programmeTitle'] : 'Add Programme';
    final String year = _userProfile?['yearOfAttendance']?.toString() ?? 'N/A';
    final String email = _userProfile?['email'] ?? 'No Email';
    final String phone = _formatPhoneNumber(_userProfile?['phoneNumber']);
    final String bio = _userProfile?['bio'] ?? '';
    final String statusText = _isOnline ? "Active Now" : _formatLastSeen(_lastSeen);

    return Scaffold(
      backgroundColor: scaffoldBg,
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
      body: RefreshIndicator(
        onRefresh: _loadProfile, 
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              // --- HEADER SECTION ---
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
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // ✅ FIX 2: Animated Completion Ring
                        SizedBox(
                          width: 100, height: 100,
                          child: CircularProgressIndicator(
                            value: _completionPercent,
                            strokeWidth: 3,
                            backgroundColor: Colors.white.withOpacity(0.3),
                            color: Colors.amber, // Gold ring for "Pro" feel
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: cardColor, width: 4),
                          ),
                          child: CircleAvatar(
                            radius: 45,
                            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                            backgroundImage: getProfileImage(_userProfile?['profilePicture']),
                            child: getProfileImage(_userProfile?['profilePicture']) == null
                                ? Icon(Icons.person, size: 60, color: Colors.grey[400])
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60), 
              
              // --- NAME & BADGES ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16), 
                child: Column(
                  children: [
                    Text(fullName, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 4), 
                    // Simple subtitle fallback
                    if (jobTitle.isNotEmpty || org.isNotEmpty)
                      Text("$jobTitle ${org.isNotEmpty ? 'at $org' : ''}", textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w500)),
                    
                    const SizedBox(height: 8),

                    // Presence
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: _isOnline ? Colors.green : Colors.grey[400], shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText, 
                          style: TextStyle(color: _isOnline ? Colors.green[700] : Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),

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
              const SizedBox(height: 25), 

              // --- ABOUT ME ---
              if (bio.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("About Me", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 8),
                      Text(bio, textAlign: TextAlign.justify, style: TextStyle(fontSize: 14, color: textColor, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // ✅ FIX 3: CAREER TIMELINE (Replaces standard rows)
              if (jobTitle.isNotEmpty || org.isNotEmpty || industry.isNotEmpty) 
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timeline, size: 20, color: primaryColor),
                          const SizedBox(width: 8),
                          Text("Career Journey", style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // 1. Current Role
                      _buildTimelineItem(
                        title: jobTitle.isNotEmpty ? jobTitle : "Alumni",
                        subtitle: org.isNotEmpty ? org : "ASCON",
                        date: "Present",
                        isFirst: true,
                        isLast: false,
                        isActive: true,
                        lineColor: primaryColor,
                      ),
                      
                      // 2. Education (ASCON)
                      _buildTimelineItem(
                        title: "Student",
                        subtitle: programme,
                        date: year,
                        isFirst: false,
                        isLast: true,
                        isActive: false,
                        lineColor: primaryColor,
                      ),
                    ],
                  ),
                ),

              // --- EDIT BUTTON ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 45, 
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(userData: _userProfile ?? {})));
                      if (result == true) _loadProfile(); 
                    },
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text("Edit Details", style: TextStyle(fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20), 

              // --- CONTACT INFO ---
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16), 
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), 
                decoration: BoxDecoration(
                  color: cardColor, 
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Contact Information", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor)),
                    const SizedBox(height: 12),
                    _buildContactRow(Icons.email_outlined, "Email", email),
                    Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1, color: Theme.of(context).dividerColor)),
                    _buildContactRow(Icons.phone_outlined, "Phone", phone), 
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ALUMNI SERVICES
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16), 
                decoration: BoxDecoration(
                  color: cardColor, 
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text("Alumni Services", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor)),
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.description_outlined, color: Colors.blue),
                      ),
                      title: const Text("Document Requests", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text("Transcripts, certificates, etc.", style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const DocumentRequestScreen()));
                      },
                    ),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Divider(height: 1)),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.school_rounded, color: const Color(0xFFD4AF37)), 
                      ),
                      title: const Text("Mentorship Program", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: const Text("Manage requests & connections", style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) => const MentorshipDashboardScreen()));
                      },
                    ),
                    const SizedBox(height: 8),
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

  // ✅ WIDGET: Timeline Item (Vertical Connected Line)
  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    required String date,
    required bool isFirst,
    required bool isLast,
    required bool isActive,
    required Color lineColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time Column
        SizedBox(
          width: 60,
          child: Text(
            date, 
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, color: isActive ? lineColor : Colors.grey, fontWeight: FontWeight.bold)
          ),
        ),
        const SizedBox(width: 12),
        
        // Line & Dot
        Column(
          children: [
            Container(width: 2, height: 10, color: isFirst ? Colors.transparent : Colors.grey[300]),
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: isActive ? lineColor : Colors.grey[300],
                shape: BoxShape.circle,
                border: isActive ? Border.all(color: Colors.white, width: 2) : null
              ),
            ),
            Container(width: 2, height: 40, color: isLast ? Colors.transparent : Colors.grey[300]),
          ],
        ),
        const SizedBox(width: 12),
        
        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6), // Align with dot
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 20),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildBadge(IconData icon, String text, {bool isPlaceholder = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isPlaceholder 
            ? (isDark ? Colors.orange[900]!.withOpacity(0.3) : Colors.orange[50]) 
            : primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPlaceholder 
              ? (isDark ? Colors.orange[700]! : Colors.orange.withOpacity(0.3)) 
              : primaryColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isPlaceholder ? Colors.orange[700] : primaryColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text, 
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isPlaceholder ? Colors.orange[700] : primaryColor), 
              overflow: TextOverflow.ellipsis
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBg = isDark ? Colors.grey[800] : Colors.grey[50];
    final labelColor = Theme.of(context).textTheme.bodyMedium?.color;
    final valueColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8), 
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.grey[600], size: 18), 
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: labelColor)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: valueColor)),
            ],
          ),
        ),
      ],
    );
  }
}