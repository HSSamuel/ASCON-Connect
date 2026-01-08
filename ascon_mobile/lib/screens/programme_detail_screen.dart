import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ Added for font consistency
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // ✅ Added for rich formatting
// ✅ Import the registration screen
import 'programme_registration_screen.dart';

class ProgrammeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> programme;

  const ProgrammeDetailScreen({super.key, required this.programme});

  @override
  State<ProgrammeDetailScreen> createState() => _ProgrammeDetailScreenState();
}

class _ProgrammeDetailScreenState extends State<ProgrammeDetailScreen> {
  String? _localUserId;

  @override
  void initState() {
    super.initState();
    _getUserId();
  }

  Future<void> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
       _localUserId = prefs.getString('mongo_id');
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // ✅ Extract ALL Backend Data
    final title = widget.programme['title'] ?? 'Programme Details';
    final code = widget.programme['code'] ?? '';
    final description = widget.programme['description'] ?? 'No description available.';
    final duration = widget.programme['duration'];
    final fee = widget.programme['fee'];
    final programmeId = widget.programme['_id'];
    
    // ✅ Handle Image (Check both keys just in case)
    final String? programmeImage = widget.programme['image'] ?? widget.programme['imageUrl'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Programme Details"), 
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            // ✅ UPDATED HEADER: Shows Image if available, else shows Icon
            _buildHeader(programmeImage, title, code, primaryColor),
            
            const SizedBox(height: 25),

            // Info Grid (Duration & Fee)
            if (duration != null || fee != null)
              Row(
                children: [
                  if (duration != null && duration.toString().isNotEmpty) 
                    Expanded(child: _buildInfoTile(Icons.timer_outlined, "Duration", duration)),
                  
                  if (duration != null && fee != null) 
                    const SizedBox(width: 15),
                  
                  if (fee != null && fee.toString().isNotEmpty) 
                    Expanded(child: _buildInfoTile(Icons.monetization_on_outlined, "Fee", fee)),
                ],
              ),
            
            const SizedBox(height: 25),

            Text(
              "About this Programme", 
              style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)
            ),
            const SizedBox(height: 12),
            
            // ✅ ENHANCED: Markdown renderer for professional alignment and formatting
            MarkdownBody(
              data: description,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: GoogleFonts.inter(fontSize: 15, height: 1.6, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                strong: const TextStyle(fontWeight: FontWeight.bold),
                listBullet: TextStyle(color: primaryColor),
                blockSpacing: 10.0,
              ),
            ),
            
            const SizedBox(height: 40),
            
            // ACTION BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProgrammeRegistrationScreen(
                        programmeId: programmeId,
                        programmeTitle: title,
                        userId: _localUserId,
                        programmeImage: programmeImage, // Pass image to next screen too
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Register Interest", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

 // ✅ Header with Larger, Bolder Title
  Widget _buildHeader(String? image, String title, String code, Color primaryColor) {
    // 1. IF IMAGE EXISTS
    if (image != null && image.isNotEmpty) {
      return Container(
        height: 220, 
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[200],
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
          ]
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
              ),
            ),
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
            // ✅ CENTERED TEXT CONTENT
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // TITLE: Significantly Increased Size
                    Text(
                      title, 
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 28.0, 
                        fontWeight: FontWeight.w900, 
                        color: Colors.white,
                        height: 1.2
                      )
                    ),
                    const SizedBox(height: 10),
                    // Code Pill
                    if (code.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2), 
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.5))
                        ),
                        child: Text(
                          code.toUpperCase(), 
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } 
    
    // 2. IF NO IMAGE (Fallback)
    else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.school_rounded, size: 50, color: primaryColor),
            const SizedBox(height: 15),
            Text(
              title, 
              textAlign: TextAlign.center, 
              style: GoogleFonts.inter(
                fontSize: 26.0, 
                fontWeight: FontWeight.w900, 
                color: primaryColor
              )
            ),
            if (code.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white, 
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withOpacity(0.3))
                ),
                child: Text(code, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: primaryColor)),
              ),
            ]
          ],
        ),
      );
    }
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.grey[600]), 
              const SizedBox(width: 6), 
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]))
            ]
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}