import 'dart:async';
import 'dart:convert';
import 'dart:math'; 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/data_service.dart'; 
import '../services/auth_service.dart'; 
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
      setState(() => _loadedName = widget.userName!);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final savedName = prefs.getString('user_name');
      if (savedName != null && mounted) {
        setState(() => _loadedName = savedName);
      }
    }
    
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
        
        // 1. JOBS ICON (Floating Button)
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

        // 2. BOTTOM APP BAR (White Box)
        bottomNavigationBar: SizedBox(
          height: 60, // ✅ Fixed height
          child: BottomAppBar(
            shape: const CircularNotchedRectangle(), 
            notchMargin: 6.0, 
            color: navBarColor,
            elevation: 0, 
            clipBehavior: Clip.antiAlias,
            padding: EdgeInsets.zero, 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround, 
              // ✅ CHANGED: Center vertically instead of pushing to bottom
              crossAxisAlignment: CrossAxisAlignment.center, 
              children: <Widget>[
                _buildNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, index: 0, color: primaryColor),
                _buildNavItem(icon: Icons.event_outlined, activeIcon: Icons.event, index: 1, color: primaryColor),

                const SizedBox(width: 48), // Spacer

                _buildNavItem(icon: Icons.list_alt, activeIcon: Icons.list, index: 3, color: primaryColor),
                _buildNavItem(icon: Icons.person_outline, activeIcon: Icons.person, index: 4, color: primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ Helper to position icons
  Widget _buildNavItem({required IconData icon, required IconData activeIcon, required int index, required Color color}) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _onTabTapped(index),
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        // ✅ CHANGED: Removed bottom padding to ensure true centering
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
// DASHBOARD VIEW (Unchanged)
// ---------------------------------------------------------
class _DashboardView extends StatefulWidget {
  final String userName;
  const _DashboardView({required this.userName});

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> with SingleTickerProviderStateMixin {
  final DataService _dataService = DataService();
  final AuthService _authService = AuthService();

  late Future<List<dynamic>> _eventsFuture;
  late Future<List<dynamic>> _programmesFuture;
  
  late AnimationController _bellController;
  Timer? _notificationTimer; 

  String? _profileImage;
  String _programme = "Member"; 
  String _year = "....";
  String _alumniID = "PENDING"; 
  int _unreadNotifications = 0; 

  @override
  void initState() {
    super.initState();
    _bellController = AnimationController(
      duration: const Duration(milliseconds: 1000), 
      vsync: this,
    );

    _loadLocalData();
    _refreshData();
    _checkAuthenticatedNotifications(); 
    
    _notificationTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
      _checkAuthenticatedNotifications();
    });
  }

  @override
  void dispose() {
    _bellController.dispose();
    _notificationTimer?.cancel(); 
    super.dispose();
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final localId = prefs.getString('alumni_id');
    if (localId != null && mounted) {
      setState(() {
        _alumniID = localId;
      });
    }
  }

  Future<void> _checkAuthenticatedNotifications() async {
    try {
      final int count = await _dataService.fetchUnreadNotificationCount();
      if (mounted) {
        setState(() {
          _unreadNotifications = count;
          if (_unreadNotifications > 0) {
            if (!_bellController.isAnimating) {
              _bellController.repeat(reverse: true);
            }
          } else {
            _bellController.stop();
            _bellController.reset();
          }
        });
      }
    } catch (e) {
      // Fallback
    }
  }

  void _refreshData() {
    setState(() {
      _eventsFuture = _dataService.fetchEvents();
      _programmesFuture = _authService.getProgrammes();
      _loadUserProfile(); 
      _checkAuthenticatedNotifications(); 
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
      print("⚠️ Error loading profile: $e");
    }
  }

  void _showNotificationSheet() {
    final sheetColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;

    Future<List<dynamic>> notificationFuture = _dataService.fetchMyNotifications();

    showModalBottomSheet(
      context: context,
      backgroundColor: sheetColor, 
      isScrollControlled: true, 
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7, 
              padding: const EdgeInsets.all(20),
              child: Column(
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
                          setState(() {
                            _unreadNotifications = 0;
                            _bellController.stop(); 
                            _bellController.reset();
                          }); 
                        },
                        child: const Text("Close", style: TextStyle(color: Colors.grey)),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: notificationFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final notifications = snapshot.data ?? [];
                        
                        if (notifications.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none, size: 40, color: Colors.grey[300]),
                                const SizedBox(height: 10),
                                const Text("No new notifications", style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: notifications.length,
                          itemBuilder: (context, index) {
                            final n = notifications[index];
                            return _buildNotificationTile(
                              n['title'] ?? "Update", 
                              n['message'] ?? "",
                              n['_id'],
                              () async {
                                await _dataService.deleteNotification(n['_id']);
                                setSheetState(() {
                                  notificationFuture = _dataService.fetchMyNotifications();
                                });
                                _checkAuthenticatedNotifications();
                              }
                            );
                          },
                        );
                      }
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    ).whenComplete(() {
      _checkAuthenticatedNotifications(); 
    });
  }

  Widget _buildNotificationTile(String title, String subtitle, String? id, VoidCallback onDelete) {
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
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          if (id != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
        ],
      ),
    );
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
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: _showNotificationSheet,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: Tween(begin: -0.05, end: 0.05).animate(
                      CurvedAnimation(parent: _bellController, curve: Curves.easeInOut),
                    ),
                    child: Icon(
                      _unreadNotifications > 0 ? Icons.notifications_active : Icons.notifications_none_outlined,
                      color: _unreadNotifications > 0 ? const Color(0xFFD32F2F) : primaryColor,
                      size: 26,
                    ),
                  ),
                  if (_unreadNotifications > 0)
                    Positioned(
                      top: 8,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: cardColor, width: 1.5),
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Center(
                          child: Text(
                            '$_unreadNotifications',
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 9, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
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
                                    // ✅ FIXED: Increased ratio from 0.70 to 0.80 -> Makes card shorter vertically
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
                                // ✅ FIXED: Increased ratio from 0.70 to 0.80 -> Makes card shorter vertically
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
                  child: programmeImage != null && programmeImage.isNotEmpty
                      ? Image.network(
                          programmeImage,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Icon(Icons.image, color: Colors.grey[400], size: 40),
                        )
                      : Icon(Icons.school, color: Colors.grey[400], size: 40),
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
    final titleColor = isDark ? Colors.greenAccent[400] : const Color(0xFF1B5E20);

    String formattedDate = 'TBA';
    String rawDate = data['date']?.toString() ?? '';
    String type = data['type'] ?? 'News';
    
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
                      Image.network(
                        data['image'] ?? data['imageUrl'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => Icon(Icons.event, color: Colors.grey[400], size: 40),
                      ),
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