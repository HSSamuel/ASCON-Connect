import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart'; 
import '../services/data_service.dart';
import '../services/api_client.dart'; 
import '../widgets/skeleton_loader.dart'; 
import 'alumni_detail_screen.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final ApiClient _api = ApiClient(); 
  final DataService _dataService = DataService(); 
  
  List<dynamic> _allAlumni = [];
  List<dynamic> _searchResults = [];
  Map<String, List<dynamic>> _groupedAlumni = {};
  
  // Recommendation State
  List<dynamic> _recommendedAlumni = [];
  bool _hasRecommendations = false;
  
  bool _isLoading = false;
  bool _isSearching = false;
  bool _showMentorsOnly = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDirectory();
    _loadRecommendations(); 
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecommendations() async {
    final result = await _dataService.fetchRecommendations();
    if (result['success'] == true && mounted) {
      setState(() {
        _recommendedAlumni = result['matches'] ?? [];
        _hasRecommendations = _recommendedAlumni.isNotEmpty;
      });

      // Show pop-up if matches found
      if (_hasRecommendations) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _showSmartMatchPopup();
        });
      }
    }
  }

  // ✅ UPDATED: Now supports Dark Mode
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
          color: backgroundColor, // ✅ Uses Theme Card Color
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
                  style: TextStyle(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold, 
                    color: textColor // ✅ Adaptive Text Color
                  )
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Based on your profile, here are alumni from your Class Year and Programme. Connect with them now!",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600], // ✅ Adaptive Grey
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
                        _buildAvatar(user['profilePicture'], isDark), // ✅ Pass isDark
                        const SizedBox(height: 8),
                        Text(
                          user['fullName'].toString().split(' ')[0], 
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor // ✅ Adaptive Name Color
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user['jobTitle'] ?? 'Alumni',
                          style: TextStyle(
                            fontSize: 10, 
                            color: isDark ? Colors.grey[400] : Colors.grey // ✅ Adaptive Subtext
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
                onPressed: () => Navigator.pop(context),
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

  Future<void> _loadDirectory({String query = ""}) async {
    setState(() => _isLoading = true);
    
    try {
      String endpoint = '/api/directory?search=$query';
      if (_showMentorsOnly) endpoint += '&mentorship=true';

      final response = await _api.get(endpoint);

      if (response['success'] == true && response['data'] is List) {
        final List<dynamic> data = response['data'];

        if (mounted) {
          setState(() {
            _allAlumni = data;
            _searchResults = data; 
            _groupedAlumni = _groupUsersByYear(data);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Alumni Directory", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        automaticallyImplyLeading: false,
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
      ),
      backgroundColor: bgColor,
      body: Column(
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
                        labelStyle: TextStyle(
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
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // ✅ A. RECOMMENDATION SECTION (Top of List)
                    if (_hasRecommendations && !_isSearching)
                      _buildRecommendationsSection(),

                    // ✅ B. STANDARD DIRECTORY LIST
                    if (_isLoading)
                      const DirectorySkeletonList() 
                    else if (_allAlumni.isEmpty)
                      _buildEmptyState()
                    else if (_isSearching)
                      // Important: shrinkWrap + physics prevents crash
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
      ),
    );
  }

  // ✅ WIDGET: Recommender Carousel (UPDATED: Circles instead of Squares)
  Widget _buildRecommendationsSection() {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.stars, color: Colors.amber[700], size: 20),
              const SizedBox(width: 8),
              const Text(
                "Suggested for You",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120, // Height for circle layout
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _recommendedAlumni.length,
              itemBuilder: (context, index) {
                final user = _recommendedAlumni[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniData: user)));
                  },
                  child: Container(
                    width: 80, // Narrower for circle layout
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        // ✅ CIRCLE AVATAR with Gold Border
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.amber[700]!, width: 2), 
                          ),
                          child: SizedBox(
                            width: 60, height: 60,
                            child: _buildAvatar(user['profilePicture'], isDark), // ✅ Pass isDark
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user['fullName'].toString().split(' ')[0], 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Class of ${user['yearOfAttendance']}",
                          style: TextStyle(fontSize: 10, color: primaryColor, fontWeight: FontWeight.w600),
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
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : primaryColor),
          ),
          subtitle: Text(
            "${classMembers.length} ${classMembers.length == 1 ? 'Member' : 'Members'}",
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          children: classMembers.map((user) => _buildAlumniCard(user)).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          SizedBox(height: 50),
          Icon(Icons.people_outline, size: 50, color: Colors.grey),
          SizedBox(height: 12),
          Text("No alumni found.", style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAlumniCard(dynamic user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;
    final borderColor = Theme.of(context).dividerColor;
    final primaryColor = Theme.of(context).primaryColor;

    final bool isMentor = user['isOpenToMentorship'] == true;

    String subtitle = user['programmeTitle'] ?? 'Member';
    if (user['jobTitle'] != null && user['jobTitle'].toString().isNotEmpty) {
      subtitle = "${user['jobTitle']} • ${user['organization'] ?? ''}";
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
            Navigator.push(context, MaterialPageRoute(builder: (context) => AlumniDetailScreen(alumniData: user)));
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: borderColor, width: 1)),
                  child: _buildAvatar(user['profilePicture'], isDark),
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
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
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
                          if (yearDisplay.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                              child: Text(
                                yearDisplay,
                                style: TextStyle(color: isDark ? const Color(0xFF81C784) : primaryColor, fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: TextStyle(color: subTextColor, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text("View Profile", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF81C784) : primaryColor)),
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
}