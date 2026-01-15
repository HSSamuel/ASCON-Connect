import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/full_screen_image.dart';

class FacilityDetailScreen extends StatelessWidget {
  final Map<String, dynamic> facility;

  const FacilityDetailScreen({super.key, required this.facility});

  Future<void> _requestBooking(BuildContext context) async {
    final String subject = "Booking Request: ${facility['name']}";
    final String body = "Hello ASCON Team,\n\nI am interested in booking the ${facility['name']}.\n\n--- Request Details ---\n📅 Proposed Date:\n👥 Expected Guests:\n📞 Contact Phone:\n\nPlease send me availability and payment details.";
    
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'info@ascon.gov.ng', 
      query: 'subject=$subject&body=$body',
    );

    try {
      await launchUrl(emailLaunchUri);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open email app")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    
    final String? imageUrl = facility['image'];
    final bool isActive = facility['isActive'] == true;
    final List<dynamic> rates = facility['rates'] ?? [];
    final String description = facility['description'] ?? "No detailed description available for this facility.";
    
    // Simulated Amenities (Kept as visual filler for "Pro" look)
    final List<String> amenities = ["Air Conditioning", "Security", "Parking", "Sound System"];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // -------------------------------------------
          // 1. IMMERSIVE HERO APP BAR
          // -------------------------------------------
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            backgroundColor: primaryColor,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26, 
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white30)
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: GestureDetector(
                onTap: () {
                  if (imageUrl != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FullScreenImage(
                          imageUrl: imageUrl, 
                          heroTag: 'facility_img_${facility['_id']}'
                        ),
                      ),
                    );
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'facility_img_${facility['_id']}',
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl, 
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(color: Colors.grey[800]),
                            )
                          : Container(color: Colors.grey[800]),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                          stops: [0.6, 1.0],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white30),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.fullscreen, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text("View Photo", style: TextStyle(color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // -------------------------------------------
          // 2. MAIN CONTENT BODY
          // -------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE & BADGE
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          facility['name'] ?? "Facility Name",
                          style: GoogleFonts.inter(
                            fontSize: 26, 
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: isDark ? Colors.white : const Color(0xFF1B5E3A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildStatusChip(isActive),
                    ],
                  ),
                  
                  const SizedBox(height: 20),

                  // ✅ REMOVED: Stats Row (Capacity, Size, Rating)
                  
                  // DESCRIPTION (Header removed, text increased for focus)
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 16, // Slightly larger for readability since it's prominent now
                      height: 1.6,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // AMENITIES
                  Text("Key Amenities", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: amenities.map((amenity) => Chip(
                      avatar: const Icon(Icons.check_circle, size: 16, color: Color(0xFF1B5E3A)),
                      label: Text(amenity),
                      backgroundColor: isDark ? Colors.grey[800] : Colors.green[50],
                      labelStyle: TextStyle(color: isDark ? Colors.white : Colors.green[900], fontSize: 13),
                      side: BorderSide.none,
                    )).toList(),
                  ),

                  const SizedBox(height: 30),

                  // PRICING CARDS
                  if (rates.isNotEmpty) ...[
                    Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Color(0xFF1B5E3A)),
                        const SizedBox(width: 8),
                        Text("Official Rates", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...rates.map((rate) => _buildRateCard(rate, isDark, primaryColor)),
                  ],
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // -------------------------------------------
      // 3. STICKY BOTTOM ACTION BAR
      // -------------------------------------------
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
          border: Border(top: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!)),
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Interested?", style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                    const Text("Book this Venue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: isActive ? () => _requestBooking(context) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1B5E3A),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text("Request Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGET HELPERS ---

  Widget _buildStatusChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green : Colors.grey,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? "AVAILABLE" : "UNAVAILABLE",
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildRateCard(dynamic rate, bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey[200]!),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                rate['type'] ?? 'Standard Rate',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              const SizedBox(height: 4),
              Text(
                "Per Day",
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[500]),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "₦${rate['naira']}",
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFF1B5E3A)),
              ),
              if (rate['dollar'] != null)
                Text(
                  "\$${rate['dollar']}",
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey[600]),
                ),
            ],
          )
        ],
      ),
    );
  }
}