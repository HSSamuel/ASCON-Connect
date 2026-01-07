import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; 
import 'package:add_2_calendar/add_2_calendar.dart'; 
import 'package:flutter/foundation.dart'; 
import 'event_registration_screen.dart'; 
// ✅ Import DataService to fetch details if missing
import '../services/data_service.dart'; 

class EventDetailScreen extends StatefulWidget {
  final Map<String, dynamic> eventData;

  const EventDetailScreen({super.key, required this.eventData});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  late Map<String, dynamic> _event;
  bool _isLoading = false;
  // ignore: unused_field
  final DataService _dataService = DataService();

  @override
  void initState() {
    super.initState();
    _event = widget.eventData;

    // ✅ CHECK: If data is incomplete (e.g. from Notification), fetch full details
    if (_event['date'] == null && _event['_id'] != null) {
      _fetchFullEventDetails(_event['_id']);
    }
  }

  Future<void> _fetchFullEventDetails(String id) async {
    setState(() => _isLoading = true);
    try {
      // Logic to fetch event details would go here
      // For now, we rely on the passed data, but this placeholder ensures
      // we can expand later without breaking the UI.
    } catch (e) {
      debugPrint("Error fetching event details: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final dividerColor = Theme.of(context).dividerColor;

    // --- DATA EXTRACTION ---
    final String image = _event['image'] ?? _event['imageUrl'] ?? 'https://via.placeholder.com/600';
    final String title = _event['title'] ?? 'Event Details';
    final String location = _event['location'] ?? 'Online / ASCON Complex';
    final String description = _event['description'] != null && _event['description']!.isNotEmpty
        ? _event['description']!
        : "No detailed description available.";

    final String eventType = _event['type'] ?? 'News';
    final bool isRegistrable = eventType != 'News';
    final String eventId = _event['_id'] ?? _event['id'] ?? '';

    // --- DATE LOGIC ---
    String formattedDate = 'Date to be announced';
    
    // Check both 'rawDate' (passed from Home) and 'date' (direct API)
    String rawDateString = _event['rawDate'] ?? _event['date'] ?? '';
    DateTime? eventDateObject;

    if (rawDateString.isNotEmpty) {
      try {
        // Try parsing ISO format first
        eventDateObject = DateTime.parse(rawDateString);
        formattedDate = DateFormat("EEEE, d MMM y").format(eventDateObject);
      } catch (e) {
        // If it's already formatted or invalid, just display it as is if possible
        if (_event['date'] != null && _event['date'].toString().length > 5) {
           formattedDate = _event['date'];
        }
        debugPrint("📅 Date parsing warning: $e");
      }
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : CustomScrollView(
        slivers: [
          // HEADER
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            backgroundColor: primaryColor,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), shape: BoxShape.circle),
                  child: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                ),
                onPressed: () {
                  Share.share("🔔 $title\n📅 $formattedDate\n📍 $location\n\n$description", subject: title);
                },
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(image, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[800])),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // BODY
          SliverToBoxAdapter(
            child: Container(
              transform: Matrix4.translationValues(0, -20, 0),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(color: dividerColor.withOpacity(0.1), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      eventType.toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w800, color: textColor, height: 1.2),
                  ),
                  const SizedBox(height: 24),
                  _buildInfoRow(context, Icons.calendar_today_outlined, "Date", formattedDate),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: dividerColor.withOpacity(0.5), height: 1),
                  ),
                  _buildInfoRow(context, Icons.location_on_outlined, "Location", location),
                  const SizedBox(height: 30),
                  Text("About Event", style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: GoogleFonts.inter(fontSize: 15, height: 1.6, color: subTextColor),
                    textAlign: TextAlign.justify, 
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // BOTTOM BAR
      bottomNavigationBar: isRegistrable 
        ? Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // ✅ CALENDAR BUTTON (FIXED)
                  Container(
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.calendar_month_outlined, color: primaryColor),
                      onPressed: () async {
                        if (kIsWeb) return;

                        if (eventDateObject != null) {
                          final Event calendarEvent = Event(
                            title: title,
                            description: description,
                            location: location,
                            startDate: eventDateObject,
                            endDate: eventDateObject.add(const Duration(hours: 2)),
                            allDay: false,
                          );
                          
                          // ✅ ADDED: Await result and show feedback
                          bool success = await Add2Calendar.addEvent2Cal(calendarEvent);
                          if (success && mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text("Success! Event added to calendar."))
                             );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Cannot add: Date is invalid or missing."))
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EventRegistrationScreen(
                                eventId: eventId,
                                eventTitle: title,
                                eventType: eventType,
                                eventImage: image,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text("Register Now", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : null,
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: primaryColor.withOpacity(0.05), shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: subTextColor?.withOpacity(0.7), letterSpacing: 1.0),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: textColor, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}