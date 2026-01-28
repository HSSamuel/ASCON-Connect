import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:intl/intl.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:cached_network_image/cached_network_image.dart'; 
import '../widgets/full_screen_image.dart'; 
import 'chat_screen.dart'; 

class AlumniDetailScreen extends StatelessWidget {
  final Map<String, dynamic> alumniData;

  const AlumniDetailScreen({super.key, required this.alumniData});

  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  String _formatLastSeen(String? dateString) {
    if (dateString == null) return "Offline";
    try {
      final lastSeen = DateTime.parse(dateString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(lastSeen);

      if (diff.inMinutes < 1) return "Last seen just now";
      if (diff.inMinutes < 60) return "Last seen ${diff.inMinutes}m ago";
      
      if (now.day == lastSeen.day && now.month == lastSeen.month && now.year == lastSeen.year) {
        return "Last seen today at ${DateFormat('h:mm a').format(lastSeen)}";
      }
      
      final yesterday = now.subtract(const Duration(days: 1));
      if (yesterday.day == lastSeen.day && yesterday.month == lastSeen.month && yesterday.year == lastSeen.year) {
        return "Last seen yesterday at ${DateFormat('h:mm a').format(lastSeen)}";
      }

      return "Last seen ${DateFormat('MMM d, h:mm a').format(lastSeen)}";
    } catch (e) {
      return "Offline";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final scaffoldBg = isDark ? const Color(0xFF121212) : Colors.grey[50];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryColor = const Color(0xFF1B5E3A);
    
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[700];

    final String fullName = alumniData['fullName'] ?? 'Unknown Alumnus';
    final String job = alumniData['jobTitle'] ?? '';
    final String org = alumniData['organization'] ?? '';
    
    String rawBio = alumniData['bio'] ?? '';
    final String bio = rawBio.trim().isNotEmpty ? rawBio : 'No biography provided.';

    final bool showPhone = alumniData['isPhoneVisible'] == true;
    final bool isMentor = alumniData['isOpenToMentorship'] == true;
    
    final bool isOnline = alumniData['isOnline'] == true;
    final String statusText = isOnline ? "Active Now" : _formatLastSeen(alumniData['lastSeen']);

    final String phone = alumniData['phoneNumber'] ?? '';
    final String linkedin = alumniData['linkedin'] ?? '';
    final String email = alumniData['email'] ?? '';
    final String year = alumniData['yearOfAttendance']?.toString() ?? 'Unknown';
    final String imageString = alumniData['profilePicture'] ?? '';
    
    final String zoomHeroTag = "zoom_profile_${alumniData['_id'] ?? DateTime.now().millisecondsSinceEpoch}";

    final String programme = (alumniData['programmeTitle'] != null && alumniData['programmeTitle'].toString().isNotEmpty) 
        ? alumniData['programmeTitle'] 
        : 'Not Specified';

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text("Alumni Profile", style: GoogleFonts.lato(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 1. HEADER SECTION ---
            SizedBox(
              height: 150, 
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    width: double.infinity,
                    height: 100, 
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1B5E3A), Color(0xFF2E8B57)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                    ),
                  ),
                  Positioned(
                    top: 55, 
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (imageString.isNotEmpty && !imageString.contains('https://lh3.googleusercontent.com/a/ACg8ocLUAgz3dKVYY5ttmmjOi3u8H9kodBXwT0ZrOX2YK7DghVqRhopX=s96-c')) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullScreenImage(
                                imageUrl: imageString,
                                heroTag: zoomHeroTag,
                              ),
                            ),
                          );
                        }
                      },
                      child: Hero(
                        tag: zoomHeroTag,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: cardColor, width: 4),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))
                            ],
                          ),
                          child: _buildRobustAvatar(imageString, isDark),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10), 

            // --- 2. IDENTITY SECTION ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    fullName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold, 
                      color: textColor 
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  if (job.isNotEmpty || org.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.work_outline, size: 14, color: subTextColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            "$job${(job.isNotEmpty && org.isNotEmpty) ? ' at ' : ''}$org",
                            style: GoogleFonts.lato(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  
                  // Presence Status
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusText, 
                          style: GoogleFonts.lato(
                            color: isOnline ? Colors.green[700] : Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w600
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  if (isMentor)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.amber.shade600),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars_rounded, color: Colors.amber.shade700, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            "Open to Mentoring",
                            style: GoogleFonts.lato(color: Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                    ),
                    child: Text(
                      "Class of $year",
                      style: GoogleFonts.lato(color: const Color(0xFFB8860B), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            // ✅ NEW: REQUEST MENTORSHIP BUTTON (Only if they are a mentor)
            if (isMentor)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 10),
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          receiverId: alumniData['_id'] ?? '',
                          receiverName: fullName,
                          receiverProfilePic: imageString,
                          isOnline: isOnline,
                          lastSeen: alumniData['lastSeen'],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.handshake_rounded, color: Colors.white, size: 20),
                  label: Text("Request Mentorship", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[800], // Gold/Amber
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 2,
                  ),
                ),
              ),

            const SizedBox(height: 10),

            // --- 3. CONTACT ACTION BUTTONS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCircleAction(context, Icons.chat_bubble_outline, "Message", primaryColor, () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        receiverId: alumniData['_id'] ?? '',
                        receiverName: fullName,
                        receiverProfilePic: imageString,
                        isOnline: isOnline,
                        lastSeen: alumniData['lastSeen'],
                      ),
                    ),
                  );
                }),

                if (linkedin.isNotEmpty)
                  _buildCircleAction(context, Icons.link, "LinkedIn", Colors.blue[700]!, () => _launchURL(linkedin)),
                
                // Email is ALWAYS visible now
                if (email.isNotEmpty)
                  _buildCircleAction(context, Icons.email, "Email", Colors.red[400]!, () => _launchURL("mailto:$email")),
                
                if (showPhone && phone.isNotEmpty)
                  _buildCircleAction(context, Icons.phone, "Call", Colors.green[600]!, () => _launchURL("tel:$phone")),
              ],
            ),

            const SizedBox(height: 25),

            // --- 4. DETAILS CARDS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // About Me Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline_rounded, size: 20, color: primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              "About Me",
                              style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          bio,
                          style: GoogleFonts.lato(fontSize: 14, height: 1.6, color: subTextColor),
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Programme Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.school_outlined, color: primaryColor, size: 22),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Programme Attended",
                                style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                programme,
                                style: GoogleFonts.lato(
                                  fontSize: 14, 
                                  fontWeight: FontWeight.bold, 
                                  color: programme == 'Not Specified' ? Colors.grey : textColor
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRobustAvatar(String imageString, bool isDark) {
    if (imageString.isEmpty || imageString.contains('googleusercontent.com/profile/picture/0')) {
      return _buildPlaceholder(isDark);
    }

    if (imageString.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageString,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 45,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => _buildPlaceholder(isDark),
        errorWidget: (context, url, error) => _buildPlaceholder(isDark),
      );
    }

    try {
      return CircleAvatar(
        radius: 45,
        backgroundImage: MemoryImage(base64Decode(imageString)),
      );
    } catch (e) {
      return _buildPlaceholder(isDark);
    }
  }

  Widget _buildPlaceholder(bool isDark) {
    return CircleAvatar(
      radius: 45,
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      child: Icon(Icons.person, size: 45, color: isDark ? Colors.grey[500] : Colors.grey),
    );
  }

  Widget _buildCircleAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white; 
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))
                ],
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}