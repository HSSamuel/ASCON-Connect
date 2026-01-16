import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

class JobDetailScreen extends StatelessWidget {
  final Map<String, dynamic> job;
  const JobDetailScreen({super.key, required this.job});

  // ✅ INTELLIGENT APPLICATION HANDLER
  Future<void> _handleApplication(BuildContext context) async {
    String link = job['applicationLink'] ?? "";
    
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No application link provided")),
      );
      return;
    }

    // 1. Check if it's an email address (Contains @ and no http)
    final bool isEmail = link.contains('@') && !link.startsWith('http');

    if (isEmail) {
      await _launchEmailApp(context, link);
    } else {
      await _launchBrowser(context, link);
    }
  }

  // 📧 EMAIL LAUNCHER (Like Facility Inquiry)
  Future<void> _launchEmailApp(BuildContext context, String email) async {
    final String jobTitle = job['title'] ?? "Job Opportunity";
    final String company = job['company'] ?? "ASCON";

    final String subject = "Application for $jobTitle - $company";
    final String body = 
        "Dear Hiring Manager,\n\n"
        "I am writing to express my interest in the $jobTitle position at $company.\n\n"
        "Please find my application details attached.\n\n"
        "Sincerely,\n"
        "[Your Name]\n"
        "[Your Phone Number]";

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );

    try {
      if (!await launchUrl(emailLaunchUri)) {
        throw 'Could not launch email';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open email app. Please copy the email manually.")),
        );
      }
    }
  }

  // 🌐 BROWSER LAUNCHER (Google Forms / Websites)
  Future<void> _launchBrowser(BuildContext context, String urlString) async {
    if (!urlString.startsWith('http')) {
      urlString = 'https://$urlString';
    }

    final Uri url = Uri.parse(urlString);

    try {
      // Try launching inside the app first (WebView)
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication, // Changed to external for better Google Form support
      );

      if (!launched) {
        throw 'Could not launch URL';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch application form.")),
        );
      }
    }
  }

  // Share functionality
  void _shareJob() {
    final String title = job['title'] ?? "Job Opportunity";
    final String company = job['company'] ?? "ASCON Network";
    final String link = job['applicationLink'] ?? "";
    Share.share("Check out this job: $title at $company.\nApply here: $link");
  }

  @override
  Widget build(BuildContext context) {
    // Theme Awareness
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardBg = isDark ? Colors.grey[850] : Colors.grey[100];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Job Details"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareJob,
            tooltip: "Share Job",
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER SECTION ---
                  Row(
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        child: Icon(Icons.business_center, color: primaryColor, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              job['title'] ?? "Untitled Role",
                              style: GoogleFonts.inter(
                                fontSize: 22, 
                                fontWeight: FontWeight.w800,
                                color: textColor,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              job['company'] ?? "Unknown Company",
                              style: GoogleFonts.inter(
                                fontSize: 16, 
                                color: subTextColor, 
                                fontWeight: FontWeight.w500
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // --- TAGS ROW ---
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildTag(job['type'] ?? 'Full-time', Colors.blue, isDark),
                      if (job['location'] != null)
                        _buildTag(job['location'], Colors.orange, isDark),
                      if (job['salary'] != null && job['salary'] != "Negotiable")
                        _buildTag(job['salary'], Colors.green, isDark),
                    ],
                  ),
                  
                  const SizedBox(height: 30),
                  Divider(color: Colors.grey.withOpacity(0.2)),
                  const SizedBox(height: 24),

                  // --- DESCRIPTION ---
                  Text(
                    "Job Description",
                    style: GoogleFonts.inter(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      color: textColor
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Text(
                    job['description'] ?? "No description available.",
                    style: GoogleFonts.inter(
                      fontSize: 16, 
                      height: 1.6,
                      color: isDark ? Colors.grey[300] : Colors.grey[800]
                    ),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // --- APPLY BUTTON ---
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                )
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: primaryColor.withOpacity(0.4),
                ),
                // ✅ UPDATE: Uses new intelligent handler
                onPressed: () => _handleApplication(context),
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text(
                  "Apply Now",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.1), 
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text, 
        style: TextStyle(
          color: color, 
          fontWeight: FontWeight.bold,
          fontSize: 13
        )
      ),
    );
  }
}