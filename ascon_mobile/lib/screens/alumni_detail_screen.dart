import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart'; 

class AlumniDetailScreen extends StatelessWidget {
  final Map<String, dynamic> alumniData;

  const AlumniDetailScreen({super.key, required this.alumniData});

  // --- HELPER: Launch URLs Safely ---
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

  // --- HELPER: Smart Image Loader (URL vs Base64) ---
  ImageProvider? getProfileImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    
    // 1. Check if it is a URL (Cloudinary/S3)
    if (imagePath.startsWith('http')) {
      return NetworkImage(imagePath);
    } 
    
    // 2. Fallback for Base64 strings
    try {
      return MemoryImage(base64Decode(imagePath));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- 1. SAFE DATA EXTRACTION ---
    final String fullName = alumniData['fullName'] ?? 'Unknown Alumnus';
    final String job = alumniData['jobTitle'] ?? '';
    final String org = alumniData['organization'] ?? '';
    final String bio = alumniData['bio'] ?? 'No biography provided.';
    final String phone = alumniData['phoneNumber'] ?? '';
    final String linkedin = alumniData['linkedin'] ?? '';
    final String email = alumniData['email'] ?? '';
    final String year = alumniData['yearOfAttendance']?.toString() ?? 'Unknown';
    final String imageString = alumniData['profilePicture'] ?? '';
    
    // ✅ Logic: Show "Not Specified" if missing
    final String programme = (alumniData['programmeTitle'] != null && alumniData['programmeTitle'].toString().isNotEmpty) 
        ? alumniData['programmeTitle'] 
        : 'Not Specified';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Alumni Profile", style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1B5E3A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 2. HEADER SECTION (Gradient + Avatar) ---
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Background Gradient
                Container(
                  width: double.infinity,
                  height: 140,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1B5E3A), Color(0xFF2E8B57)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // Avatar
                Positioned(
                  bottom: -60,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: getProfileImage(imageString),
                      child: getProfileImage(imageString) == null
                          ? const Icon(Icons.person, size: 60, color: Colors.grey)
                          : null,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 70), // Spacer for Avatar

            // --- 3. NAME & JOB INFO ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    fullName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  if (job.isNotEmpty || org.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.work_outline, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            "$job at $org",
                            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[700]),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  
                  const SizedBox(height: 5),
                  
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.15), // Gold tint
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Class of $year",
                      style: GoogleFonts.inter(
                        color: const Color(0xFFB8860B), // Dark Gold
                        fontWeight: FontWeight.bold,
                        fontSize: 13
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // --- 4. ACTION BUTTONS (Clean Row) ---
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

            const SizedBox(height: 30),
            const Divider(thickness: 1, indent: 20, endIndent: 20, color: Colors.black12),
            const SizedBox(height: 20),

            // --- 5. DETAILS SECTION ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("About Me"),
                  const SizedBox(height: 8),
                  Text(
                    bio,
                    style: GoogleFonts.inter(fontSize: 15, height: 1.6, color: Colors.grey[800]),
                  ),
                  
                  const SizedBox(height: 30),

                  _buildSectionTitle("Academic Record"),
                  const SizedBox(height: 10),
                  
                  // ✅ IMPROVED PROGRAMME CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF1B5E3A).withOpacity(0.2)),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF1B5E3A).withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E3A).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.school, color: Color(0xFF1B5E3A)),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Programme Attended",
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                programme,
                                style: GoogleFonts.inter(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold, 
                                  // Grey text if "Not Specified", black otherwise
                                  color: programme == 'Not Specified' ? Colors.grey : Colors.black87
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF1B5E3A),
      ),
    );
  }

  Widget _buildCircleAction(IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}