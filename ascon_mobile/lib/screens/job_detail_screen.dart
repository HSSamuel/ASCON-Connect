import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class JobDetailScreen extends StatelessWidget {
  final Map<String, dynamic> job;
  const JobDetailScreen({super.key, required this.job});

  Future<void> _launchApplyLink(BuildContext context, String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No application link provided")),
      );
      return;
    }

    if (!urlString.startsWith('http')) {
      urlString = 'https://$urlString';
    }

    final Uri url = Uri.parse(urlString);

    try {
      final bool launched = await launchUrl(
        url,
        mode: LaunchMode.inAppWebView, // Keeps user inside the app
        webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
      );

      if (!launched) {
        throw 'Could not launch';
      }
    } catch (e) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 1. DETECT DARK MODE
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    
    // ✅ 2. ADAPTIVE TEXT COLORS
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Job Details"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              job['title'] ?? "Untitled Role",
              style: GoogleFonts.inter(
                fontSize: 24, 
                fontWeight: FontWeight.w800,
                color: textColor, // Adaptive Color
              ),
            ),
            const SizedBox(height: 10),
            
            // Company & Location
            Text(
              "${job['company'] ?? 'Unknown Company'} • ${job['location'] ?? 'Remote'}",
              style: GoogleFonts.inter(
                fontSize: 16, 
                color: subTextColor, // Adaptive Grey
                fontWeight: FontWeight.w500
              ),
            ),
            const SizedBox(height: 20),
            
            // ✅ 3. ADAPTIVE TAG (See helper function below)
            _buildTag(job['type'] ?? 'Full-time', Colors.blue, isDark),
            
            const SizedBox(height: 30),
            
            Text(
              "Description",
              style: GoogleFonts.inter(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: textColor
              ),
            ),
            const SizedBox(height: 10),
            
            Text(
              job['description'] ?? "No description available.",
              style: GoogleFonts.inter(
                fontSize: 15, 
                height: 1.6,
                color: isDark ? Colors.grey[300] : Colors.black87 // Softer white for reading
              ),
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 40),
            
            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: isDark ? 0 : 2, // Flatten in dark mode for cleaner look
                ),
                onPressed: () => _launchApplyLink(context, job['applicationLink']),
                child: const Text(
                  "Apply Now",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        // ✅ Dark Mode Tip: Increase opacity so the color is visible against dark grey
        color: color.withOpacity(isDark ? 0.25 : 0.1), 
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: color.withOpacity(0.5), width: 1) : null, // Add border in dark mode for pop
      ),
      child: Text(
        text, 
        style: TextStyle(
          color: isDark ? color.withOpacity(0.9) : color, 
          fontWeight: FontWeight.bold
        )
      ),
    );
  }
}