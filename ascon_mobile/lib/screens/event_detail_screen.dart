import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart'; // ✅ REQUIRED for sharing
import 'package:add_2_calendar/add_2_calendar.dart'; // ✅ REQUIRED for Calendar
import 'package:flutter/foundation.dart'; // ✅ REQUIRED to check for Web (kIsWeb)
import 'event_registration_screen.dart'; // ✅ REQUIRED for registration navigation

class EventDetailScreen extends StatelessWidget {
  // ✅ Changed to dynamic to handle database fields safely (e.g., IDs, numbers)
  final Map<String, dynamic> eventData;

  const EventDetailScreen({super.key, required this.eventData});

  @override
  Widget build(BuildContext context) {
    // --- THEME VARIABLES ---
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final dividerColor = Theme.of(context).dividerColor;

    // --- 1. DATA EXTRACTION ---
    final String image = eventData['image'] ?? 'https://via.placeholder.com/600';
    final String title = eventData['title'] ?? 'Event Details';
    final String location = eventData['location'] ?? 'Online / ASCON Complex';
    final String description = eventData['description'] != null && eventData['description']!.isNotEmpty
        ? eventData['description']!
        : "No detailed description available for this event.";

    // ✅ Detect Event Type & Registration Availability
    // If the type is missing, default to 'News' (which hides the button)
    final String eventType = eventData['type'] ?? 'News';
    final bool isRegistrable = eventType != 'News';
    
    // Handle ID (supports both '_id' from MongoDB and 'id' from normal maps)
    final String eventId = eventData['_id'] ?? eventData['id'] ?? '';

    // --- DATE PARSING LOGIC ---
    String formattedDate = eventData['date'] ?? 'Date to be announced';
    String rawDateString = eventData['rawDate'] ?? eventData['date'] ?? '';

    // ✅ Store the actual DateTime object for the Calendar function
    DateTime? eventDateObject;

    if (rawDateString.isNotEmpty) {
      try {
        eventDateObject = DateTime.parse(rawDateString); // ✅ Capture date object
        formattedDate = DateFormat("EEEE, d MMM y").format(eventDateObject!); 
      } catch (e) {
        // Keep original string if parsing fails
      }
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // --- 2. HERO HEADER (Image + Back + Share) ---
          SliverAppBar(
            expandedHeight: 280.0,
            pinned: true,
            backgroundColor: primaryColor,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3), 
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // ✅ FUNCTIONAL SHARE BUTTON
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                ),
                onPressed: () {
                  // Construct a professional share message
                  final String shareText = 
                    "🔔 *ASCON UPDATE: $title*\n\n"
                    "📅 Date: $formattedDate\n"
                    "📍 Location: $location\n\n"
                    "${description.length > 100 ? description.substring(0, 100) + '...' : description}\n\n"
                    "Download the ASCON Mobile App for details!";
                  
                  // Launch native share sheet
                  Share.share(shareText, subject: title);
                },
              ),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    image,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(color: Colors.grey[800]),
                  ),
                  // Dark Gradient for text contrast
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                        stops: const [0.6, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- 3. CONTENT BODY ---
          SliverToBoxAdapter(
            child: Container(
              transform: Matrix4.translationValues(0, -20, 0), // Pull up overlap effect
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Decorative Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: dividerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ✅ DYNAMIC EVENT TYPE BADGE
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      eventType.toUpperCase(), // e.g., "WEBINAR", "NEWS"
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // TITLE
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // INFO ROWS
                  _buildInfoRow(context, Icons.calendar_today_outlined, "Date", formattedDate),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(color: dividerColor.withOpacity(0.5), height: 1),
                  ),
                  _buildInfoRow(context, Icons.location_on_outlined, "Location", location),
                  
                  const SizedBox(height: 30),

                  // DESCRIPTION
                  Text(
                    "About Event",
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.6,
                      color: subTextColor,
                    ),
                    textAlign: TextAlign.justify, 
                  ),
                  
                  const SizedBox(height: 100), // Spacing for bottom bar
                ],
              ),
            ),
          ),
        ],
      ),

      // --- 4. FLOATING BOTTOM BAR (Only if NOT 'News') ---
      bottomNavigationBar: isRegistrable 
        ? Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                )
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // ✅ FUNCTIONAL CALENDAR BUTTON (Protected for Web)
                  Container(
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.calendar_month_outlined, color: primaryColor),
                      onPressed: () {
                        // ❌ Prevent Crash on Web
                        if (kIsWeb) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Calendar feature is available on Mobile App only.")),
                          );
                          return;
                        }

                        if (eventDateObject != null) {
                          // Define the Event
                          final Event calendarEvent = Event(
                            title: title,
                            description: description,
                            location: location,
                            startDate: eventDateObject!,
                            endDate: eventDateObject!.add(const Duration(hours: 2)), // Default 2 hours
                            iosParams: const IOSParams(reminder: Duration(minutes: 60)),
                            androidParams: const AndroidParams(emailInvites: []),
                          );
                          
                          // Add to System Calendar
                          Add2Calendar.addEvent2Cal(calendarEvent);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Date not set for this event.")),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // ✅ REGISTER BUTTON -> Navigates to Registration Screen
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
                                // Pass userId here if available in your state management
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
                        child: Text(
                          "Register Now",
                          style: GoogleFonts.inter(
                            fontSize: 16, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : null, // ✅ Hides bottom bar if event type is 'News'
    );
  }

  // --- HELPER: Info Row Widget ---
  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: subTextColor?.withOpacity(0.7),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}