import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/data_service.dart';
import '../widgets/skeleton_loader.dart'; // ✅ Import Skeleton Loader
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
    // Optional: Add artificial delay to test skeleton
    // await Future.delayed(const Duration(seconds: 2));
    
    final events = await _dataService.fetchEvents();
    
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  // ✅ FIXED: Robust Title Casing (Preserves ASCON)
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    
    // 1. Basic Title Case
    String titleCased = text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');

    // 2. 🛡️ FORCE 'ASCON' TO UPPERCASE ALWAYS
    titleCased = titleCased.replaceAllMapped(
      RegExp(r'\bascon\b', caseSensitive: false), 
      (match) => 'ASCON'
    );

    return titleCased;
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Reunion':    return const Color(0xFF1B5E3A); 
      case 'Webinar':    return const Color(0xFF1565C0);     
      case 'Seminar':    return const Color(0xFF6A1B9A);   
      case 'News':       return const Color(0xFFE65100);   
      case 'Conference': return const Color(0xFF0D47A1); 
      case 'Workshop':   return const Color(0xFF00695C); 
      case 'Symposium':  return const Color(0xFFC2185B); 
      case 'AGM':        return const Color(0xFFF57F17); 
      case 'Induction':  return const Color(0xFF2E7D32); 
      case 'Event':      return const Color(0xFF283593);     
      default:           return Colors.grey[800]!;
    }
  }

  Widget _buildSafeImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[900],
        child: const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 40)),
      );
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(
          color: Colors.grey[900],
          child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 40)),
        ),
      );
    }

    try {
      String cleanBase64 = imageUrl;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      return Image.memory(
        base64Decode(cleanBase64),
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(
          color: Colors.grey[900],
          child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 40)),
        ),
      );
    } catch (e) {
      return Container(
        color: Colors.grey[900],
        child: const Center(child: Icon(Icons.error_outline, color: Colors.white24, size: 40)),
      );
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
          style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 18)
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      backgroundColor: scaffoldBg,
      
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        color: primaryColor,
        // ✅ 1. SKELETON LOADING
        child: _isLoading
            ? const EventSkeletonList() 
            : _events.isEmpty
                ? _buildEmptyState()
                : GridView.builder( 
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220, 
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.72, 
                    ),
                    itemCount: _events.length,
                    itemBuilder: (context, index) {
                      return _buildImmersiveEventCard(_events[index]);
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
          Icon(Icons.newspaper_rounded, size: 70, color: color?.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            "No updates yet",
            style: GoogleFonts.lato(fontSize: 18, color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Check back later for news & events.",
            style: GoogleFonts.lato(fontSize: 14, color: color?.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  // ✅ 100% PRO: IMMERSIVE CARD DESIGN
  Widget _buildImmersiveEventCard(dynamic event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Data Parsing
    String formattedDate = 'TBA';
    String rawDate = event['date']?.toString() ?? '';
    try {
      if (rawDate.isNotEmpty) {
        final dateObj = DateTime.parse(rawDate);
        formattedDate = DateFormat("d MMM").format(dateObj); 
      }
    } catch (e) {
      formattedDate = 'TBA';
    }

    final String title = event['title']?.toString() ?? 'No Title';
    final String type = event['type'] ?? 'News';
    final String imageUrl = event['image'] ?? event['imageUrl'] ?? ''; 

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. BACKGROUND IMAGE
            _buildSafeImage(imageUrl),

            // 2. GRADIENT OVERLAY
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0), 
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.8), 
                    Colors.black.withOpacity(0.95), 
                  ],
                  stops: const [0.4, 0.6, 0.85, 1.0],
                ),
              ),
            ),

            // 3. TYPE BADGE (Top Right)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _getTypeColor(type), 
                  borderRadius: BorderRadius.circular(20), 
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                  ]
                ),
                child: Text(
                  type.toUpperCase(),
                  style: GoogleFonts.lato(
                    fontSize: 9, 
                    fontWeight: FontWeight.w900, 
                    color: Colors.white,
                    letterSpacing: 0.5
                  ),
                ),
              ),
            ),

            // 4. CONTENT (Bottom)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center, // ✅ Centered
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Date (Centered Row)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 10, color: Colors.white.withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Text(
                          formattedDate.toUpperCase(),
                          style: GoogleFonts.lato(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withOpacity(0.9), 
                            letterSpacing: 0.5
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 6),

                    // Title (Centered & 3 Lines)
                    Text(
                      _toTitleCase(title),
                      maxLines: 3, // ✅ Allow 3 lines
                      textAlign: TextAlign.center, // ✅ Center text alignment
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(
                        fontSize: 15, 
                        fontWeight: FontWeight.w900,
                        color: Colors.white, 
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 5. RIPPLE EFFECT
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}