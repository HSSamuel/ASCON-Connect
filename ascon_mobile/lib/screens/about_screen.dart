import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; // Ensure you have this in pubspec.yaml

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // Helper to open links
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("About ASCON"),
        backgroundColor: const Color(0xFF1B5E3A), // Deep Green
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HERO SECTION ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF1B5E3A),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Image.asset('assets/logo.png', height: 80, width: 80),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Administrative Staff College of Nigeria",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "The Natural Place for Capacity Building",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD4AF37), // Gold
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // --- CONTENT SECTION ---
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("Vision"),
                  const Text(
                    "To be a world-class Management Development Institute (MDI) using advanced technology and best practices for rapid and sustainable national development.",
                    style: TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                  ),
                  
                  const SizedBox(height: 25),
                   _buildSectionTitle("Mission"),
                  const Text(
                    "To consistently deliver excellent management training, consultancy, research, and related services to improve performance across all sectors of the Nigerian economy.",
                    style: TextStyle(fontSize: 15, height: 1.6, color: Colors.black87),
                  ),
                  
                  const SizedBox(height: 25),
                  
                  _buildSectionTitle("Contact Information"),
                  const SizedBox(height: 10),
                  
                  _buildContactRow(Icons.location_on, "Topo, Badagry, Lagos State, Nigeria"),
                  const SizedBox(height: 15),
                  _buildContactRow(Icons.email, "info@ascon.gov.ng"),
                   const SizedBox(height: 15),
                  _buildContactRow(Icons.phone, "09010121012"),
                  const SizedBox(height: 15),
                  _buildContactRow(Icons.language, "www.ascon.gov.ng"),

                  const SizedBox(height: 40),
                  
                  // --- ACTION BUTTONS ---
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => _launchURL("https://ascon.gov.ng"),
                      icon: const Icon(Icons.public),
                      label: const Text("VISIT WEBSITE"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1B5E3A),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  Center(
                    child: Text(
                      "ASCON Connect v1.0.0",
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1B5E3A),
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFD4AF37), size: 20),
        const SizedBox(width: 15),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}