import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart'; 

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

  ImageProvider? getProfileImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http')) {
      return NetworkImage(imagePath);
    } 
    try {
      return MemoryImage(base64Decode(imagePath));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final String fullName = alumniData['fullName'] ?? 'Unknown Alumnus';
    final String job = alumniData['jobTitle'] ?? '';
    final String org = alumniData['organization'] ?? '';
    final String bio = alumniData['bio'] ?? 'No biography provided.';
    final String phone = alumniData['phoneNumber'] ?? '';
    final String linkedin = alumniData['linkedin'] ?? '';
    final String email = alumniData['email'] ?? '';
    final String year = alumniData['yearOfAttendance']?.toString() ?? 'Unknown';
    final String imageString = alumniData['profilePicture'] ?? '';
    
    final String programme = (alumniData['programmeTitle'] != null && alumniData['programmeTitle'].toString().isNotEmpty) 
        ? alumniData['programmeTitle'] 
        : 'Not Specified';

    return Scaffold(
      backgroundColor: Colors.grey[50], // ✅ Light grey background to make cards pop
      appBar: AppBar(
        title: Text("Alumni Profile", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: const Color(0xFF1B5E3A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 1. HEADER SECTION ---
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Background Gradient
                Container(
                  width: double.infinity,
                  height: 100, // Compact height
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1B5E3A), Color(0xFF2E8B57)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                ),
                // Avatar with "Floating" Shadow
                Positioned(
                  bottom: -45, 
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 45, 
                      backgroundColor: Colors.grey[200],
                      backgroundImage: getProfileImage(imageString),
                      child: getProfileImage(imageString) == null
                          ? const Icon(Icons.person, size: 45, color: Colors.grey)
                          : null,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 55), 

            // --- 2. IDENTITY SECTION ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    fullName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 22, 
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  if (job.isNotEmpty || org.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.work_outline, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            "$job at $org",
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 10),
                  
                  // Class Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.1), // Gold tint
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                    ),
                    child: Text(
                      "Class of $year",
                      style: GoogleFonts.inter(
                        color: const Color(0xFFB8860B), 
                        fontWeight: FontWeight.bold,
                        fontSize: 12 
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 3. CONTACT ACTION BUTTONS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (linkedin.isNotEmpty)
                  _buildCircleAction(Icons.link, "LinkedIn", Colors.blue[700]!, () => _launchURL(linkedin)),
                
                if (email.isNotEmpty)
                  _buildCircleAction(Icons.email, "Email", Colors.red[400]!, () => _launchURL("mailto:$email")),
                
                if (phone.isNotEmpty)
                  _buildCircleAction(Icons.phone, "Call", Colors.green[600]!, () => _launchURL("tel:$phone")),
              ],
            ),

            const SizedBox(height: 25),

            // --- 4. DETAILS CARDS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // ✅ ENHANCED "ABOUT ME" CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF1B5E3A)),
                            const SizedBox(width: 8),
                            Text(
                              "About Me",
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E3A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          bio,
                          style: GoogleFonts.inter(fontSize: 14, height: 1.6, color: Colors.grey[800]),
                          textAlign: TextAlign.justify, // Pro look
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ✅ ACADEMIC RECORD CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E3A).withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school_outlined, color: Color(0xFF1B5E3A), size: 22),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Programme Attended",
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                programme,
                                style: GoogleFonts.inter(
                                  fontSize: 14, 
                                  fontWeight: FontWeight.bold, 
                                  color: programme == 'Not Specified' ? Colors.grey : Colors.black87
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

  // --- HELPER WIDGETS ---

  Widget _buildCircleAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white, // White bg for button
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))
                ],
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}