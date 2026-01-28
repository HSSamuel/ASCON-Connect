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
  
  List<dynamic> _allAlumni = [];
  List<dynamic> _searchResults = [];
  Map<String, List<dynamic>> _groupedAlumni = {};
  
  bool _isLoading = false;
  bool _isSearching = false;
  
  // ✅ Mentorship Filter State
  bool _showMentorsOnly = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDirectory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDirectory({String query = ""}) async {
    setState(() => _isLoading = true);
    
    try {
      String endpoint = '/api/directory?search=$query';
      if (_showMentorsOnly) endpoint += '&mentorship=true';

      final response = await _api.get(endpoint);

      // ✅ FIX: Extract the 'data' list from the response map
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
        debugPrint("Unexpected API response format: $response");
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error loading directory: $e");
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
          final prog = (user['programmeTitle'] ?? '').toString().toLowerCase();
          
          return name.contains(lowerQuery) || 
                 org.contains(lowerQuery) || 
                 year.contains(lowerQuery) ||
                 job.contains(lowerQuery) ||
                 prog.contains(lowerQuery);
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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Alumni Directory",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // --- SEARCH & FILTER AREA ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            color: primaryColor, 
            child: Column(
              children: [
                // 1. Search Bar
                Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
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
                      prefixIcon: Icon(Icons.search,
                          color: isDark ? Colors.grey : const Color(0xFF1B5E3A), size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                      isDense: true,
                    ),
                  ),
                ),
                
                // ✅ 2. VISIBLE Mentors Filter
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text("Mentors Only"),
                        selected: _showMentorsOnly,
                        showCheckmark: false,
                        
                        // Icons
                        avatar: Icon(
                          _showMentorsOnly ? Icons.check : Icons.handshake_outlined,
                          size: 18,
                          // If selected (Gold bg), White icon. If unselected (White bg), Green icon.
                          color: _showMentorsOnly ? Colors.white : const Color(0xFF1B5E3A),
                        ),
                        
                        // Background Colors
                        backgroundColor: Colors.white, // 🟢 Default: White (Highly Visible)
                        selectedColor: const Color(0xFFD4AF37), // 🟡 Active: Gold
                        
                        // Text Style
                        labelStyle: TextStyle(
                          color: _showMentorsOnly ? Colors.white : const Color(0xFF1B5E3A),
                          fontWeight: FontWeight.bold,
                          fontSize: 13
                        ),
                        
                        // Border/Shape
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none, 
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

          // --- CONTENT AREA ---
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadDirectory(), 
              color: primaryColor,
              child: _isLoading
                  ? const DirectorySkeletonList() 
                  : _allAlumni.isEmpty
                      ? _buildEmptyState()
                      : _isSearching
                          ? _buildSearchResults()
                          : _buildGroupedList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _groupedAlumni.keys.length,
      itemBuilder: (context, index) {
        String year = _groupedAlumni.keys.elementAt(index);
        List<dynamic> classMembers = _groupedAlumni[year]!;

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
              if (!isDark) 
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2)),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : primaryColor, 
                ),
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
      },
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 50, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 10),
            const Text("No matching alumni found", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return _buildAlumniCard(_searchResults[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 50, color: Colors.grey),
          const SizedBox(height: 12),
          const Text(
            "No alumni found.",
            style: TextStyle(fontSize: 15, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
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
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => AlumniDetailScreen(alumniData: user)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 1),
                  ),
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
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: textColor, 
                                    ),
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                yearDisplay,
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF81C784) : primaryColor, 
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: subTextColor, fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            "View Profile",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF81C784) : primaryColor,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward,
                              size: 10, color: isDark ? const Color(0xFF81C784) : primaryColor),
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