import 'package:flutter/material.dart';
import 'alumni_detail_screen.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:async'; // Required for Debounce
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

  // ✅ Server-Side Search Function
  Future<void> fetchAlumni({String query = ""}) async {
    setState(() => _isLoading = true);

    String endpoint = '${AppConfig.baseUrl}/api/directory';
    if (query.isNotEmpty) {
      endpoint += '?search=$query';
    }

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
      debugPrint("Directory Error: $error");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ Debounce Logic
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    _debounce = Timer(const Duration(milliseconds: 500), () {
      fetchAlumni(query: query);
    });
  }

  // Helper for Images
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
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1B5E3A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, 
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50], // Slightly off-white for contrast
      body: Column(
        children: [
          // 1. SEARCH BAR AREA
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            color: const Color(0xFF1B5E3A), // Extend Green Header
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search Name, Company, or Year...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF1B5E3A)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 15),
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
                          padding: const EdgeInsets.all(16),
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

  // --- HELPER WIDGETS ---

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "No alumni found.",
            style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            "Try adjusting your search criteria.",
            style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
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
          MaterialPageRoute(
            builder: (context) => AlumniDetailScreen(alumniData: user),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[200]!, width: 2),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[100],
                  backgroundImage: getProfileImage(user['profilePicture']),
                  child: getProfileImage(user['profilePicture']) == null
                      ? const Icon(Icons.person, color: Colors.grey, size: 30)
                      : null,
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & Badge Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            user['fullName'] ?? 'Unknown',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Class Badge
                        if (user['yearOfAttendance'] != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1B5E3A).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "'${user['yearOfAttendance'].toString().substring(2)}", // e.g., '23
                              style: const TextStyle(
                                color: Color(0xFF1B5E3A),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Job / Program
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Action Link
                    Row(
                      children: [
                        Text(
                          "View Profile",
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1B5E3A),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward, size: 12, color: Color(0xFF1B5E3A)),
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