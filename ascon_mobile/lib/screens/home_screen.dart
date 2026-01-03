import 'dart:async';
import 'dart:convert'; // Required for base64Decode
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import '../services/data_service.dart'; 
import '../services/auth_service.dart'; 
import 'directory_screen.dart';
import 'profile_screen.dart';
import 'events_screen.dart';
import 'about_screen.dart';
import 'event_detail_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      _DashboardView(userName: widget.userName),
      const EventsScreen(),
      const DirectoryScreen(),
      ProfileScreen(userName: widget.userName),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: const Color(0xFF1B5E3A),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          iconSize: 22,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: "Home"),
            BottomNavigationBarItem(icon: Icon(Icons.event_outlined), activeIcon: Icon(Icons.event), label: "Events"),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt), activeIcon: Icon(Icons.list), label: "Directory"),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: "Profile"),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// DASHBOARD VIEW (The main Home Tab)
// ---------------------------------------------------------
class _DashboardView extends StatefulWidget {
  final String userName;
  const _DashboardView({required this.userName});

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  final DataService _dataService = DataService();
  final AuthService _authService = AuthService();

  late Future<List<dynamic>> _eventsFuture;
  late Future<List<dynamic>> _programmesFuture;

  String? _profileImage;
  int _unreadNotifications = 2; 

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _eventsFuture = _dataService.fetchEvents();
      _programmesFuture = _authService.getProgrammes();
      _loadProfileImage();
    });
  }

  Future<void> _loadProfileImage() async {
    final profile = await _dataService.fetchProfile();
    if (mounted && profile != null) {
      setState(() => _profileImage = profile['profilePicture']);
    }
  }

  ImageProvider? getProfileImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http')) return NetworkImage(imagePath); 
    try { return MemoryImage(base64Decode(imagePath)); } catch (e) { return null; }
  }

  void _showNotificationSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Notifications",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E3A)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _unreadNotifications = 0); 
                    },
                    child: const Text("Mark all read", style: TextStyle(color: Colors.grey)),
                  )
                ],
              ),
              const SizedBox(height: 10),
              
              if (_unreadNotifications == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none, size: 40, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text("No new notifications", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              else ...[
                 _buildNotificationTile("Welcome to ASCON Connect!", "Just now"),
                 _buildNotificationTile("Please complete your profile details.", "1 hour ago"),
              ],
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (_unreadNotifications > 0) {
          setState(() => _unreadNotifications = 0);
      }
    });
  }

  Widget _buildNotificationTile(String title, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: const Color(0xFF1B5E3A).withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.notifications, color: Color(0xFF1B5E3A), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Reunion': return const Color(0xFF1B5E3A); // Green
      case 'Webinar': return Colors.blue[700]!;     // Blue
      case 'Seminar': return Colors.purple[700]!;   // Purple
      case 'News':    return Colors.orange[800]!;   // Orange
      default:        return Colors.grey[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "ASCON Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1B5E3A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF1B5E3A), size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen())),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Badge(
                isLabelVisible: _unreadNotifications > 0,
                label: Text('$_unreadNotifications', style: const TextStyle(fontSize: 10)),
                backgroundColor: Colors.red,
                child: const Icon(Icons.notifications_none_outlined, color: Color(0xFF1B5E3A), size: 22),
              ),
              onPressed: _showNotificationSheet, 
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refreshData(),
          color: const Color(0xFF1B5E3A),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(),

                const SizedBox(height: 25),

                // ✅ FEATURED PROGRAMMES SECTION
                // This logic completely hides the section if there are no programmes.
                FutureBuilder<List<dynamic>>(
                  future: _programmesFuture,
                  builder: (context, snapshot) {
                    // 1. Loading State: Show Title + Shimmer
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Featured Programmes",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 140,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [1,2,3].map((_) => _buildShimmerCard()).toList(),
                            ),
                          ),
                          const SizedBox(height: 25),
                        ],
                      );
                    }

                    final programmes = snapshot.data ?? [];

                    // 2. Empty State: HIDE EVERYTHING (Returns 0 size box)
                    if (programmes.isEmpty) {
                      return const SizedBox.shrink(); 
                    }

                    // 3. Data State: Show Title + List
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Featured Programmes",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 140, 
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: programmes.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 12),
                            itemBuilder: (context, index) {
                              final prog = programmes[index];
                              return _buildProgrammeCard(prog);
                            },
                          ),
                        ),
                        const SizedBox(height: 25),
                      ],
                    );
                  },
                ),

                // --- EVENTS SECTION ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Upcoming Events",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    GestureDetector(
                      onTap: _refreshData,
                      child: const Icon(Icons.refresh, size: 18, color: Color(0xFF1B5E3A)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                FutureBuilder<List<dynamic>>(
                  future: _eventsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E3A)));
                    }
                    if (snapshot.hasError) {
                      return _buildEmptyState("Could not load events.");
                    }
                    final events = snapshot.data ?? [];
                    if (events.isEmpty) {
                      return _buildEmptyState("No Upcoming Events");
                    }

                    return Column(
                      children: events.map((event) {
                        return _buildEventCard(context, {
                          'title': event['title'] ?? 'No Title',
                          'date': event['date'] ?? 'TBA', 
                          'location': event['location'] ?? 'ASCON Complex',
                          'image': event['image'] ?? event['imageUrl'] ?? 'https://via.placeholder.com/600',
                          'description': event['description'] ?? 'No description provided.',
                          'type': event['type'] ?? 'News', 
                        });
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ WIDGET: Pro Programme Card
  Widget _buildProgrammeCard(Map<String, dynamic> prog) {
    return Container(
      width: 220, // Slightly wider for better text fit
      margin: const EdgeInsets.only(bottom: 5), // Space for shadow
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Optional: Handle tap (e.g., show details dialog)
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- TOP ROW: Icon & Decoration ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B5E3A).withOpacity(0.08), // Light Green bg
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school_rounded, color: Color(0xFF1B5E3A), size: 22),
                    ),
                    // Optional: A small 'arrow' to show it's clickable
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300]),
                  ],
                ),
                
                const Spacer(), // Pushes text to the middle/bottom

                // --- MIDDLE: Title ---
                Text(
                  prog['title'] ?? "Programme",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700, // Bolder
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.2, // Better line spacing
                    letterSpacing: -0.3,
                  ),
                ),
                
                const SizedBox(height: 12),

                // --- BOTTOM: Code Badge ---
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100], // Subtle grey pill
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Text(
                    prog['code']?.toUpperCase() ?? "ASCON",
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ WIDGET: Loading Shimmer for Programmes
  Widget _buildShimmerCard() {
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16), 
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E3A), Color(0xFF2E8B57)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1B5E3A).withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded( 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Welcome back,",
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    _TypingText(
                      text: widget.userName,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: CircleAvatar(
                  radius: 22, 
                  backgroundColor: const Color(0xFFF5F7F6),
                  backgroundImage: getProfileImage(_profileImage),
                  child: getProfileImage(_profileImage) == null 
                      ? const Icon(Icons.person, color: Color(0xFF1B5E3A), size: 24)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_user, color: Colors.amberAccent, size: 16),
                SizedBox(width: 6),
                Text(
                  "Verified Member",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ✅ UPDATED EVENT CARD
  Widget _buildEventCard(BuildContext context, Map<String, dynamic> data) {
    String formattedDate = 'TBA';
    String rawDate = data['date']?.toString() ?? '';
    
    // Parse Date
    try {
      if (rawDate.isNotEmpty) {
        final dateObj = DateTime.parse(rawDate);
        formattedDate = DateFormat("EEE, d MMM, y • h:mm a").format(dateObj);
      }
    } catch (e) {
      // Keep default if parsing fails
    }

    String type = data['type'] ?? 'News';

    return GestureDetector(
      onTap: () {
        final safeData = {
          ...data.map((key, value) => MapEntry(key, value.toString())),
          'rawDate': rawDate,
          'date': formattedDate,
        };
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EventDetailScreen(eventData: safeData)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    height: 150, 
                    width: double.infinity,
                    color: Colors.grey[50], 
                    child: Image.network(
                      data['image'] ?? data['imageUrl'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Center(
                        child: Icon(Icons.image_not_supported, color: Colors.grey[300], size: 40)
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _getTypeColor(type),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Text(
                      type.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, size: 14, color: Color(0xFF1B5E3A)),
                      const SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1B5E3A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  Text(
                    data['title'] ?? 'Untitled Event',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['location'] ?? 'ASCON Complex',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

// ---------------------------------------------------------
// TYPING TEXT WIDGET
// ---------------------------------------------------------
class _TypingText extends StatefulWidget {
  final String text;
  final TextStyle style;

  const _TypingText({required this.text, required this.style});

  @override
  State<_TypingText> createState() => _TypingTextState();
}

class _TypingTextState extends State<_TypingText> {
  String _displayedText = "";
  int _charIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void didUpdateWidget(covariant _TypingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _restartAnimation();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _restartAnimation() {
    _timer?.cancel();
    setState(() {
      _charIndex = 0;
      _displayedText = "";
    });
    _startAnimation();
  }

  void _startAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_charIndex < widget.text.length) {
          _charIndex++;
          _displayedText = widget.text.substring(0, _charIndex);
        } else {
          timer.cancel();
          Future.delayed(const Duration(seconds: 5), () {
             if (mounted) _restartAnimation();
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _displayedText,
          style: widget.style,
        ),
        if (_charIndex < widget.text.length) 
          Text(
            "|",
            style: widget.style.copyWith(color: Colors.white.withOpacity(0.5)),
          ),
      ],
    );
  }
}