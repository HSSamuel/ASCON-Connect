import 'dart:convert'; // ✅ Import this for Base64 decoding
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

  // ✅ UPDATED: Added colors for new professional event types
  Color _getTypeColor(String type) {
    switch (type) {
      case 'Reunion':    return const Color(0xFF1B5E3A); // Dark Green
      case 'Webinar':    return Colors.blue[700]!;     
      case 'Seminar':    return Colors.purple[700]!;   
      case 'News':       return Colors.orange[800]!;   
      
      // New Types
      case 'Conference': return const Color(0xFF0D47A1); // Deep Blue
      case 'Workshop':   return const Color(0xFF00695C); // Teal
      case 'Symposium':  return const Color(0xFFAD1457); // Pink/Magenta
      case 'AGM':        return const Color(0xFFFF8F00); // Amber/Gold
      case 'Induction':  return const Color(0xFF2E7D32); // Success Green
      case 'Event':      return Colors.indigo[900]!;     // General Event
      
      default:           return Colors.grey[700]!;
    }
  }

  // ✅ NEW HELPER: Handles both HTTP URLs and Base64 Strings
  Widget _buildSafeImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Icon(Icons.event, color: Colors.grey[400], size: 30);
    }

    // 1. If it's a web URL
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey[400]),
      );
    }

    // 2. If it's Base64 (Database string)
    try {
      // Remove header if present (e.g., "data:image/png;base64,")
      String cleanBase64 = imageUrl;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      return Image.memory(
        base64Decode(cleanBase64),
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey[400]),
      );
    } catch (e) {
      return Icon(Icons.event, color: Colors.grey[400], size: 30);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                : GridView.builder( 
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200, 
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: MediaQuery.of(context).size.width < 600 ? 0.80 : 0.85,
                    ),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      return _buildCompactEventCard(_events[index]);
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

  Widget _buildCompactEventCard(dynamic event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final titleColor = isDark ? Colors.greenAccent[400] : const Color(0xFF1B5E20);

    // --- DATE PARSING ---
    String formattedDate = 'TBA';
    String rawDate = event['date']?.toString() ?? '';
    try {
      if (rawDate.isNotEmpty) {
        final dateObj = DateTime.parse(rawDate);
        formattedDate = DateFormat("d MMM, y").format(dateObj);
      }
    } catch (e) {
      formattedDate = event['date']?.toString() ?? 'TBA';
    }

    final String title = event['title']?.toString() ?? 'No Title';
    final String type = event['type'] ?? 'News';
    final String imageUrl = event['image'] ?? event['imageUrl'] ?? ''; // Pass empty string if null

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.grey.withOpacity(0.1), 
              blurRadius: 6, 
              offset: const Offset(0, 3)
            ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final Map<String, dynamic> safeEventData = {
              ...event,
              '_id': (event['_id'] ?? event['id'] ?? '').toString(),
              'date': formattedDate,
              'rawDate': rawDate,
            };
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => EventDetailScreen(eventData: safeEventData)),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 90, 
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ✅ USE SAFE IMAGE HERE
                      _buildSafeImage(imageUrl),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getTypeColor(type).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                          ),
                          child: Text(
                            type.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 8, 
                              fontWeight: FontWeight.w900, 
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.visible, 
                        style: TextStyle(
                          fontWeight: FontWeight.w800, 
                          fontSize: 12.0,            
                          color: titleColor,            
                          height: 1.1,
                        ),
                      ),
                      
                      const SizedBox(height: 6), 

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.green[900]!.withOpacity(0.3) : const Color(0xFFE8F5E9), 
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          formattedDate.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9, 
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.green[200] : const Color(0xFF1B5E20), 
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}