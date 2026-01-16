import 'dart:async';
import 'dart:convert';
import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/data_service.dart'; 
import '../services/auth_service.dart';
import '../main.dart'; 
import 'directory_screen.dart';
import 'profile_screen.dart';
import 'events_screen.dart';
import 'jobs_screen.dart'; 
import 'about_screen.dart';
import 'event_detail_screen.dart';
import 'programme_detail_screen.dart';
import 'login_screen.dart';
import '../widgets/digital_id_card.dart'; 

class HomeScreen extends StatefulWidget {
  final String? userName;
  const HomeScreen({super.key, this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  List<int> _tabHistory = [0];
  late List<Widget> _screens;
  String _loadedName = "Alumni"; 

  @override
  void initState() {
    super.initState();
    _resolveUserName();
  }

  void _resolveUserName() async {
    if (widget.userName != null) {
      if (mounted) setState(() => _loadedName = widget.userName!);
    } else {
      final prefs = await SharedPreferences.getInstance();
      
      if (!mounted) return;

      final savedName = prefs.getString('user_name');
      if (savedName != null) {
        setState(() => _loadedName = savedName);
      }
    }
    
    if (!mounted) return;

    setState(() {
      _screens = [
        _DashboardView(userName: _loadedName),
        const EventsScreen(),
        const JobsScreen(), 
        const DirectoryScreen(),
        ProfileScreen(userName: _loadedName),
      ];
    });
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
      _tabHistory.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_screens.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final navBarColor = Theme.of(context).cardColor;
    
    return PopScope(
      canPop: _tabHistory.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _tabHistory.removeLast();
          _currentIndex = _tabHistory.last;
        });
      },
      child: Scaffold(
        body: _screens[_currentIndex],
        
        floatingActionButton: SizedBox(
          width: 58, 
          height: 58, 
          child: FloatingActionButton(
            onPressed: () => _onTabTapped(2), 
            backgroundColor: _currentIndex == 2 ? primaryColor : Colors.grey, 
            elevation: 6.0, 
            shape: const CircleBorder(),
            child: const Icon(Icons.work, color: Colors.white, size: 28), 
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked, 

        bottomNavigationBar: SizedBox(
          height: 60, 
          child: BottomAppBar(
            shape: const CircularNotchedRectangle(), 
            notchMargin: 6.0, 
            color: navBarColor,
            elevation: 0, 
            clipBehavior: Clip.antiAlias,
            padding: EdgeInsets.zero, 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround, 
              crossAxisAlignment: CrossAxisAlignment.center, 
              children: <Widget>[
                _buildNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, index: 0, color: primaryColor),
                _buildNavItem(icon: Icons.event_outlined, activeIcon: Icons.event, index: 1, color: primaryColor),
                const SizedBox(width: 48), 
                _buildNavItem(icon: Icons.list_alt, activeIcon: Icons.list, index: 3, color: primaryColor),
                _buildNavItem(icon: Icons.person_outline, activeIcon: Icons.person, index: 4, color: primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required IconData activeIcon, required int index, required Color color}) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), 
        child: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? color : Colors.grey[400], 
          size: 28, 
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// DASHBOARD VIEW
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
  String _programme = "Member"; 
  String _year = "....";
  String _alumniID = "PENDING"; 

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    _refreshData();
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final localId = prefs.getString('alumni_id');
    if (localId != null) {
      setState(() {
        _alumniID = localId;
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

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _dataService.fetchProfile();
      if (mounted && profile != null) {
        String? apiId = profile['alumniId'];
        setState(() {
          _profileImage = profile['profilePicture'];
          _programme = profile['programmeTitle'] ?? "Member";
          if (_programme.isEmpty) _programme = "Member";
          _year = profile['yearOfAttendance']?.toString() ?? "....";
          if (apiId != null && apiId.isNotEmpty && apiId != "PENDING") {
             _alumniID = apiId;
          }
        });
        if (apiId != null && apiId.isNotEmpty && apiId != "PENDING") {
           final prefs = await SharedPreferences.getInstance();
           await prefs.setString('alumni_id', apiId);
        }
      }
    } catch (e) {
      debugPrint("⚠️ Error loading profile: $e");
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Reunion': return const Color(0xFF1B5E3A); 
      case 'Webinar': return Colors.blue[700]!;     
      case 'Seminar': return Colors.purple[700]!;   
      case 'News':    return Colors.orange[800]!;   
      case 'Conference': return const Color(0xFF0D47A1); 
      case 'Workshop':   return const Color(0xFF00695C); 
      case 'Symposium':  return const Color(0xFFAD1457); 
      case 'AGM':        return const Color(0xFFFF8F00); 
      case 'Induction':  return const Color(0xFF2E7D32); 
      case 'Event':      return Colors.indigo[900]!;     
      default:           return Colors.grey[700]!;
    }
  }

  // ✅ HELPER: Handles both HTTP URLs and Base64 Strings
  Widget _buildSafeImage(String? imageUrl, {IconData fallbackIcon = Icons.image}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Icon(fallbackIcon, color: Colors.grey[400], size: 40);
    }

    // 1. If it's a web URL
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey[400], size: 40),
      );
    }

    // 2. If it's Base64
    try {
      String cleanBase64 = imageUrl;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      return Image.memory(
        base64Decode(cleanBase64),
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Icon(Icons.broken_image, color: Colors.grey[400], size: 40),
      );
    } catch (e) {
      return Icon(fallbackIcon, color: Colors.grey[400], size: 40);
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
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 18, 
            // ✅ CHANGED: White in Dark Mode, Primary in Light Mode
            color: isDark ? Colors.white : primaryColor
          ),
        ),
        backgroundColor: cardColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // ✅ CHANGED: About Icon Color
          IconButton(
            icon: Icon(Icons.info_outline, color: isDark ? Colors.white : primaryColor, size: 22),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreen())),
          ),
          
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: IconButton(
              tooltip: 'Switch Theme',
              icon: ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier, 
                builder: (context, currentMode, _) {
                  bool isCurrentlyDark = currentMode == ThemeMode.dark || 
                      (currentMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
                  
                  return Icon(
                    isCurrentlyDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    // ✅ CHANGED: Theme Icon Color
                    color: isDark ? Colors.white : primaryColor,
                    size: 24,
                  );
                },
              ),
              onPressed: () {
                themeNotifier.value = themeNotifier.value == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark;
              },
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
                
                DigitalIDCard(
                    userName: widget.userName, 
                    programme: _programme,
                    year: _year,
                    alumniID: _alumniID,
                    imageUrl: _profileImage ?? "", 
                ),

                const SizedBox(height: 15),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        FutureBuilder<List<dynamic>>(
                          future: _programmesFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(20.0),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final programmes = snapshot.data ?? [];
                            if (programmes.isEmpty) return const SizedBox.shrink();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Featured Programmes",
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                                ),
                                const SizedBox(height: 15),
                                
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 180,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: MediaQuery.of(context).size.width < 600 ? 0.80 : 0.85, 
                                  ),
                                  itemCount: programmes.length,
                                  itemBuilder: (context, index) {
                                    return _buildProgrammeCard(programmes[index]);
                                  },
                                ),
                                const SizedBox(height: 25),
                              ],
                            );
                          },
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text.rich(
                              TextSpan(
                                style: TextStyle(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold
                                ),
                                children: [
                                  TextSpan(
                                    text: "Recent & Upcoming ",
                                    style: TextStyle(color: textColor), 
                                  ),
                                  TextSpan(
                                    text: "Events",
                                    style: TextStyle(color: primaryColor), 
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: _refreshData,
                              child: Icon(Icons.refresh, size: 18, color: primaryColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),

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

                            return GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 180,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: MediaQuery.of(context).size.width < 600 ? 0.80 : 0.85, 
                              ),
                              itemCount: events.length,
                              itemBuilder: (context, index) {
                                return _buildEventCard(context, events[index]);
                              },
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
    final titleColor = isDark ? Colors.greenAccent[400] : const Color(0xFF1B5E20);
    final String? programmeImage = prog['image'] ?? prog['imageUrl'];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.grey.withOpacity(0.1), 
              blurRadius: 6, 
              offset: const Offset(0, 3)
            ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProgrammeDetailScreen(programme: prog),
              ),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  height: 90, 
                  width: double.infinity,
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  child: _buildSafeImage(programmeImage, fallbackIcon: Icons.school),
                ),
              ),
              Expanded( 
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      Text(
                        prog['title'] ?? "Programme",
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.visible, 
                        style: TextStyle(
                          fontWeight: FontWeight.w800, 
                          fontSize: 12.0,            
                          color: titleColor,            
                          height: 1.1,
                        ),
                      ),
                      
                      const SizedBox(height: 6), 

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.green[900]!.withOpacity(0.3) : const Color(0xFFE8F5E9), 
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          prog['code']?.toUpperCase() ?? "PIC",
                          style: TextStyle(
                            fontSize: 10, 
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.green[200] : const Color(0xFF1B5E20), 
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
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
    final titleColor = isDark ? Colors.greenAccent[400] : const Color(0xFF1B5E20);

    String formattedDate = 'TBA';
    String rawDate = data['date']?.toString() ?? '';
    String type = data['type'] ?? 'News';
    final String? imageUrl = data['image'] ?? data['imageUrl'];
    
    try {
      if (rawDate.isNotEmpty) {
        final dateObj = DateTime.parse(rawDate);
        formattedDate = DateFormat("d MMM, y").format(dateObj); 
      }
    } catch (e) {
       formattedDate = data['date']?.toString() ?? 'TBA';
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.grey.withOpacity(0.1), 
              blurRadius: 6, 
              offset: const Offset(0, 3)
            ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            final String resolvedId = (data['_id'] ?? data['id'] ?? '').toString();

            final safeData = {
              ...data.map((key, value) => MapEntry(key, value.toString())),
              'rawDate': rawDate,
              'date': formattedDate,
              '_id': resolvedId,
            };

            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EventDetailScreen(eventData: safeData)),
            );
          },
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  height: 90, 
                  width: double.infinity,
                  color: isDark ? Colors.grey[850] : Colors.grey[100],
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ✅ USE SAFE IMAGE
                      _buildSafeImage(imageUrl, fallbackIcon: Icons.event),
                      
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getTypeColor(type).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
                          ),
                          child: Text(
                            type.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 8, 
                              fontWeight: FontWeight.w900, 
                              letterSpacing: 0.3
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded( 
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), 
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, 
                    children: [
                      Text(
                        data['title'] ?? "Untitled Event",
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontWeight: FontWeight.w800, 
                          fontSize: 12.0,             
                          color: titleColor,            
                          height: 1.1,
                        ),
                      ),
                      
                      const SizedBox(height: 6), 

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.green[900]!.withOpacity(0.3) : const Color(0xFFE8F5E9), 
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          formattedDate.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9, 
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.green[200] : const Color(0xFF1B5E20), 
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}