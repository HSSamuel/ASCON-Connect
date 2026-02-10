import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../widgets/shimmer_utils.dart'; 
import 'event_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final DataService _dataService = DataService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allEvents = [];
  List<dynamic> _filteredEvents = [];
  List<dynamic> _featuredEvents = [];
  
  bool _isLoading = true;
  String _selectedCategory = "All";
  
  // News added as requested
  final List<String> _categories = ["All", "News", "Reunion", "Webinar", "Workshop", "General"];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final events = await _dataService.fetchEvents();
      if (mounted) {
        setState(() {
          _allEvents = events;
          _filteredEvents = events;
          _featuredEvents = events.take(3).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterEvents() {
    final query = _searchController.text.toLowerCase();
    
    setState(() {
      _filteredEvents = _allEvents.where((event) {
        final title = (event['title'] ?? "").toString().toLowerCase();
        final type = (event['type'] ?? "General").toString();
        
        final matchesSearch = title.contains(query);
        final matchesCategory = _selectedCategory == "All" || type == _selectedCategory;

        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  Future<void> _addToCalendar(Map<String, dynamic> event) async {
    try {
      final title = Uri.encodeComponent(event['title'] ?? "ASCON Event");
      final details = Uri.encodeComponent(event['description'] ?? "");
      final location = Uri.encodeComponent(event['location'] ?? "Online");
      
      DateTime start = DateTime.now();
      if (event['date'] != null) {
        start = DateTime.parse(event['date']);
      }
      DateTime end = start.add(const Duration(hours: 2));

      final fmt = DateFormat("yyyyMMdd'T'HHmmss");
      final dates = "${fmt.format(start)}/${fmt.format(end)}";

      final urlString = "https://www.google.com/calendar/render?action=TEMPLATE&text=$title&dates=$dates&details=$details&location=$location";
      
      if (await canLaunchUrl(Uri.parse(urlString))) {
        await launchUrl(Uri.parse(urlString), mode: LaunchMode.externalApplication);
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open calendar.")));
      }
    } catch (e) {
      debugPrint("Calendar Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    // Calculate card width ONCE per frame here
    final screenWidth = MediaQuery.of(context).size.width;
    // Formula: (ScreenWidth - ListPaddingLeft - ListPaddingRight - CardMargin) / 2
    double cardWidth = (screenWidth - 48) / 2;
    if (cardWidth < 140) cardWidth = 140; // Safety floor

    final bool showFeatured = _featuredEvents.isNotEmpty && _searchController.text.isEmpty;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // 1. CUSTOM HEADER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Events", style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                      IconButton(
                        icon: Icon(Icons.calendar_month_outlined, color: Colors.grey[600]),
                        onPressed: () {},
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => _filterEvents(),
                    decoration: InputDecoration(
                      hintText: "Find events...",
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ],
              ),
            ),

            // 2. SCROLLABLE CONTENT
            Expanded(
              child: _isLoading
                  ? const EventListSkeleton()
                  : RefreshIndicator(
                      onRefresh: _loadEvents,
                      color: primaryColor,
                      child: CustomScrollView(
                        slivers: [
                          // A. FEATURED CAROUSEL
                          if (showFeatured)
                            SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                                    child: Text("Featured", style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                                  ),
                                  SizedBox(
                                    height: 200,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      itemCount: _featuredEvents.length,
                                      separatorBuilder: (c, i) => const SizedBox(width: 16), 
                                      itemBuilder: (context, index) => _buildFeaturedCard(
                                        context, 
                                        _featuredEvents[index], 
                                        cardWidth 
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // B. CATEGORY CHIPS (WRAPPED)
                          // ✅ CHANGED: Replaced SingleChildScrollView+Row with Wrap for responsiveness
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                              child: Wrap(
                                spacing: 8.0, // Horizontal gap
                                runSpacing: 10.0, // Vertical gap
                                children: _categories.map((cat) {
                                  final isSelected = _selectedCategory == cat;
                                  return ChoiceChip(
                                    label: Text(cat),
                                    selected: isSelected,
                                    selectedColor: primaryColor.withOpacity(0.2),
                                    labelStyle: TextStyle(
                                      color: isSelected ? primaryColor : Colors.grey[600],
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                                    ),
                                    onSelected: (val) {
                                      setState(() {
                                        _selectedCategory = cat;
                                        _filterEvents();
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                          ),

                          // C. ALL EVENTS LIST
                          if (_filteredEvents.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.all(40.0),
                                child: Center(child: Text("No events found.", style: GoogleFonts.lato(color: Colors.grey))),
                              ),
                            )
                          else
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _buildEventRow(_filteredEvents[index]),
                                childCount: _filteredEvents.length,
                              ),
                            ),
                            
                          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(BuildContext context, Map<String, dynamic> event, double cardWidth) {
    final title = event['title'] ?? "Untitled";
    final dateRaw = event['date'];
    String dateStr = "Upcoming";
    if (dateRaw != null) {
      dateStr = DateFormat("EEE, MMM d").format(DateTime.parse(dateRaw));
    }
    final image = event['image'] ?? event['imageUrl'];
    final id = event['_id'] ?? event['id'] ?? DateTime.now().toString();

    return Container(
      width: cardWidth, 
      key: ValueKey(id), 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Image Background
            Positioned.fill(
              child: image != null 
                ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
                : Container(color: Colors.grey[300], child: const Icon(Icons.event, size: 50, color: Colors.grey)),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
              ),
            ),
            // Text Content
            Positioned(
              bottom: 12, left: 10, right: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center, // Center Alignment
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(6)),
                    child: Text(dateStr, style: const TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 4, // More lines
                    textAlign: TextAlign.center, // Center text
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            // Tap Ripple
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final String resolvedId = (event['_id'] ?? event['id'] ?? '').toString();
                    final safeData = {...event.map((key, value) => MapEntry(key, value.toString())), '_id': resolvedId};
                    Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventData: safeData)));
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEventRow(Map<String, dynamic> event) {
    final title = event['title'] ?? "Event";
    final location = event['location'] ?? "TBA";
    final id = event['_id'] ?? event['id'] ?? DateTime.now().toString();
    
    DateTime dateObj = DateTime.now();
    if (event['date'] != null) dateObj = DateTime.parse(event['date']);
    
    final day = DateFormat("d").format(dateObj);
    final month = DateFormat("MMM").format(dateObj).toUpperCase();
    final time = event['time'] ?? DateFormat("h:mm a").format(dateObj);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Container(
      key: ValueKey(id), 
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: () {
          final String resolvedId = (event['_id'] ?? event['id'] ?? '').toString();
          final safeData = {...event.map((key, value) => MapEntry(key, value.toString())), '_id': resolvedId};
          Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventData: safeData)));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Date Box
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(month, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green[700])),
                    Text(day, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(time, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(width: 10),
                        Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Flexible(child: Text(location, style: TextStyle(fontSize: 12, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
                      ],
                    )
                  ],
                ),
              ),

              // Calendar Button
              IconButton(
                icon: const Icon(Icons.calendar_today_outlined, size: 20, color: Colors.blue),
                onPressed: () => _addToCalendar(event),
                tooltip: "Add to Calendar",
              )
            ],
          ),
        ),
      ),
    );
  }
}