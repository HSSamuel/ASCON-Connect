import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; 
import '../config.dart';
import 'event_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<dynamic> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  Future<void> fetchEvents() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/events');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        setState(() {
          if (data is Map && data.containsKey('events')) {
            _events = data['events'];
          } else if (data is List) {
            _events = data;
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading events: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "News & Events", 
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18)
        ),
        backgroundColor: const Color(0xFF1B5E3A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.grey[50],
      
      body: RefreshIndicator(
        onRefresh: fetchEvents,
        color: const Color(0xFF1B5E3A),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E3A)))
            : _events.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12), // Reduced padding
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      return _buildEventCard(_events[index]);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            "No news or events yet.",
            style: GoogleFonts.inter(fontSize: 15, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(dynamic event) {
    String dateString = "TBD";
    try {
      if (event['date'] != null) {
        final date = DateTime.parse(event['date']);
        dateString = DateFormat('MMM dd, yyyy').format(date);
      }
    } catch (e) {
      dateString = event['date'] ?? "Unknown";
    }

    final Map<String, String> safeEventData = {
      'title': event['title']?.toString() ?? 'No Title',
      'date': dateString, // Keeps the short date for the card
      // ✅ ADD THIS LINE: Pass the full raw date so Detail Screen can show time
      'rawDate': event['date']?.toString() ?? '', 
      'location': event['location']?.toString() ?? 'ASCON HQ',
      'image': event['image']?.toString() ?? 'https://via.placeholder.com/600',
      'description': event['description']?.toString() ?? 'No description available.',
    };

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (context) => EventDetailScreen(eventData: safeEventData)),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 1, // Reduced elevation
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thinner Green Strip
            Container(
              height: 4,
              decoration: const BoxDecoration(
                color: Color(0xFF1B5E3A),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(12.0), // Compact Padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green[50], 
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event['type'] ?? 'News', 
                          style: GoogleFonts.inter(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: const Color(0xFF1B5E3A)
                          ),
                        ),
                      ),
                      Text(
                        dateString,
                        style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),

                  Text(
                    event['title'] ?? 'No Title',
                    style: GoogleFonts.inter(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold, 
                      color: Colors.black87,
                      height: 1.3
                    ),
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        event['location'] ?? 'Publication Dept',
                        style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    event['description'] ?? '',
                    maxLines: 3, 
                    overflow: TextOverflow.ellipsis, 
                    textAlign: TextAlign.justify, 
                    style: GoogleFonts.inter(
                      fontSize: 13, 
                      color: Colors.grey[800], 
                      height: 1.5
                    ),
                  ),
                  
                  const SizedBox(height: 10),

                  Text(
                    "Read More",
                    style: GoogleFonts.inter(
                      fontSize: 12, 
                      fontWeight: FontWeight.w600, 
                      color: const Color(0xFF1B5E3A),
                      decoration: TextDecoration.underline
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
}