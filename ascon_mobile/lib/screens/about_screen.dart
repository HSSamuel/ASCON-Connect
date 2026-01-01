import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light background for contrast
      appBar: AppBar(
        title: Text("About ASCON", style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 18)),
        backgroundColor: const Color(0xFF1B5E3A),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- 1. ENHANCED HERO SECTION ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E3A), Color(0xFF2E8B57)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset('assets/logo.png', height: 60, width: 60),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Administrative Staff College of Nigeria",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "The Natural Place for Capacity Building",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFD700), // Gold
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- 2. CENTERED CONTENT CARDS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Vision Card
                  _buildInfoCard(
                    icon: Icons.visibility_outlined,
                    title: "Our Vision",
                    content: "To be a world-class Management Development Institute (MDI) using advanced technology and best practices for rapid and sustainable national development.",
                  ),
                  
                  const SizedBox(height: 16),

                  // Mission Card
                  _buildInfoCard(
                    icon: Icons.track_changes_outlined,
                    title: "Our Mission",
                    content: "To consistently deliver excellent management training, consultancy, research, and related services to improve performance across all sectors of the Nigerian economy.",
                  ),
                  
                  const SizedBox(height: 16),

                  // Contact Card
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
                      children: [
                         Text(
                          "Contact Information",
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1B5E3A),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildContactRow(Icons.location_on_outlined, "Topo, Badagry, Lagos State, Nigeria"),
                        const Divider(height: 24, thickness: 0.5),
                        _buildContactRow(Icons.email_outlined, "info@ascon.gov.ng", onTap: () => _launchURL("mailto:info@ascon.gov.ng")),
                        const Divider(height: 24, thickness: 0.5),
                        _buildContactRow(Icons.phone_outlined, "09010121012", onTap: () => _launchURL("tel:09010121012")),
                        const Divider(height: 24, thickness: 0.5),
                        _buildContactRow(Icons.language, "www.ascon.gov.ng", onTap: () => _launchURL("https://ascon.gov.ng")),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Visit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _launchURL("https://ascon.gov.ng"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E3A),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        "VISIT OFFICIAL WEBSITE",
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  
                  Text(
                    "ASCON Alumni App v1.0.0",
                    style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER: Info Card (Centered Text) ---
  Widget _buildInfoCard({required IconData icon, required String title, required String content}) {
    return Container(
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1B5E3A).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF1B5E3A), size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            textAlign: TextAlign.center, // ✅ Centralized Text
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER: Contact Row (Centered) ---
  Widget _buildContactRow(IconData icon, String text, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // ✅ Align Center
        children: [
          Icon(icon, color: const Color(0xFFD4AF37), size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center, // ✅ Align Text Center
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}