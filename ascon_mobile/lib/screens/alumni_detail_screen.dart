import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart'; // ✅ To open LinkedIn/Phone

class AlumniDetailScreen extends StatelessWidget {
  final Map<String, dynamic> alumniData;

  const AlumniDetailScreen({super.key, required this.alumniData});

  // Helper to open links safely
  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract safely
    final String fullName = alumniData['fullName'] ?? 'Unknown Alumnus';
    final String job = alumniData['jobTitle'] ?? '';
    final String org = alumniData['organization'] ?? '';
    final String bio = alumniData['bio'] ?? 'No biography provided.';
    final String phone = alumniData['phoneNumber'] ?? '';
    final String linkedin = alumniData['linkedin'] ?? '';
    final String email = alumniData['email'] ?? '';
    final String year = alumniData['yearOfAttendance']?.toString() ?? 'Unknown';
    final String imageString = alumniData['profilePicture'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Alumni Profile"),
        backgroundColor: const Color(0xFF1B5E3A),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 1. GREEN HEADER BACKGROUND
            Container(
              width: double.infinity,
              height: 120,
              color: const Color(0xFF1B5E3A),
            ),

            // 2. OVERLAPPING AVATAR
            Transform.translate(
              offset: const Offset(0, -50),
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white,
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: imageString.isNotEmpty
                      ? MemoryImage(base64Decode(imageString))
                      : null,
                  child: imageString.isEmpty
                      ? const Icon(Icons.person, size: 60, color: Colors.grey)
                      : null,
                ),
              ),
            ),

            // 3. MAIN DETAILS
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      fullName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (job.isNotEmpty || org.isNotEmpty)
                      Text(
                        "$job at $org",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    const SizedBox(height: 5),
                    Text(
                      "Class of $year",
                      style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // 4. ACTION BUTTONS (LinkedIn / Email)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (linkedin.isNotEmpty)
                    _buildSocialButton(Icons.link, "LinkedIn", () => _launchURL(linkedin)),
                  if (linkedin.isNotEmpty) const SizedBox(width: 15),
                  
                  _buildSocialButton(Icons.email, "Email", () => _launchURL("mailto:$email")),
                  
                  if (phone.isNotEmpty) const SizedBox(width: 15),
                  if (phone.isNotEmpty)
                    _buildSocialButton(Icons.phone, "Call", () => _launchURL("tel:$phone")),
                ],
              ),
            ),
            
            const Divider(height: 40),

            // 5. BIO SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "About Me",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1B5E3A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    bio,
                    style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[800]),
                  ),
                  const SizedBox(height: 30),
                  
                  // PROGRAMME INFO
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!)
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Programme Attended", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 5),
                        Text(
                          alumniData['programmeTitle'] ?? 'N/A',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1B5E3A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}