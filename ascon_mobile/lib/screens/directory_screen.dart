import 'package:flutter/material.dart';
import 'alumni_detail_screen.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:async'; 
import 'package:http/http.dart' as http;
import '../config.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  List<dynamic> _alumniList = []; 
  bool _isLoading = false;            
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce; 

  @override
  void initState() {
    super.initState();
    fetchAlumni(); 
  }

  @override
  void dispose() {
    _debounce?.cancel(); 
    super.dispose();
  }

  Future<void> fetchAlumni({String query = ""}) async {
    setState(() => _isLoading = true);
    String endpoint = '${AppConfig.baseUrl}/api/directory';
    if (query.isNotEmpty) endpoint += '?search=$query';

    try {
      final response = await http.get(Uri.parse(endpoint));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _alumniList = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (error) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      fetchAlumni(query: query);
    });
  }

  ImageProvider? getProfileImage(String? imagePath) {
      if (imagePath == null || imagePath.isEmpty) return null;
      if (imagePath.startsWith('http')) {
        return NetworkImage(imagePath); 
      } else {
        try {
          return MemoryImage(base64Decode(imagePath));
        } catch (e) { return null; }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Alumni Directory",
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF1B5E3A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, 
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50], 
      body: Column(
        children: [
          // 1. COMPACT SEARCH BAR
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), // Reduced padding
            color: const Color(0xFF1B5E3A), 
            child: Container(
              height: 45, // Fixed smaller height
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  hintText: 'Search Name, Company, or Year...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF1B5E3A), size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  isDense: true,
                ),
              ),
            ),
          ),

          // 2. THE LIST
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => fetchAlumni(query: _searchController.text),
              color: const Color(0xFF1B5E3A),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E3A)))
                  : _alumniList.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(12), // Reduced list padding
                          itemCount: _alumniList.length,
                          itemBuilder: (context, index) {
                            return _buildAlumniCard(_alumniList[index]);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 50, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            "No alumni found.",
            style: GoogleFonts.inter(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAlumniCard(dynamic user) {
    String subtitle = user['programmeTitle'] ?? 'Member';
    if (user['jobTitle'] != null && user['jobTitle'].toString().isNotEmpty) {
      subtitle = "${user['jobTitle']} • ${user['organization'] ?? ''}";
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AlumniDetailScreen(alumniData: user)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12), // Reduced spacing
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0), // Reduced internal padding
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Compact Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                ),
                child: CircleAvatar(
                  radius: 24, // Reduced from 28
                  backgroundColor: Colors.grey[100],
                  backgroundImage: getProfileImage(user['profilePicture']),
                  child: getProfileImage(user['profilePicture']) == null
                      ? const Icon(Icons.person, color: Colors.grey, size: 26)
                      : null,
                ),
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
                          child: Text(
                            user['fullName'] ?? 'Unknown',
                            style: GoogleFonts.inter(
                              fontSize: 15, // Reduced from 16
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user['yearOfAttendance'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B5E3A).withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              "'${user['yearOfAttendance'].toString().substring(2)}", 
                              style: const TextStyle(
                                color: Color(0xFF1B5E3A),
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
                      style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12), // Reduced from 13
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          "View Profile",
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1B5E3A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 10, color: Color(0xFF1B5E3A)),
                      ],
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
}