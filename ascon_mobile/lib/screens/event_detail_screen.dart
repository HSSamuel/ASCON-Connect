import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; 

class EventDetailScreen extends StatelessWidget {
  final Map<String, String> eventData;

  const EventDetailScreen({super.key, required this.eventData});

  @override
  Widget build(BuildContext context) {
    // ✅ AUTO-DETECT THEME COLORS
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final dividerColor = Theme.of(context).dividerColor;

    // Extract data safely
    final String image = eventData['image'] ?? 'https://via.placeholder.com/600';
    final String title = eventData['title'] ?? 'Event Details';
    final String location = eventData['location'] ?? 'ASCON Complex';
    final String description = eventData['description'] != null && eventData['description']!.isNotEmpty
        ? eventData['description']!
        : "No detailed description available for this event.";

    String formattedDate = eventData['date'] ?? 'TBA';
    String rawDateString = eventData['rawDate'] ?? eventData['date'] ?? '';

    if (rawDateString.isNotEmpty) {
      try {
        DateTime dt = DateTime.parse(rawDateString);
        formattedDate = DateFormat("EEE, d MMM y\n'at' h:mm a").format(dt); 
      } catch (e) {
        // Keep original if parsing fails
      }
    }

    return Scaffold(
      backgroundColor: scaffoldBg, // ✅ Dynamic Background
      body: CustomScrollView(
        slivers: [
          // --- 1. COMPACT APP BAR ---
          SliverAppBar(
            expandedHeight: 220.0,
            pinned: true,
            backgroundColor: primaryColor, // ✅ Dynamic Primary Color
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.black26, 
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share, color: Colors.white, size: 18),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Share feature coming soon!")),
                  );
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(color: Colors.grey[800]), // Dark placeholder
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- 2. MAIN CONTENT SHEET ---
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -20), 
              child: Container(
                decoration: BoxDecoration(
                  color: cardColor, // ✅ Dynamic Content Background
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    if (!isDark) // Only show shadow in light mode
                      const BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -4))
                  ],
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: dividerColor, // ✅ Dynamic Handle Color
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: primaryColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        "OFFICIAL EVENT",
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Title
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor, // ✅ Dynamic Title Color
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- INFO GRID ROW (SIDE-BY-SIDE) ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start, 
                      children: [
                        Expanded(
                          child: _buildInfoItem(context, Icons.calendar_today, "Date", formattedDate),
                        ),
                        const SizedBox(width: 12), 
                        Expanded(
                          child: _buildInfoItem(context, Icons.location_on_outlined, "Location", location),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24), 
                    Divider(color: dividerColor, thickness: 1), // ✅ Dynamic Divider
                    const SizedBox(height: 16),

                    // --- DESCRIPTION SECTION ---
                    Text(
                      "About Event",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: subTextColor, // ✅ Dynamic Text Color
                      ),
                      textAlign: TextAlign.justify, 
                    ),
                    
                    const SizedBox(height: 30), 
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // --- 3. COMPACT BOTTOM BAR ---
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor, // ✅ Dynamic Bottom Bar
          boxShadow: [
            if (!isDark)
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -3))
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Container(
                width: 45, 
                height: 45,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: Icon(Icons.calendar_month, color: primaryColor, size: 20),
                  padding: EdgeInsets.zero,
                  onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Add to Calendar coming soon!")),
                      );
                  },
                ),
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: SizedBox(
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text("Registration Portal Opening Soon!"),
                          backgroundColor: primaryColor,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      "Register Now",
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGET ---
  Widget _buildInfoItem(BuildContext context, IconData icon, String label, String value) {
    // ✅ Dynamic Colors for Info Box
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxColor = isDark ? Colors.grey[800] : Colors.grey[50];
    final borderColor = Theme.of(context).dividerColor;
    final labelColor = Theme.of(context).textTheme.bodyMedium?.color;
    final valueColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Container(
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: boxColor, // ✅ Dynamic Background
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor), // ✅ Dynamic Border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: labelColor), 
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: labelColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 3, 
            overflow: TextOverflow.ellipsis, 
            style: GoogleFonts.inter(
              fontSize: 13, 
              fontWeight: FontWeight.bold, 
              color: valueColor, // ✅ Dynamic Text
              height: 1.2, 
            ),
          ),
        ],
      ),
    );
  }
}