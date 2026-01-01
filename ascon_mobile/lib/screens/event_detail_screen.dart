import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EventDetailScreen extends StatelessWidget {
  final Map<String, String> eventData;

  const EventDetailScreen({super.key, required this.eventData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // --- HEADER IMAGE ---
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: const Color(0xFF1B5E3A),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                eventData['image']!,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
              ),
            ),
            leading: IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.arrow_back, color: Color(0xFF1B5E3A)),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // --- CONTENT ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B5E3A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      eventData['date']!,
                      style: GoogleFonts.inter(
                        fontSize: 14, 
                        fontWeight: FontWeight.bold, 
                        color: const Color(0xFF1B5E3A)
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    eventData['title']!,
                    style: GoogleFonts.inter(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.black87
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Location Row
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.grey, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          eventData['location']!,
                          style: GoogleFonts.inter(fontSize: 15, color: Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // Description Title
                  Text(
                    "About this Event",
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),

                  // Description Body
                  Text(
                    "Join us for this special event organized by ASCON. This is a great opportunity to network, learn, and connect with fellow alumni. More details will be shared closer to the date.",
                    style: GoogleFonts.inter(fontSize: 16, height: 1.5, color: Colors.grey[800]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      
      // --- BOTTOM ACTION BUTTON ---
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ElevatedButton(
            onPressed: () {
              // Placeholder for future "Register" logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Registration feature coming soon!")),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1B5E3A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Register for Event", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}