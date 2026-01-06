import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; 
import '../services/data_service.dart'; 
import 'event_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final DataService _dataService = DataService(); 
  
  List<dynamic> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await _dataService.fetchEvents();
    
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ Dynamic Theme Colors
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "News & Events", 
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: scaffoldBg,
      
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        color: primaryColor,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : _events.isEmpty
                ? _buildEmptyState()
                : ListView.separated( 
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      return _buildEventCard(_events[index]);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final color = Theme.of(context).textTheme.bodyMedium?.color;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 60, color: color?.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            "No news or events yet.",
            style: GoogleFonts.inter(fontSize: 16, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(dynamic event) {
    // ✅ Dynamic Colors for Card
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final primaryColor = Theme.of(context).primaryColor;

    // --- 1. SMART DATE PARSING ---
    String month = "TBD";
    String day = "--";
    String fullDateString = "Date to be announced";
    
    try {
      if (event['date'] != null) {
        final date = DateTime.parse(event['date']);
        month = DateFormat('MMM').format(date).toUpperCase(); // e.g. DEC
        day = DateFormat('dd').format(date); // e.g. 25
        fullDateString = DateFormat('MMMM d, yyyy').format(date);
      }
    } catch (e) {
      // If parsing fails, stick to defaults
    }

    final String title = event['title']?.toString() ?? 'No Title';
    final String location = event['location']?.toString() ?? 'ASCON HQ';
    final String imageUrl = event['image']?.toString() ?? 'https://via.placeholder.com/600x300';
    final String type = event['type'] ?? 'News';
    final String description = event['description']?.toString() ?? 'No details available.';

    // Safe Data Payload for Detail Screen
    final Map<String, String> safeEventData = {
      'title': title,
      'date': fullDateString, 
      'rawDate': event['date']?.toString() ?? '', 
      'location': location,
      'image': imageUrl,
      'description': description,
    };

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => EventDetailScreen(eventData: safeEventData)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
          ],
        ),
        clipBehavior: Clip.antiAlias, // Ensures image doesn't bleed out
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 2. HERO IMAGE TOP SECTION ---
            Stack(
              children: [
                Container(
                  height: 150,
                  width: double.infinity,
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Icon(Icons.image_not_supported, color: Colors.grey[400], size: 50),
                  ),
                ),
                // Gradient Overlay for readability
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.6),
                        ],
                      ),
                    ),
                  ),
                ),
                // Type Badge (News/Event)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Text(
                      type.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 10, 
                        fontWeight: FontWeight.bold, 
                        color: Colors.white,
                        letterSpacing: 0.5
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // --- 3. CARD CONTENT ---
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // CALENDAR LEAF (Date Badge)
                  _buildDateBadge(context, month, day),
                  
                  const SizedBox(width: 16),
                  
                  // INFO COLUMN
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            height: 1.3
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: subTextColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: GoogleFonts.inter(fontSize: 12, color: subTextColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 12),
                        
                        // "View Details" Link
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "View Details →",
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                          ),
                        )
                      ],
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

  // --- HELPER: The "Calendar Leaf" Badge ---
  Widget _buildDateBadge(BuildContext context, String month, String day) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: 55,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: primaryColor.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            month, 
            style: GoogleFonts.inter(
              fontSize: 12, 
              fontWeight: FontWeight.bold, 
              color: primaryColor
            ),
          ),
          const SizedBox(height: 2),
          Text(
            day, 
            style: GoogleFonts.inter(
              fontSize: 18, 
              fontWeight: FontWeight.w900, 
              color: Theme.of(context).textTheme.bodyLarge?.color
            ),
          ),
        ],
      ),
    );
  }
}