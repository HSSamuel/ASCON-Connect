import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 

import '../services/data_service.dart';
import '../services/api_client.dart'; 
import '../widgets/skeleton_loader.dart'; 
import '../services/socket_service.dart'; 
import 'alumni_detail_screen.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient(); 
  final DataService _dataService = DataService(); 
  
  late TabController _tabController;

  // --- TAB 1: DIRECTORY STATE ---
  List<dynamic> _allAlumni = [];
  List<dynamic> _searchResults = [];
  Map<String, List<dynamic>> _groupedAlumni = {};
  
  // Recommendation State (Carousel in Tab 1)
  List<dynamic> _recommendedAlumni = [];
  bool _hasRecommendations = false;
  
  bool _isLoadingDirectory = false;
  bool _isSearching = false;
  bool _showMentorsOnly = false;
  final TextEditingController _searchController = TextEditingController();

  // --- TAB 2: SMART MATCHES STATE ---
  List<dynamic> _smartMatches = [];
  bool _isLoadingMatches = false;

  // --- TAB 3: NEAR ME STATE ---
  List<dynamic> _nearbyAlumni = [];
  bool _isLoadingNearMe = false;
  String? _currentNearMeLocation;
  final TextEditingController _cityController = TextEditingController();
  
  // Local Filter for Near Me Tab
  final TextEditingController _nearMeFilterController = TextEditingController();
  String _nearMeFilter = "";
  
  // STREAM SUBSCRIPTION (Presence System)
  StreamSubscription? _statusSubscription;
  
  // Scroll Controller for Smart Action
  final ScrollController _mainScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Load Data for all tabs
    _loadDirectory();
    _loadRecommendations(); 
    _loadSmartMatches();
    _loadNearMe(); 
    
    // Listen to Real-Time Status Stream
    _statusSubscription = SocketService().userStatusStream.listen((data) {
      if (!mounted) return;
      
      setState(() {
        final userId = data['userId'];
        final isOnline = data['isOnline'];
        final lastSeen = data['lastSeen'];
        
        // Helper to update a list in-place
        void updateList(List<dynamic> list) {
          for (var user in list) {
            if (user['_id'] == userId) {
              user['isOnline'] = isOnline;
              user['lastSeen'] = lastSeen;
            }
          }
        }

        // Update all data sources
        updateList(_allAlumni);
        updateList(_searchResults);
        updateList(_recommendedAlumni);
        updateList(_smartMatches);
        updateList(_nearbyAlumni);
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _cityController.dispose();
    _nearMeFilterController.dispose(); 
    _mainScrollController.dispose(); 
    _tabController.dispose();
    _statusSubscription?.cancel(); 
    super.dispose();
  }

  // ========================================================
  // 踏 DATA LOADING METHODS
  // ========================================================

  // --- TAB 1: DIRECTORY ---
  Future<void> _loadDirectory({String query = ""}) async {
    setState(() => _isLoadingDirectory = true);
    
    try {
      String endpoint = '/api/directory?search=$query';
      if (_showMentorsOnly) endpoint += '&mentorship=true';

      final response = await _api.get(endpoint);

      if (response['success'] == true) {
        final dynamic rawData = response['data']; 
        List<dynamic> alumniList = [];

        if (rawData is List) {
          alumniList = rawData;
        } else if (rawData is Map && rawData.containsKey('data') && rawData['data'] is List) {
          alumniList = rawData['data'];
        }

        if (mounted) {
          setState(() {
            _allAlumni = alumniList;
            _searchResults = alumniList; 
            _groupedAlumni = _groupUsersByYear(alumniList);
            _isLoadingDirectory = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingDirectory = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingDirectory = false);
    }
  }

  // --- TAB 1: RECOMMENDATIONS CAROUSEL ---
  Future<void> _loadRecommendations() async {
    final result = await _dataService.fetchRecommendations();
    if (result['success'] == true && mounted) {
      setState(() {
        _recommendedAlumni = result['matches'] ?? [];
        _hasRecommendations = _recommendedAlumni.isNotEmpty;
      });

      if (_hasRecommendations) {
        final prefs = await SharedPreferences.getInstance();
        final lastShown = prefs.getInt('last_recommendation_popup_time') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        
        // Show only if 24 hours have passed
        if (now - lastShown > 86400000) { 
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              _showSmartMatchPopup();
              prefs.setInt('last_recommendation_popup_time', now);
            }
          });
        }
      }
    }
  }

  // --- TAB 2: SMART MATCHES ---
  Future<void> _loadSmartMatches() async {
    setState(() => _isLoadingMatches = true);
    try {
      final matches = await _dataService.fetchSmartMatches();
      if (mounted) setState(() {
        _smartMatches = matches;
        _isLoadingMatches = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingMatches = false);
    }
  }

  // --- TAB 3: NEAR ME ---
  Future<void> _loadNearMe({String? city}) async {
    setState(() => _isLoadingNearMe = true);
    try {
      // ✅ FIX: Removed the redundant `fetchAlumniNearMe` call that was assigned to `headers`
      // and causing type errors because it expected metadata but got a List.
      
      _currentNearMeLocation = city; 
      
      final nearby = await _dataService.fetchAlumniNearMe(city: city);
      
      if (mounted) setState(() {
        _nearbyAlumni = nearby;
        _isLoadingNearMe = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingNearMe = false);
    }
  }

  // ========================================================
  // ｧｩ HELPER METHODS
  // ========================================================

  Map<String, List<dynamic>> _groupUsersByYear(List<dynamic> users) {
    Map<String, List<dynamic>> groups = {};
    for (var user in users) {
      String year = user['yearOfAttendance']?.toString() ?? 'Others';
      if (!groups.containsKey(year)) {
        groups[year] = [];
      }
      groups[year]!.add(user);
    }
    var sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    Map<String, List<dynamic>> sortedGroups = {};
    for (var key in sortedKeys) {
      sortedGroups[key] = groups[key]!;
    }
    return sortedGroups;
  }

  void _onSearchChanged(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      
      if (query.isEmpty) {
        _searchResults = _allAlumni;
      } else {
        final lowerQuery = query.toLowerCase();
        _searchResults = _allAlumni.where((user) {
          final name = (user['fullName'] ?? '').toString().toLowerCase();
          final org = (user['organization'] ?? '').toString().toLowerCase();
          final year = (user['yearOfAttendance'] ?? '').toString().toLowerCase();
          final job = (user['jobTitle'] ?? '').toString().toLowerCase();
          
          return name.contains(lowerQuery) || 
                 org.contains(lowerQuery) || 
                 year.contains(lowerQuery) ||
                 job.contains(lowerQuery);
        }).toList();
      }
    });
  }

  // ========================================================
  // 耳 WIDGETS
  // ========================================================

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Alumni Directory", 
          style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 18)
        ),
        automaticallyImplyLeading: false,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4AF37), // Gold
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: GoogleFonts.lato(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "All"),
            Tab(text: "Smart Match"),
            Tab(text: "Near Me"),
          ],
        ),
      ),
      backgroundColor: bgColor,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDirectoryTab(),
          _buildSmartMatchesTab(),
          _buildNearMeTab(),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // TAB 1: DIRECTORY (Existing Functionality)
  // ----------------------------------------------------------------
  Widget _buildDirectoryTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      children: [
        // --- 1. SEARCH & FILTER ---
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: Theme.of(context).cardColor, 
          child: Column(
            children: [
              Container(
                height: 45,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color), 
                  decoration: InputDecoration(
                    hintText: 'Search Name, Company, or Year...',
                    hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13),
                    prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey : primaryColor, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    isDense: true,
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text("Mentors Only"),
                      selected: _showMentorsOnly,
                      showCheckmark: false,
                      avatar: Icon(
                        _showMentorsOnly ? Icons.check : Icons.handshake_outlined,
                        size: 18,
                        color: _showMentorsOnly ? Colors.white : primaryColor,
                      ),
                      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                      selectedColor: const Color(0xFFD4AF37),
                      labelStyle: GoogleFonts.lato(
                        color: _showMentorsOnly ? Colors.white : primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isDark ? Colors.transparent : Colors.grey[300]!), 
                      ),
                      onSelected: (bool selected) {
                        setState(() {
                          _showMentorsOnly = selected;
                          _loadDirectory(query: _searchController.text);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // --- 2. MAIN LIST ---
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _loadDirectory();
              await _loadRecommendations();
            }, 
            color: primaryColor,
            child: SingleChildScrollView(
              controller: _mainScrollController, 
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // A. RECOMMENDATION SECTION
                  if (_hasRecommendations && !_isSearching)
                    _buildRecommendationsSection(),

                  // B. STANDARD LIST
                  if (_isLoadingDirectory)
                    const DirectorySkeletonList() 
                  else if (_allAlumni.isEmpty)
                    _buildEmptyState()
                  else if (_isSearching)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) => _buildAlumniCard(_searchResults[index]),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(12),
                      itemCount: _groupedAlumni.keys.length,
                      itemBuilder: (context, index) {
                        String year = _groupedAlumni.keys.elementAt(index);
                        List<dynamic> classMembers = _groupedAlumni[year]!;
                        return _buildGroupedTile(year, classMembers);
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------
  // TAB 2: SMART MATCHES (New Feature)
  // ----------------------------------------------------------------
  Widget _buildSmartMatchesTab() {
    final primaryColor = Theme.of(context).primaryColor;

    return RefreshIndicator(
      onRefresh: _loadSmartMatches,
      color: primaryColor,
      child: _isLoadingMatches
          ? const Center(child: CircularProgressIndicator())
          : _smartMatches.isEmpty
              ? _buildEmptyState("No matches found.\nUpdate your Industry & Skills in Profile.")
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _smartMatches.length,
                  itemBuilder: (context, index) {
                    final user = _smartMatches[index];
                    final score = user['matchScore'] ?? 0;
                    return Column(
                      children: [
                        _buildAlumniCard(user, badgeText: "$score% Match"),
                      ],
                    );
                  },
                ),
    );
  }

  // ----------------------------------------------------------------
  // TAB 3: NEAR ME (New Feature)
  // ----------------------------------------------------------------
  Widget _buildNearMeTab() {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Apply Local Filter logic
    final filteredList = _nearbyAlumni.where((user) {
      if (_nearMeFilter.isEmpty) return true;
      final name = (user['fullName'] ?? '').toLowerCase();
      final job = (user['jobTitle'] ?? '').toLowerCase();
      return name.contains(_nearMeFilter.toLowerCase()) || job.contains(_nearMeFilter.toLowerCase());
    }).toList();

    // Determine what text to show in the header
    String locationText = "Finding alumni near you...";
    if (_currentNearMeLocation != null && _currentNearMeLocation!.isNotEmpty) {
      locationText = "Showing alumni in ${_currentNearMeLocation!}";
    } else if (_nearbyAlumni.isNotEmpty) {
      final firstUserCity = _nearbyAlumni[0]['city'] ?? _nearbyAlumni[0]['state'] ?? "your area";
      locationText = "Found alumni in $firstUserCity";
    }

    return Column(
      children: [
        // 1. City Input (Fetches from Server)
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _cityController,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  labelText: "Travel Mode: Enter City",
                  hintText: "e.g. Abuja, Lagos, London",
                  labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                  prefixIcon: Icon(Icons.flight_takeoff, color: primaryColor),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: () => _loadNearMe(city: _cityController.text.trim()),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                ),
                onSubmitted: (val) => _loadNearMe(city: val),
              ),
              if (_nearbyAlumni.isNotEmpty || _currentNearMeLocation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 4),
                  child: Text(
                    locationText,
                    style: GoogleFonts.lato(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),

        // 2. Local Name Filter (Only visible if results exist)
        if (_nearbyAlumni.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _nearMeFilterController,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                labelText: "Filter by Name or Job",
                prefixIcon: Icon(Icons.person_search, color: Colors.grey[600]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              ),
              onChanged: (val) => setState(() => _nearMeFilter = val),
            ),
          ),

        // 3. Filtered List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadNearMe(city: _cityController.text),
            color: primaryColor,
            child: _isLoadingNearMe
                ? const Center(child: CircularProgressIndicator())
                : filteredList.isEmpty
                    ? _buildEmptyState("No alumni found nearby.\nTry entering a major city like 'Lagos'.")
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) => _buildAlumniCard(filteredList[index]),
                      ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------
  // 耳 COMMON WIDGETS
  // ---------------------------------------------------------

  void _showSmartMatchPopup() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: 350,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFD4AF37), size: 28),
                const SizedBox(width: 10),
                Text(
                  "We found your classmates!", 
                  style: GoogleFonts.lato(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: textColor
                  )
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Based on your profile, here are alumni from your Class Year and Programme. Connect with them now!",
              style: GoogleFonts.lato(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 14
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _recommendedAlumni.length,
                itemBuilder: (context, index) {
                  final user = _recommendedAlumni[index];
                  return Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        _buildAvatar(user['profilePicture'], isDark),
                        const SizedBox(height: 8),
                        Text(
                          user['fullName'].toString().split(' ')[0], 
                          style: GoogleFonts.lato(
                            fontWeight: FontWeight.bold,
                            color: textColor
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user['jobTitle'] ?? 'Alumni',
                          style: GoogleFonts.lato(
                            fontSize: 10, 
                            color: isDark ? Colors.grey[400] : Colors.grey
                          ),
                          overflow: TextOverflow.ellipsis,
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Go to recommendations
                  if (_mainScrollController.hasClients) {
                    _mainScrollController.animateTo(
                      0, 
                      duration: const Duration(milliseconds: 500), 
                      curve: Curves.easeOut
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Start Connecting"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationsSection() {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    
    return Container(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars, color: Colors.amber[700], size: 20),
              const SizedBox(width: 8),
              Text(
                "Suggested for You",
                style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120, 
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendedAlumni.length,
              itemBuilder: (context, index) {
                final user = _recommendedAlumni[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniData: user))
                    );
                  },
                  child: Container(
                    width: 80, 
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.amber[700]!, width: 2), 
                          ),
                          child: SizedBox(
                            width: 60, height: 60,
                            child: _buildAvatar(user['profilePicture'], isDark), 
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user['fullName'].toString().split(' ')[0], 
                          style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 12, color: textColor),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Class of ${user['yearOfAttendance']}",
                          style: GoogleFonts.lato(fontSize: 10, color: primaryColor, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 30),
        ],
      ),
    );
  }

  Widget _buildGroupedTile(String year, List<dynamic> classMembers) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final primaryColor = Theme.of(context).primaryColor;
    final borderColor = Theme.of(context).dividerColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.school, color: primaryColor, size: 20),
          ),
          title: Text(
            year == 'Others' ? "Other Alumni" : "Class of $year",
            style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : primaryColor),
          ),
          subtitle: Text(
            "${classMembers.length} ${classMembers.length == 1 ? 'Member' : 'Members'}",
            style: GoogleFonts.lato(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          children: classMembers.map((user) => _buildAlumniCard(user)).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState([String message = "No alumni found."]) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 50),
          const Icon(Icons.people_outline, size: 50, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAlumniCard(dynamic user, {String? badgeText}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final borderColor = Theme.of(context).dividerColor;
    final primaryColor = Theme.of(context).primaryColor;

    final bool isMentor = user['isOpenToMentorship'] == true;
    final bool isOnline = user['isOnline'] == true;

    String subtitle = "Alumnus"; 
    if (user['jobTitle'] != null && user['jobTitle'].toString().isNotEmpty) {
      subtitle = "${user['jobTitle']} ${user['organization'] != null ? '窶｢ ${user['organization']}' : ''}";
    } else if (user['programmeTitle'] != null && user['programmeTitle'].toString().isNotEmpty) {
      subtitle = user['programmeTitle'];
    }
    
    String yearDisplay = "";
    if (user['yearOfAttendance'] != null) {
        String yStr = user['yearOfAttendance'].toString();
        yearDisplay = yStr.length >= 2 ? "'${yStr.substring(2)}" : yStr;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8, top: 4),
      decoration: BoxDecoration(
        color: cardColor, 
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (context) => AlumniDetailScreen(alumniData: user))
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: 1)),
                      child: _buildAvatar(user['profilePicture'], isDark),
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14, height: 14,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: cardColor, width: 2),
                          ),
                        ),
                      )
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    user['fullName'] ?? 'Unknown',
                                    style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMentor) 
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4.0),
                                    child: Icon(Icons.stars_rounded, color: Colors.amber[700], size: 16),
                                  ),
                              ],
                            ),
                          ),
                          if (badgeText != null)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                badgeText,
                                style: GoogleFonts.lato(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10),
                              ),
                            )
                          else if (yearDisplay.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                yearDisplay,
                                style: GoogleFonts.lato(color: isDark ? const Color(0xFF81C784) : primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: GoogleFonts.lato(color: subTextColor, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text("View Profile", style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF81C784) : primaryColor)),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 10, color: isDark ? const Color(0xFF81C784) : primaryColor),
                        ],
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

  Widget _buildAvatar(String? imagePath, bool isDark) {
    if (imagePath == null || imagePath.isEmpty || imagePath.contains('profile/picture/0')) { 
      return _buildPlaceholder(isDark);
    }

    if (imagePath.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imagePath,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 24,
          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => _buildPlaceholder(isDark),
        errorWidget: (context, url, error) => _buildPlaceholder(isDark),
      );
    }

    try {
      return CircleAvatar(
        radius: 24,
        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
        backgroundImage: MemoryImage(base64Decode(imagePath)),
      );
    } catch (e) {
      return _buildPlaceholder(isDark);
    }
  }

  Widget _buildPlaceholder(bool isDark) {
    return CircleAvatar(
      radius: 24,
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
      child: const Icon(Icons.person, color: Colors.grey, size: 26),
    );
  }
}