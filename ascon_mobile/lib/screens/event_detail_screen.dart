import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // ✅ Required for Date Formatting

class EventDetailScreen extends StatelessWidget {
  final Map<String, String> eventData;

  const EventDetailScreen({super.key, required this.eventData});

  @override
  Widget build(BuildContext context) {
    // Extract data safely
    final String image = eventData['image'] ?? 'https://via.placeholder.com/600';
    final String title = eventData['title'] ?? 'Event Details';
    final String location = eventData['location'] ?? 'ASCON Complex';
    final String description = eventData['description'] != null && eventData['description']!.isNotEmpty
        ? eventData['description']!
        : "No detailed description available for this event.";

    // --- ✅ DATE FORMATTING LOGIC ---
    String formattedDate = eventData['date'] ?? 'TBA';
    // Use 'rawDate' if available, otherwise try 'date'
    String rawDateString = eventData['rawDate'] ?? eventData['date'] ?? '';

    if (rawDateString.isNotEmpty) {
      try {
        DateTime dt = DateTime.parse(rawDateString);
        // Format: "Fri, 12 Jan, 2026 at 4:30 PM" (Shortened Day/Month to fit side-by-side)
        formattedDate = DateFormat("EEE, d MMM y\n'at' h:mm a").format(dt); 
      } catch (e) {
        // Keep original if parsing fails
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // --- 1. COMPACT APP BAR ---
          SliverAppBar(
            expandedHeight: 220.0,
            pinned: true,
            backgroundColor: const Color(0xFF1B5E3A),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Colors.white24, 
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
                    color: Colors.white24,
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
                    errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.3),
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
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -4))
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
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Category Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E3A).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF1B5E3A).withOpacity(0.2)),
                      ),
                      child: Text(
                        "OFFICIAL EVENT",
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1B5E3A),
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
                        color: Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- INFO GRID ROW (SIDE-BY-SIDE) ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start, // Align top if heights differ
                      children: [
                        Expanded(
                          child: _buildInfoItem(Icons.calendar_today, "Date", formattedDate),
                        ),
                        const SizedBox(width: 12), 
                        Expanded(
                          child: _buildInfoItem(Icons.location_on_outlined, "Location", location),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24), 
                    const Divider(color: Colors.black12, thickness: 1),
                    const SizedBox(height: 16),

                    // --- DESCRIPTION SECTION ---
                    Text(
                      "About Event",
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1B5E3A)
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.grey[800],
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
          color: Colors.white,
          boxShadow: [
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
                  color: const Color(0xFF1B5E3A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.calendar_month, color: Color(0xFF1B5E3A), size: 20),
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
                        const SnackBar(
                          content: Text("Registration Portal Opening Soon!"),
                          backgroundColor: Color(0xFF1B5E3A),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E3A),
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
  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Container(
      // Ensure the container fills vertical space nicely
      constraints: const BoxConstraints(minHeight: 80),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.grey[600]), 
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[500]),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // ✅ UPDATE: Allow multiple lines so the long date fits
          Text(
            value,
            maxLines: 3, // Allowed to wrap to 3 lines
            overflow: TextOverflow.ellipsis, 
            style: GoogleFonts.inter(
              fontSize: 13, 
              fontWeight: FontWeight.bold, 
              color: Colors.black87,
              height: 1.2, // Tighter line height for wrapping
            ),
          ),
        ],
      ),
    );
  }
}