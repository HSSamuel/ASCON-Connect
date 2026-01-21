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
import '../widgets/digital_id_card.dart';
// ✅ Import the ViewModel
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
// DASHBOARD VIEW (REFACTORED WITH VIEWMODEL & MODERN UI)
// ---------------------------------------------------------
class _DashboardView extends StatefulWidget {
  final String userName;
  const _DashboardView({required this.userName});

  @override
  State<_DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<_DashboardView> {
  // ✅ Use the ViewModel
  final DashboardViewModel _viewModel = DashboardViewModel();

  @override
  void initState() {
    super.initState();
    // ✅ Fetch data through ViewModel
    _viewModel.loadData();
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Reunion':
        return const Color(0xFF1B5E3A);
      case 'Webinar':
        return Colors.blue[700]!;
      case 'Seminar':
        return Colors.purple[700]!;
      case 'News':
        return Colors.orange[800]!;
      case 'Conference':
        return const Color(0xFF0D47A1);
      case 'Workshop':
        return const Color(0xFF00695C);
      case 'Symposium':
        return const Color(0xFFAD1457);
      case 'AGM':
        return const Color(0xFFFF8F00);
      case 'Induction':
        return const Color(0xFF2E7D32);
      case 'Event':
        return Colors.indigo[900]!;
      default:
        return Colors.grey[700]!;
    }
  }

  Widget _buildSafeImage(String? imageUrl,
      {IconData fallbackIcon = Icons.image}) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Icon(fallbackIcon, color: Colors.grey[400], size: 40);
    }

    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
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
        fit: BoxFit.cover,
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
                    // ✅ Digital ID Card
                    DigitalIDCard(
                      userName: widget.userName,
                      programme: _viewModel.programme,
                      year: _viewModel.year,
                      alumniID: _viewModel.alumniID,
                      imageUrl: _viewModel.profileImage,
                    ),

                    const SizedBox(height: 25),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ------------------------------------------------
                          // 🎓 FEATURED PROGRAMMES (Updated UI)
                          // ------------------------------------------------
                          if (_viewModel.isLoading)
                            const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(20.0),
                                    child: CircularProgressIndicator()))
                          else if (_viewModel.programmes.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Featured Programmes",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: textColor),
                                ),
                                const SizedBox(height: 15),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 180,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    // 🎨 Adjusted Aspect Ratio for Taller Cards
                                    childAspectRatio: 0.8,
                                  ),
                                  itemCount: _viewModel.programmes.length,
                                  itemBuilder: (context, index) {
                                    return _buildProgrammeCard(
                                        _viewModel.programmes[index]);
                                  },
                                ),
                                const SizedBox(height: 30),
                              ],
                            ),

                          // ------------------------------------------------
                          // 📅 EVENTS HEADER
                          // ------------------------------------------------
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text.rich(
                                TextSpan(
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
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
                                onTap: _viewModel.loadData,
                                child: Icon(Icons.refresh,
                                    size: 18, color: primaryColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 15),

                          // ------------------------------------------------
                          // 📅 EVENTS GRID (Updated UI)
                          // ------------------------------------------------
                          if (_viewModel.isLoading)
                            Center(
                                child: CircularProgressIndicator(
                                    color: primaryColor))
                          else if (_viewModel.events.isEmpty)
                            _buildEmptyState("No Upcoming Events")
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 180,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                // 🎨 Adjusted Aspect Ratio for Taller Cards
                                childAspectRatio: 0.75,
                              ),
                              itemCount: _viewModel.events.length,
                              itemBuilder: (context, index) {
                                return _buildEventCard(
                                    context, _viewModel.events[index]);
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
      },
    );
  }

  // ------------------------------------------------
  // 🎨 MODERN PROGRAMME CARD
  // ------------------------------------------------
  Widget _buildProgrammeCard(Map<String, dynamic> prog) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final String? programmeImage = prog['image'] ?? prog['imageUrl'];
    final String title = prog['title'] ?? "Programme";
    final String code = prog['code']?.toUpperCase() ?? "PIC";

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 4)),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProgrammeDetailScreen(programme: prog),
                ),
              );
            },
            child: Stack(
              children: [
                Column(
                  children: [
                    // Image Section
                    SizedBox(
                      height: 100,
                      width: double.infinity,
                      child: _buildSafeImage(programmeImage,
                          fallbackIcon: Icons.school),
                    ),
                    // Text Section
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 14, 8, 4),
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.0,
                            color: textColor,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Floating Badge (Centered on the line)
                Positioned(
                  top: 88, 
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 2,
                              offset: Offset(0, 1))
                        ],
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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

  // ------------------------------------------------
  // 🎨 MODERN EVENT CARD (With Floating Date)
  // ------------------------------------------------
  Widget _buildEventCard(BuildContext context, Map<String, dynamic> data) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    String day = 'TBA';
    String month = '';
    String rawDate = data['date']?.toString() ?? '';
    String type = data['type'] ?? 'News';
    final String? imageUrl = data['image'] ?? data['imageUrl'];
    final String title = data['title'] ?? "Untitled Event";

    // 📅 Parse Date for Badge
    if (rawDate.isNotEmpty) {
      try {
        final dateObj = DateTime.parse(rawDate);
        day = DateFormat("d").format(dateObj);
        month = DateFormat("MMM").format(dateObj).toUpperCase();
      } catch (e) {
        // keep fallback
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 8,
                offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              final String resolvedId =
                  (data['_id'] ?? data['id'] ?? '').toString();

              final safeData = {
                ...data.map((key, value) => MapEntry(key, value.toString())),
                'rawDate': rawDate,
                'date': rawDate, 
                '_id': resolvedId,
              };

              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) =>
                        EventDetailScreen(eventData: safeData)),
              );
            },
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    SizedBox(
                      height: 110,
                      width: double.infinity,
                      child:
                          _buildSafeImage(imageUrl, fallbackIcon: Icons.event),
                    ),
                    // Content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Type Tag
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getTypeColor(type).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                type.toUpperCase(),
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: _getTypeColor(type)),
                              ),
                            ),
                            const SizedBox(height: 6),
                            // Title
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.0,
                                color: textColor,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // 📅 Floating Date Badge
                if (month.isNotEmpty)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            day,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87),
                          ),
                          Text(
                            month,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: primaryColor),
                          ),
                        ],
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
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
          ),
        ],
      ),
    );
  }
}