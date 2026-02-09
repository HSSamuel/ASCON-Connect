import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart'; 
import '../widgets/shimmer_utils.dart'; 
import 'alumni_detail_screen.dart';
import 'chat_screen.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  final DataService _dataService = DataService();
  final AuthService _authService = AuthService();
  final ApiClient _api = ApiClient(); 
  
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allAlumni = [];
  Map<String, List<dynamic>> _groupedAlumni = {};
  List<String> _sortedYears = [];
  
  // Tracks expanded folders
  final Set<String> _expandedSections = {}; 
  
  bool _isLoading = true;
  String _currentFilter = "All";
  String? _myUserId;
  String? _myYear;

  final List<String> _filters = ["All", "Mentors", "Classmates", "Near Me"];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      _myUserId = await _authService.currentUserId;
      final res = await _api.get('/api/auth/me'); 
      if (res['success'] == true) {
        final me = res['data'];
        _myYear = me['yearOfAttendance']?.toString();
      }
    } catch (e) {
      debugPrint("Error fetching my profile: $e");
    }

    try {
      final alumni = await _dataService.fetchDirectory();
      
      if (mounted) {
        setState(() {
          _allAlumni = alumni;
          _applyFilters(); 
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ UPDATED LOGIC: Auto-Expand ONLY on Search
  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    
    final filteredList = _allAlumni.where((user) {
      final name = (user['fullName'] ?? "").toString().toLowerCase();
      final job = (user['jobTitle'] ?? "").toString().toLowerCase();
      final company = (user['organization'] ?? "").toString().toLowerCase();
      final matchesSearch = name.contains(query) || job.contains(query) || company.contains(query);

      if (!matchesSearch) return false;

      if (_currentFilter == "All") return true;
      if (_currentFilter == "Mentors") return user['isOpenToMentorship'] == true;
      if (_currentFilter == "Classmates") return _myYear != null && user['yearOfAttendance']?.toString() == _myYear;
      if (_currentFilter == "Near Me") return true; 

      return true;
    }).toList();

    final Map<String, List<dynamic>> groups = {};
    for (var user in filteredList) {
      String year = user['yearOfAttendance']?.toString() ?? "Unknown";
      if (!groups.containsKey(year)) {
        groups[year] = [];
      }
      groups[year]!.add(user);
    }

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == "Unknown") return 1;
        if (b == "Unknown") return -1;
        return b.compareTo(a); 
      });

    setState(() {
      _groupedAlumni = groups;
      _sortedYears = sortedKeys;
      
      // ✅ LOGIC UPDATE:
      if (query.isNotEmpty) {
        // 1. Search Active? -> Expand ALL matching folders
        _expandedSections.addAll(sortedKeys);
      } else {
        // 2. Search Cleared? -> Collapse ALL folders (Default state)
        _expandedSections.clear();
      }
    });
  }

  void _toggleSection(String year) {
    setState(() {
      if (_expandedSections.contains(year)) {
        _expandedSections.remove(year);
      } else {
        _expandedSections.add(year);
      }
    });
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
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Directory", style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (val) => _applyFilters(), // Triggers expansion logic
                    decoration: InputDecoration(
                      hintText: "Search name, role...",
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      // Clear button to reset state easily
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters(); // Collapses everything
                            },
                          )
                        : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((filter) {
                        final isSelected = _currentFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(filter),
                            selected: isSelected,
                            selectedColor: primaryColor.withOpacity(0.15),
                            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                            side: BorderSide.none,
                            labelStyle: TextStyle(
                              color: isSelected ? primaryColor : Colors.grey[600],
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 13
                            ),
                            onSelected: (val) {
                              setState(() {
                                _currentFilter = filter;
                                _applyFilters();
                              });
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // 2. EXPANDABLE LIST
            Expanded(
              child: _isLoading 
                ? const DirectorySkeleton()
                : _sortedYears.isEmpty 
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 40),
                        itemCount: _sortedYears.length,
                        itemBuilder: (context, index) {
                          final year = _sortedYears[index];
                          final users = _groupedAlumni[year] ?? [];
                          final isExpanded = _expandedSections.contains(year);
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Clickable Header
                              _buildYearHeader(year, users.length, primaryColor, isDark, isExpanded),
                              
                              // Content only shows if expanded
                              if (isExpanded)
                                ...users.map((user) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: _buildAlumniCard(user),
                                )),
                            ],
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ ANIMATED HEADER: Arrow rotates based on state
  Widget _buildYearHeader(String year, int count, Color color, bool isDark, bool isExpanded) {
    return InkWell(
      onTap: () => _toggleSection(year),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), 
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        color: isDark ? Colors.grey[900] : Colors.grey[100], 
        child: Row(
          children: [
            // ✅ ANIMATED ARROW: Points Right (0.0) if collapsed, Down (0.25) if expanded
            AnimatedRotation(
              turns: isExpanded ? 0.25 : 0.0, 
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            
            // Folder Icon changes too
            Icon(isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded, color: color, size: 22),
            const SizedBox(width: 12),
            
            Text(
              "Class of $year", 
              style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)
            ),
            const Spacer(),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text("$count", style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildAlumniCard(Map<String, dynamic> user) {
    final String name = user['fullName'] ?? "Alumnus";
    final String job = user['jobTitle'] ?? "";
    final String org = user['organization'] ?? "";
    final String img = user['profilePicture'] ?? "";
    final bool isMentor = user['isOpenToMentorship'] == true;
    final String userId = user['userId'] ?? user['_id'];
    
    if (userId == _myUserId) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniData: user))
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: (img.isNotEmpty && img.startsWith('http')) 
                      ? CachedNetworkImageProvider(img) 
                      : null,
                  child: img.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
                if (isMentor)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.amber[700], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                      child: const Icon(Icons.star, color: Colors.white, size: 10),
                    ),
                  )
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 2),
                  if (job.isNotEmpty || org.isNotEmpty)
                    Text(
                      "$job${(job.isNotEmpty && org.isNotEmpty) ? ' at ' : ''}$org",
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[600]),
                    )
                  else 
                    Text("Alumni Member", style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[400], fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.chat_bubble_outline_rounded, color: primaryColor),
              onPressed: () {
                Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(builder: (_) => ChatScreen(
                    receiverId: userId,
                    receiverName: name,
                    receiverProfilePic: img,
                    isOnline: false, 
                  ))
                );
              },
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("No alumni found.", style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[500])),
        ],
      ),
    );
  }
}