import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; // ✅ Required for storage

import '../config.dart';
import 'directory_screen.dart';
import 'profile_screen.dart';
import 'events_screen.dart';
import 'about_screen.dart';
import 'event_detail_screen.dart';
import 'login_screen.dart'; // ✅ Required for redirection

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
// ✅ DASHBOARD VIEW (Stateful for API & Logout Logic)
// ---------------------------------------------------------
class _DashboardView extends StatefulWidget {
  final String userName;
  const _DashboardView({required this.userName});

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  late Future<List<dynamic>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = fetchEvents();
  }

  // ✅ HELPER: Force Logout if User Deleted/Token Invalid
  Future<void> _forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all stored data

    if (!mounted) return;

    // Navigate to Login and remove all back history
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false, 
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Session expired. Please login again."), backgroundColor: Colors.red),
    );
  }

  // ✅ FETCH EVENTS (With Security Check)
  Future<List<dynamic>> fetchEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token'); // Get stored token

    final url = Uri.parse('${AppConfig.baseUrl}/api/events');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // ✅ Send Token to Backend
        },
      );

      // ✅ SECURITY CHECK: If 401 (Unauthorized), User might be deleted
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
            icon: const Icon(Icons.info_outline, color: Color(0xFF1B5E3A)),
            tooltip: "About ASCON",
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF1B5E3A)),
            tooltip: "Notifications",
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HERO CARD ---
              _buildHeroCard(),

              const SizedBox(height: 30),

              // --- EVENTS SECTION ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Events",
                    style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _eventsFuture = fetchEvents(); // Refresh functionality
                      });
                    },
                    child: const Icon(Icons.refresh, size: 20, color: Color(0xFF1B5E3A)),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // ✅ FUTURE BUILDER FOR EVENTS
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
                    return _buildEmptyState("No Upcoming Events\nCheck back later.");
                  }

                  return Column(
                    children: events.map((event) {
                      return _buildEventCard(context, {
                        'title': event['title'] ?? 'No Title',
                        'date': event['date'] ?? 'TBA',
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

  // --- HELPER WIDGETS ---

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E3A), Color(0xFF2E8B57)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1B5E3A).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome back,",
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    widget.userName,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const CircleAvatar(
                  radius: 26, // ✅ INCREASED SIZE (was 22)
                  backgroundColor: Color(0xFFF5F7F6),
                  child: Icon(Icons.person, color: Color(0xFF1B5E3A), size: 30), // ✅ INCREASED ICON
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user, color: Colors.amberAccent, size: 18),
                const SizedBox(width: 8),
                Text(
                  "Verified Member",
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
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
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy, size: 50, color: Colors.grey[400]),
          const SizedBox(height: 15),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> data) {
    return GestureDetector(
      onTap: () {
        // Convert dynamic map to string map safely
        final safeData = data.map((key, value) => MapEntry(key, value.toString()));
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EventDetailScreen(eventData: safeData),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                data['image'],
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => Container(height: 140, color: Colors.grey[200], child: const Icon(Icons.event, color: Colors.grey)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF1B5E3A)),
                      const SizedBox(width: 4),
                      Text(
                        data['date'],
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1B5E3A)),
                      ),
                      const SizedBox(width: 15),
                      const Icon(Icons.location_on, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          data['location'],
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data['title'],
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
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