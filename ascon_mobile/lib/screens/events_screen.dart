import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
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
        title: const Text(
          "News & Events", 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
        ),
        // ✅ Background color is now handled by the Theme (Green in Day, Dark Green in Night)
        automaticallyImplyLeading: false,
      ),
      backgroundColor: scaffoldBg, // ✅ Dynamic
      
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        color: primaryColor,
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: primaryColor))
            : _events.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      return _buildEventCard(_events[index]);
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    // ✅ Dynamic Colors for Empty State
    final color = Theme.of(context).textTheme.bodyMedium?.color;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_note, size: 50, color: color?.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(
            "No news or events yet.",
            style: TextStyle(fontSize: 15, color: color),
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
      'date': dateString, 
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
        color: cardColor, // ✅ Dynamic Background
        margin: const EdgeInsets.only(bottom: 12),
        elevation: isDark ? 0 : 1, // Remove shadow in dark mode for cleaner look
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: isDark ? BorderSide(color: Colors.grey[800]!) : BorderSide.none, // Subtle border in dark mode
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Green Line
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(12.0), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ✅ Dynamic Badge Background
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.green[900]!.withOpacity(0.3) : Colors.green[50], 
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event['type'] ?? 'News', 
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold, 
                            color: isDark ? Colors.green[300] : primaryColor
                          ),
                        ),
                      ),
                      Text(
                        dateString,
                        style: TextStyle(fontSize: 11, color: subTextColor),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),

                  Text(
                    event['title'] ?? 'No Title',
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.bold, 
                      color: textColor, // ✅ Dynamic Text
                      height: 1.3
                    ),
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Icon(Icons.location_on, size: 12, color: subTextColor),
                      const SizedBox(width: 4),
                      Text(
                        event['location'] ?? 'Publication Dept',
                        style: TextStyle(fontSize: 12, color: subTextColor),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Text(
                    event['description'] ?? '',
                    maxLines: 3, 
                    overflow: TextOverflow.ellipsis, 
                    textAlign: TextAlign.justify, 
                    style: TextStyle(
                      fontSize: 13, 
                      color: isDark ? Colors.grey[400] : Colors.grey[800], // ✅ Readable Grey
                      height: 1.5
                    ),
                  ),
                  
                  const SizedBox(height: 10),

                  Text(
                    "Read More",
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.w600, 
                      color: primaryColor,
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