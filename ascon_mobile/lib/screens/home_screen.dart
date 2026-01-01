import 'dart:async'; 
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // ✅ Required for Date Format

import '../config.dart';
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

class _DashboardView extends StatefulWidget {
  final String userName;
  const _DashboardView({required this.userName});

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  late Future<List<dynamic>> _eventsFuture;
  String? _profileImage;
  int _unreadNotifications = 2; 

  @override
  void initState() {
    super.initState();
    _eventsFuture = fetchEvents();
    _fetchProfileImage(); 
  }

  Future<void> _fetchProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final url = Uri.parse('${AppConfig.baseUrl}/api/profile/me');

      final response = await http.get(url, headers: {'auth-token': token ?? ''});

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _profileImage = data['profilePicture']);
      }
    } catch (e) {
      debugPrint("Error fetching profile image: $e");
    }
  }

  Future<void> _forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false, 
    );
  }

  Future<List<dynamic>> fetchEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final url = Uri.parse('${AppConfig.baseUrl}/api/events');

    try {
      final response = await http.get(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        _forceLogout();
        return [];
      }

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse is Map && jsonResponse.containsKey('events')) {
          return jsonResponse['events'];
        } else if (jsonResponse is List) {
          return jsonResponse;
        }
      }
    } catch (e) {
      debugPrint("Error fetching events: $e");
    }
    return [];
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
                  Text(
                    "Notifications",
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF1B5E3A)),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _unreadNotifications = 0); 
                    },
                    child: Text("Mark all read", style: GoogleFonts.inter(color: Colors.grey)),
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
                        Text("No new notifications", style: GoogleFonts.inter(color: Colors.grey)),
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
                Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(time, style: GoogleFonts.inter(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "ASCON Dashboard",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: const Color(0xFF1B5E3A)),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeroCard(),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Upcoming Events",
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _eventsFuture = fetchEvents();
                        _fetchProfileImage(); 
                      });
                    },
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
                        'date': event['date'] ?? 'TBA', // Raw date from API
                        'location': event['location'] ?? 'ASCON Complex',
                        'image': event['image'] ?? event['imageUrl'] ?? 'https://via.placeholder.com/600',
                        'description': event['description'] ?? 'No description provided.',
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
                    Text(
                      "Welcome back,",
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    _TypingText(
                      text: widget.userName,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user, color: Colors.amberAccent, size: 16),
                const SizedBox(width: 6),
                Text(
                  "Verified Member",
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11),
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
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> data) {
    // ✅ 1. PARSE & FORMAT DATE FOR CARD
    String formattedDate = data['date'] ?? 'TBA';
    String rawDate = data['date']?.toString() ?? ''; // Keep raw for Detail Screen
    try {
      if (rawDate.isNotEmpty) {
        final dateObj = DateTime.parse(rawDate);
        // "Fri, 12 Jan, 2026 at 4:30 PM"
        formattedDate = DateFormat("EEE, d MMM, y 'at' h:mm a").format(dateObj);
      }
    } catch (e) {
      // Keep default if parsing fails
    }

    return GestureDetector(
      onTap: () {
        // ✅ 2. PASS RAW DATE TO DETAIL SCREEN
        // We add 'rawDate' so the detail screen can do its own full formatting if needed
        final safeData = {
          ...data.map((key, value) => MapEntry(key, value.toString())),
          'rawDate': rawDate, 
          'date': formattedDate, // Display formatted on card
        };
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => EventDetailScreen(eventData: safeData)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                data['image'],
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(height: 120, color: Colors.grey[200], child: const Icon(Icons.event, color: Colors.grey)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 12, color: Color(0xFF1B5E3A)),
                      const SizedBox(width: 6),
                      // ✅ 3. DISPLAY FORMATTED DATE
                      Text(
                        formattedDate,
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF1B5E3A)),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.location_on, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['location'],
                          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data['title'],
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
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