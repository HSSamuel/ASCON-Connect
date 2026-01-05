import 'dart:async';
import 'dart:convert'; // Required for base64Decode
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ Required for Local Cache
import '../services/data_service.dart'; 
import '../services/auth_service.dart'; 
import 'directory_screen.dart';
import 'profile_screen.dart';
import 'events_screen.dart';
import 'about_screen.dart';
import 'event_detail_screen.dart';
import 'login_screen.dart';
import '../widgets/digital_id_card.dart'; 

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBarColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final unselectedItemColor = Colors.grey;

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: navBarColor,
          boxShadow: [
            if (!isDark) 
              const BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: primaryColor,
          unselectedItemColor: unselectedItemColor,
          backgroundColor: navBarColor, 
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

  // ✅ DYNAMIC VARIABLES
  String? _profileImage;
  String _programme = "Member"; 
  String _year = "....";
  String _alumniID = "PENDING"; // Default until loaded
  int _unreadNotifications = 2; 

  @override
  void initState() {
    super.initState();
    _loadLocalData(); // 1. Load cached ID immediately for speed
    _refreshData();   // 2. Fetch fresh data from API
  }

  // ✅ STEP 1: Load from Local Storage (Fast)
  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final localId = prefs.getString('alumni_id');
    if (localId != null && mounted) {
      setState(() {
        _alumniID = localId;
        print("✅ Home Screen loaded ID from storage: $_alumniID");
      });
    }
  }

  void _refreshData() {
    setState(() {
      _eventsFuture = _dataService.fetchEvents();
      _programmesFuture = _authService.getProgrammes();
      _loadUserProfile(); 
    });
  }

  // ✅ STEP 2: Sync with Backend (Authentic Source of Truth)
  Future<void> _loadUserProfile() async {
    try {
      final profile = await _dataService.fetchProfile();
      if (mounted && profile != null) {
        
        // 1. Get ID from Profile
        String? apiId = profile['alumniId'];
        
        // 2. Update UI State (Synchronous)
        setState(() {
          // Get Image
          _profileImage = profile['profilePicture'];
          
          // Get Programme
          _programme = profile['programmeTitle'] ?? "Member";
          if (_programme.isEmpty) _programme = "Member";

          // Get Year
          _year = profile['yearOfAttendance']?.toString() ?? "....";

          // Set ID variable if valid
          if (apiId != null && apiId.isNotEmpty && apiId != "PENDING") {
             _alumniID = apiId;
          }
        });

        // 3. Save to Storage (Asynchronous - MUST be outside setState)
        if (apiId != null && apiId.isNotEmpty && apiId != "PENDING") {
           final prefs = await SharedPreferences.getInstance();
           await prefs.setString('alumni_id', apiId);
        }
      }
    } catch (e) {
      print("⚠️ Error loading profile: $e");
    }
  }

  ImageProvider? getProfileImage(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) return null;
    if (imagePath.startsWith('http')) return NetworkImage(imagePath); 
    try { return MemoryImage(base64Decode(imagePath)); } catch (e) { return null; }
  }

  void _showNotificationSheet() {
    final sheetColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetColor, 
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
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
                 _buildNotificationTile("Welcome to ASCON Alumni Network!", "Just now"),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileColor = isDark ? Colors.grey[800] : Colors.grey[50];
    final borderColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.notifications, color: primaryColor, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(
          "Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor),
        ),
        backgroundColor: cardColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline, color: primaryColor, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen())),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Badge(
                isLabelVisible: _unreadNotifications > 0,
                label: Text('$_unreadNotifications', style: const TextStyle(fontSize: 10)),
                backgroundColor: Colors.red,
                child: Icon(Icons.notifications_none_outlined, color: primaryColor, size: 22),
              ),
              onPressed: _showNotificationSheet, 
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => _refreshData(),
          color: primaryColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10), 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                
                // ✅ 1. DYNAMIC DIGITAL ID CARD
                DigitalIDCard(
                    userName: widget.userName, 
                    programme: _programme,
                    year: _year,
                    alumniID: _alumniID,   // ✅ Shows Local first, then updates to Real API ID
                    imageUrl: _profileImage ?? "", 
                ),

                const SizedBox(height: 15),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // FEATURED PROGRAMMES SECTION
                        FutureBuilder<List<dynamic>>(
                          future: _programmesFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Featured Programmes",
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
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

                            if (programmes.isEmpty) {
                              return const SizedBox.shrink(); 
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Featured Programmes",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
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
                            Text(
                              "Upcoming Events",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            GestureDetector(
                              onTap: _refreshData,
                              child: Icon(Icons.refresh, size: 18, color: primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        FutureBuilder<List<dynamic>>(
                          future: _eventsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator(color: primaryColor));
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgrammeCard(Map<String, dynamic> prog) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).dividerColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Container(
      width: 220, 
      margin: const EdgeInsets.only(bottom: 5), 
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark)
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Optional: Handle tap
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.08), 
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.school_rounded, color: primaryColor, size: 22),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey[300]),
                  ],
                ),
                const Spacer(), 
                Text(
                  prog['title'] ?? "Programme",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700, 
                    fontSize: 14,
                    color: textColor, 
                    height: 1.2, 
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100], 
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    prog['code']?.toUpperCase() ?? "ASCON",
                    style: TextStyle(
                      fontSize: 10,
                      color: subTextColor, 
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

  Widget _buildShimmerCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100], 
        borderRadius: BorderRadius.circular(12)
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy, size: 40, color: Colors.grey[400]),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final primaryColor = Theme.of(context).primaryColor;

    String formattedDate = 'TBA';
    String rawDate = data['date']?.toString() ?? '';
    
    try {
      if (rawDate.isNotEmpty) {
        final dateObj = DateTime.parse(rawDate);
        formattedDate = DateFormat("EEE, d MMM, y • h:mm a").format(dateObj);
      }
    } catch (e) {
      // Keep default
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
          color: cardColor, 
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark)
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
                    color: isDark ? Colors.grey[900] : Colors.grey[50],
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
                      Icon(Icons.calendar_month_outlined, size: 14, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        formattedDate,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: primaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  Text(
                    data['title'] ?? 'Untitled Event',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor, height: 1.2), 
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
                          style: TextStyle(fontSize: 12, color: subTextColor), 
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