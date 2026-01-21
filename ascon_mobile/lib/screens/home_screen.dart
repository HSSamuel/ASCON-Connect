import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'directory_screen.dart';
import 'profile_screen.dart';
import 'events_screen.dart';
import 'jobs_screen.dart';
import 'about_screen.dart';
import 'event_detail_screen.dart';
import 'programme_detail_screen.dart';
import 'alumni_detail_screen.dart';
import '../widgets/digital_id_card.dart';
import '../viewmodels/dashboard_view_model.dart';

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
        _DashboardView(
          userName: _loadedName,
          onTabChange: _onTabTapped, 
        ),
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
    if (_screens.isEmpty)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

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
                _buildNavItem(
                    icon: Icons.dashboard_outlined,
                    activeIcon: Icons.dashboard,
                    index: 0,
                    color: primaryColor),
                _buildNavItem(
                    icon: Icons.event_outlined,
                    activeIcon: Icons.event,
                    index: 1,
                    color: primaryColor),
                const SizedBox(width: 48),
                _buildNavItem(
                    icon: Icons.list_alt,
                    activeIcon: Icons.list,
                    index: 3,
                    color: primaryColor),
                _buildNavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    index: 4,
                    color: primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
      {required IconData icon,
      required IconData activeIcon,
      required int index,
      required Color color}) {
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
  final Function(int) onTabChange;

  const _DashboardView({
    required this.userName, 
    required this.onTabChange
  });

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  final DashboardViewModel _viewModel = DashboardViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.loadData();
  }

  Widget _buildSafeImage(String? imageUrl,
      {IconData fallbackIcon = Icons.image, BoxFit fit = BoxFit.cover}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Icon(fallbackIcon, color: Colors.grey[400], size: 40);
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: fit,
        errorBuilder: (c, e, s) =>
            Icon(Icons.broken_image, color: Colors.grey[400], size: 40),
      );
    }

    try {
      String cleanBase64 = imageUrl;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      return Image.memory(
        base64Decode(cleanBase64),
        fit: fit,
        errorBuilder: (c, e, s) =>
            Icon(Icons.broken_image, color: Colors.grey[400], size: 40),
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

    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            title: Text(
              "Dashboard",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : primaryColor),
            ),
            backgroundColor: cardColor,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: Icon(Icons.info_outline,
                    color: isDark ? Colors.white : primaryColor, size: 22),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (context) => const AboutScreen())),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: IconButton(
                  tooltip: 'Switch Theme',
                  icon: ValueListenableBuilder<ThemeMode>(
                    valueListenable: themeNotifier,
                    builder: (context, currentMode, _) {
                      bool isCurrentlyDark = currentMode == ThemeMode.dark ||
                          (currentMode == ThemeMode.system &&
                              MediaQuery.of(context).platformBrightness ==
                                  Brightness.dark);

                      return Icon(
                        isCurrentlyDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
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
              onRefresh: () async => await _viewModel.loadData(),
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ------------------------------------------------
                    // 0️⃣ MAIN HEADER (ID CARD)
                    // ------------------------------------------------
                    DigitalIDCard(
                      userName: widget.userName,
                      programme: _viewModel.programme,
                      year: _viewModel.year,
                      alumniID: _viewModel.alumniID,
                      imageUrl: _viewModel.profileImage,
                    ),

                    const SizedBox(height: 20),

                    // ------------------------------------------------
                    // 1️⃣ ALUMNI NETWORK (Top 5 Avatars)
                    // ------------------------------------------------
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text("Alumni Network",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor)),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_viewModel.isLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                    else if (_viewModel.topAlumni.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text("No recently active alumni found.", style: TextStyle(color: Colors.grey)),
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AlumniDetailScreen(alumniData: alumni),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 20.0),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: primaryColor.withOpacity(0.5), width: 2),
                                      ),
                                      child: CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.grey[200],
                                        child: ClipOval(
                                          child: SizedBox(
                                            width: 56, height: 56,
                                            child: _buildSafeImage(img, fallbackIcon: Icons.person),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      firstName,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    
                    const SizedBox(height: 25),

                    // ------------------------------------------------
                    // 2️⃣ UPCOMING EVENTS (Matches Flyer Image: WHITE CARD)
                    // ------------------------------------------------
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Upcoming Events",
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor)),
                          GestureDetector(
                            onTap: () => widget.onTabChange(1), 
                            child: Icon(Icons.arrow_forward, size: 20, color: primaryColor),
                          ),
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
                        itemBuilder: (context, index) {
                          // ✅ EVENTS = WHITE CARD (Leadership Summit Style)
                          return _buildWhiteCard(
                            context, _viewModel.events[index], isEvent: true);
                        },
                      ),

                    const SizedBox(height: 25),

                    // ------------------------------------------------
                    // 3️⃣ FEATURED PROGRAMMES (Matches Flyer Image: IMAGE BACKGROUND)
                    // ------------------------------------------------
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text("Featured Programmes",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor)),
                    ),
                    const SizedBox(height: 12),
                    
                    if (_viewModel.isLoading)
                      const SizedBox.shrink()
                    else if (_viewModel.programmes.isEmpty)
                      _buildEmptyState("No active programmes")
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _viewModel.programmes.length > 3 ? 3 : _viewModel.programmes.length, 
                        separatorBuilder: (c, i) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          // ✅ PROGRAMMES = IMAGE CARD (News/Highlights Style)
                          return _buildImageCard(
                            context, _viewModel.programmes[index], isProgramme: true);
                        },
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

  // ------------------------------------------------
  // 🎨 STYLE A: WHITE CARD (Used for Events)
  // ------------------------------------------------
  Widget _buildWhiteCard(BuildContext context, Map<String, dynamic> data, {bool isEvent = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final badgeColor = const Color(0xFFE65100); // Deep Orange for Badge
    
    // Data Parsing
    String title = data['title'] ?? "Untitled";
    String subtitle = "";
    String badgeTop = "";
    String badgeBottom = "";

    if (isEvent) {
      // Event Specifics
      String location = data['location'] ?? "ASCON Complex";
      String time = "TBA";
      String rawDate = data['date']?.toString() ?? '';
      
      if (rawDate.isNotEmpty) {
        try {
          final dateObj = DateTime.parse(rawDate);
          badgeTop = DateFormat("d").format(dateObj); // "25"
          badgeBottom = DateFormat("MMM").format(dateObj).toUpperCase(); // "OCT"
          time = DateFormat("h:mm a").format(dateObj); // "11:10 AM"
        } catch (e) {}
      }
      subtitle = "$time • $location";
    } else {
      // Programme Specifics (Fallback)
      badgeTop = data['code']?.toUpperCase() ?? "PG";
      badgeBottom = "CODE";
      subtitle = "Tap to view details";
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
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
          onTap: () {
             if (isEvent) {
               final String resolvedId = (data['_id'] ?? data['id'] ?? '').toString();
               final safeData = {...data.map((key, value) => MapEntry(key, value.toString())), '_id': resolvedId};
               Navigator.push(context, MaterialPageRoute(builder: (c) => EventDetailScreen(eventData: safeData)));
             } else {
               Navigator.push(context, MaterialPageRoute(builder: (c) => ProgrammeDetailScreen(programme: data)));
             }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 1️⃣ Left Icon Box (Dark Blue)
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A237E), // Dark Blue
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isEvent ? Icons.location_on : Icons.school, 
                    color: Colors.white, size: 28
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // 2️⃣ Middle Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // Subtitle (Time/Location or Generic)
                      Row(
                        children: [
                          if (isEvent) Icon(Icons.access_time, size: 14, color: Colors.grey),
                          if (isEvent) const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // 3️⃣ Right Badge (Orange)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        badgeTop,
                        style: TextStyle(
                          fontSize: isEvent ? 18 : 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (badgeBottom.isNotEmpty)
                      Text(
                        badgeBottom,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
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

  // ------------------------------------------------
  // 🎨 STYLE B: IMAGE BACKGROUND (Used for Programmes)
  // ------------------------------------------------
  Widget _buildImageCard(BuildContext context, Map<String, dynamic> data, {bool isProgramme = false}) {
    final String title = data['title'] ?? "Untitled";
    final String? imageUrl = data['image'] ?? data['imageUrl'];
    String tagText = isProgramme ? "PROGRAMME" : "NEWS";
    String subtitle = "";

    if (isProgramme) {
      String code = data['code']?.toUpperCase() ?? "";
      if (code.isNotEmpty) tagText += " • $code";
      subtitle = "Tap to view details & apply";
    } else {
      subtitle = "Tap to read more";
    }

    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[300], // Fallback color
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            if (isProgramme) {
               Navigator.push(context, MaterialPageRoute(builder: (c) => ProgrammeDetailScreen(programme: data)));
            }
          },
          child: Stack(
            children: [
              // 1. Background Image
              Positioned.fill(
                child: _buildSafeImage(imageUrl, fallbackIcon: isProgramme ? Icons.school : Icons.article, fit: BoxFit.cover),
              ),
              
              // 2. Gradient Overlay (Bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Text Content
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tagText,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
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
    final textColor = Theme.of(context).textTheme.bodyMedium?.color;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message, style: TextStyle(color: textColor)),
      ),
    );
  }
}