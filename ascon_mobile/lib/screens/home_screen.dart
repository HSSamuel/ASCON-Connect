import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:go_router/go_router.dart';

import '../main.dart';
// Note: Imports for screens are no longer needed here as the Router handles them
// But we keep detail screens for the DashboardView
import 'event_detail_screen.dart';
import 'programme_detail_screen.dart';
import 'alumni_detail_screen.dart';
import 'chat_list_screen.dart'; 
import 'about_screen.dart';

import '../widgets/digital_id_card.dart';
import '../viewmodels/dashboard_view_model.dart';
import '../services/socket_service.dart'; 
import '../services/api_client.dart'; 

// ✅ RENAMED & REFACTORED: Now acts as the Shell for GoRouter
class HomeScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  
  const HomeScreen({super.key, required this.navigationShell});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _hasUnreadMessages = false; 
  final ApiClient _api = ApiClient();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshUnreadState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _refreshUnreadState();
      });
    }
  }

  void _refreshUnreadState() {
    _checkUnreadStatus(); 
    _listenForMessages(); 
  }

  Future<void> _checkUnreadStatus() async {
    try {
      final result = await _api.get('/api/chat/unread-status');
      if (mounted && result['success'] == true) {
        final rawData = result['data']?['hasUnread'];
        final bool isUnread = rawData.toString().toLowerCase() == 'true';
        setState(() => _hasUnreadMessages = isUnread);
      }
    } catch (e) {
      debugPrint("Check status error: $e");
    }
  }

  void _listenForMessages() {
    final socket = SocketService().socket;
    if (socket == null) return;
    try {
      socket.off('new_message');
      socket.off('connect');
    } catch (_) {}

    socket.on('new_message', (data) {
      if (mounted) setState(() => _hasUnreadMessages = true);
    });

    socket.on('connect', (_) {
      debugPrint("📡 Socket Reconnected: Checking Unread Status...");
      _checkUnreadStatus();
    });
  }

  void _goBranch(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final navBarColor = Theme.of(context).cardColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = widget.navigationShell.currentIndex;

    final showAppBar = currentIndex == 0;

    // ✅ NEW: CENTRAL ROUTE NAVIGATION FIX
    // Handled at the Shell level so it works perfectly for ALL tabs.
    return PopScope(
      canPop: currentIndex == 0, // Only allow app exit if we are already on Dashboard
      onPopInvoked: (didPop) {
        if (didPop) return;
        // If back is pressed on any other tab, go to Dashboard (Index 0)
        _goBranch(0); 
      },
      child: Scaffold(
        appBar: showAppBar 
          ? AppBar(
              title: Text("Dashboard", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : primaryColor)),
              backgroundColor: Theme.of(context).cardColor,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      icon: Icon(Icons.chat_bubble_outline_rounded, color: isDark ? Colors.white : primaryColor),
                      onPressed: () async {
                        setState(() => _hasUnreadMessages = false); 
                        context.push('/chat').then((_) => _checkUnreadStatus());
                      },
                    ),
                    if (_hasUnreadMessages)
                      Positioned(
                        right: 8, top: 8,
                        child: Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: Colors.red, 
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).cardColor, width: 1.5)
                          ),
                        ),
                      )
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.info_outline, color: isDark ? Colors.white : primaryColor, size: 22),
                  onPressed: () => context.push('/about'),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: IconButton(
                    tooltip: 'Switch Theme',
                    icon: ValueListenableBuilder<ThemeMode>(
                      valueListenable: themeNotifier,
                      builder: (context, currentMode, _) {
                        bool isCurrentlyDark = currentMode == ThemeMode.dark || (currentMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);
                        return Icon(isCurrentlyDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, color: isDark ? Colors.white : primaryColor, size: 24);
                      },
                    ),
                    onPressed: () => themeNotifier.value = themeNotifier.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                  ),
                ),
              ],
            )
          : null, 

        body: widget.navigationShell,

        floatingActionButton: SizedBox(
          width: 58, height: 58,
          child: FloatingActionButton(
            onPressed: () => _goBranch(2), // Jobs Tab
            backgroundColor: currentIndex == 2 ? primaryColor : Colors.grey,
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
                _buildNavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, index: 0, color: primaryColor, currentIndex: currentIndex),
                _buildNavItem(icon: Icons.event_outlined, activeIcon: Icons.event, index: 1, color: primaryColor, currentIndex: currentIndex),
                const SizedBox(width: 48), // Gap for FAB
                _buildNavItem(icon: Icons.list_alt, activeIcon: Icons.list, index: 3, color: primaryColor, currentIndex: currentIndex),
                _buildNavItem(icon: Icons.person_outline, activeIcon: Icons.person, index: 4, color: primaryColor, currentIndex: currentIndex),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required IconData activeIcon, required int index, required Color color, required int currentIndex}) {
    final isSelected = currentIndex == index;
    return InkWell(
      onTap: () => _goBranch(index),
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
// DASHBOARD VIEW (Formerly Private)
// ---------------------------------------------------------
class DashboardView extends StatefulWidget {
  final String? userName; // Optional now, fetches locally if null
  const DashboardView({super.key, this.userName});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  final DashboardViewModel _viewModel = DashboardViewModel();
  String _displayName = "Alumni";

  @override
  void initState() {
    super.initState();
    _viewModel.loadData();
    _loadName();
  }

  Future<void> _loadName() async {
    if (widget.userName != null) {
      setState(() => _displayName = widget.userName!);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('user_name');
      if (saved != null && mounted) {
        setState(() => _displayName = saved);
      }
    }
  }

  Widget _buildSafeImage(String? imageUrl, {IconData fallbackIcon = Icons.image, BoxFit fit = BoxFit.cover}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(color: Colors.grey[200], child: Center(child: Icon(fallbackIcon, color: Colors.grey[400], size: 40)));
    }
    if (imageUrl.contains('googleusercontent.com/profile/picture/0')) {
       return Container(color: Colors.grey[200], child: Center(child: Icon(fallbackIcon, color: Colors.grey[400], size: 40)));
    }
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl, fit: fit,
        placeholder: (context, url) => Container(color: Colors.grey[200]),
        errorWidget: (context, url, error) => Container(color: Colors.grey[200], child: Icon(Icons.broken_image, color: Colors.grey[400], size: 40)),
      );
    }
    try {
      String cleanBase64 = imageUrl;
      if (cleanBase64.contains(',')) cleanBase64 = cleanBase64.split(',').last;
      return Image.memory(base64Decode(cleanBase64), fit: fit, errorBuilder: (c, e, s) => Container(color: Colors.grey[200], child: Icon(Icons.broken_image, color: Colors.grey[400], size: 40)));
    } catch (e) {
      return Container(color: Colors.grey[200], child: Icon(fallbackIcon, color: Colors.grey[400], size: 40));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: scaffoldBg,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async => await _viewModel.loadData(),
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 0️⃣ MAIN HEADER (ID CARD)
                    DigitalIDCard(
                      userName: _displayName,
                      programme: _viewModel.programme,
                      year: _viewModel.year,
                      alumniID: _viewModel.alumniID,
                      imageUrl: _viewModel.profileImage,
                    ),

                    const SizedBox(height: 20),

                    // 1️⃣ ALUMNI NETWORK
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text("Alumni Network", style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_viewModel.isLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                    else if (_viewModel.topAlumni.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text("No recently active alumni found.", style: GoogleFonts.lato(color: Colors.grey)),
                      )
                    else
                      SizedBox(
                        height: 90, 
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _viewModel.topAlumni.length,
                          itemBuilder: (context, index) {
                            final alumni = _viewModel.topAlumni[index];
                            final String name = alumni['fullName'] ?? "User";
                            final String img = alumni['profilePicture'] ?? "";
                            final String firstName = name.split(" ")[0];

                            return GestureDetector(
                              onTap: () {
                                // ✅ FIX: Use rootNavigator: true to HIDE Bottom Nav
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniData: alumni))
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 20.0),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: primaryColor.withOpacity(0.5), width: 2)),
                                      child: CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.grey[200],
                                        child: ClipOval(child: SizedBox(width: 56, height: 56, child: _buildSafeImage(img, fallbackIcon: Icons.person))),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(firstName, style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w500, color: textColor)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    
                    const SizedBox(height: 25),

                    // 2️⃣ UPCOMING EVENTS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Recent & Upcoming Events", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
                          Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFF4CAF50).withOpacity(0.5), shape: BoxShape.circle)),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_viewModel.isLoading)
                      const SizedBox.shrink()
                    else if (_viewModel.events.isEmpty)
                      _buildEmptyState("No upcoming events")
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _viewModel.events.length,
                        separatorBuilder: (c, i) => const SizedBox(height: 12),
                        itemBuilder: (context, index) => _buildUpcomingEventCard(context, _viewModel.events[index]),
                      ),

                    const SizedBox(height: 25),

                    // 3️⃣ NEWS & UPDATES
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Programme Updates", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
                          Row(
                            children: [
                              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF607D8B), shape: BoxShape.circle)),
                              const SizedBox(width: 4),
                              Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFF607D8B).withOpacity(0.5), shape: BoxShape.circle)),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_viewModel.isLoading)
                      const SizedBox.shrink()
                    else if (_viewModel.programmes.isEmpty)
                      _buildEmptyState("No updates available")
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _viewModel.programmes.length > 3 ? 3 : _viewModel.programmes.length, 
                        separatorBuilder: (c, i) => const SizedBox(height: 16),
                        itemBuilder: (context, index) => _buildNewsUpdateCard(context, _viewModel.programmes[index]),
                      ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUpcomingEventCard(BuildContext context, Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    
    String title = data['title'] ?? "Untitled Event";
    String location = data['location'] ?? "ASCON Complex";
    String day = "25"; String month = "OCT"; String time = "TBA"; 
    String type = (data['type'] ?? "Event").toString().toUpperCase();

    String rawDate = data['date']?.toString() ?? '';
    if (rawDate.isNotEmpty) {
      try {
        final dateObj = DateTime.parse(rawDate);
        day = DateFormat("d").format(dateObj);
        month = DateFormat("MMM").format(dateObj).toUpperCase();
        if (dateObj.hour == 0 && dateObj.minute == 0) { time = "All Day"; } else { time = DateFormat("h:mm a").format(dateObj); }
      } catch (e) { time = "TBA"; }
    }
    if (data['time'] != null && data['time'].toString().isNotEmpty) { time = data['time']; }

    return Container(
      height: 100, 
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
             final String resolvedId = (data['_id'] ?? data['id'] ?? '').toString();
             final safeData = {...data.map((key, value) => MapEntry(key, value.toString())), '_id': resolvedId};
             Navigator.push(context, MaterialPageRoute(builder: (c) => EventDetailScreen(eventData: safeData)));
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0), 
            child: Row(
              children: [
                Container(
                  width: 50, height: 50,
                  decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.1) : primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.location_on_rounded, color: isDark ? Colors.white : primaryColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(location.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, color: Colors.grey[500])),
                      const SizedBox(height: 2),
                      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? Colors.white : primaryColor, height: 1.1)),
                      const SizedBox(height: 4),
                      Row(children: [Icon(Icons.access_time_rounded, size: 14, color: Colors.blueGrey), const SizedBox(width: 4), Text(time, style: GoogleFonts.lato(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w700))]),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, 
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(type, style: GoogleFonts.lato(fontSize: 9, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: 0.5)),
                    ),
                    Container(
                      width: 52,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2))]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min, 
                          children: [
                            Container(height: 22, width: double.infinity, alignment: Alignment.center, color: primaryColor, child: Text(month, style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.0))),
                            Container(height: 28, width: double.infinity, alignment: Alignment.center, color: isDark ? const Color(0xFF2C2C2C) : Colors.white, child: Text(day, style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87, height: 1.0))),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewsUpdateCard(BuildContext context, Map<String, dynamic> data) {
    final String title = data['title'] ?? "Highlights";
    final String? imageUrl = data['image'] ?? data['imageUrl'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final cardColor = Theme.of(context).cardColor; 

    return Container(
      height: 160, width: double.infinity,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: cardColor, boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () { Navigator.push(context, MaterialPageRoute(builder: (c) => ProgrammeDetailScreen(programme: data))); },
          child: Stack(
            children: [
              Positioned.fill(child: _buildSafeImage(imageUrl, fallbackIcon: Icons.business, fit: BoxFit.cover)),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
                      colors: [cardColor.withOpacity(1.0), cardColor.withOpacity(0.95), cardColor.withOpacity(0.6), cardColor.withOpacity(0.0)],
                      stops: const [0.0, 0.45, 0.65, 1.0], 
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0, bottom: 0, left: 20, width: MediaQuery.of(context).size.width * 0.65,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                      child: Text("PROGRAMME", style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.w800, color: primaryColor, letterSpacing: 0.5)),
                    ),
                    Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.w900, height: 1.1, letterSpacing: -0.5)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text("Read Now", style: GoogleFonts.lato(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFD4AF37))),
                        const SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16, color: const Color(0xFFD4AF37)),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(message, style: GoogleFonts.lato(color: Theme.of(context).textTheme.bodyMedium?.color))));
  }
}