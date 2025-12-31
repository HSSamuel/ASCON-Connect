import 'package:flutter/material.dart';
import 'alumni_detail_screen.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:typed_data'; // Required for Base64 Images
import 'package:http/http.dart' as http;
import '../config.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  List<dynamic> allAlumni = [];      
  List<dynamic> filteredAlumni = []; 
  bool isLoading = true;             
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchAlumni();
  }

  // ✅ UPGRADED SEARCH: Now searches Organization and Job Title too!
  void _runFilter(String enteredKeyword) {
    List<dynamic> results = [];
    if (enteredKeyword.isEmpty) {
      results = allAlumni;
    } else {
      results = allAlumni
          .where((user) {
            final name = user['fullName'].toString().toLowerCase();
            final year = user['yearOfAttendance'].toString();
            final org = (user['organization'] ?? '').toString().toLowerCase();
            final job = (user['jobTitle'] ?? '').toString().toLowerCase();
            final query = enteredKeyword.toLowerCase();

            return name.contains(query) || 
                   year.contains(query) || 
                   org.contains(query) || 
                   job.contains(query);
          })
          .toList();
    }

    setState(() {
      filteredAlumni = results;
    });
  }

  Future<void> fetchAlumni() async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/directory');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          allAlumni = jsonDecode(response.body);
          filteredAlumni = allAlumni; 
          isLoading = false;
        });
      } else {
        setState(() { isLoading = false; });
      }
    } catch (error) {
      print(error);
      setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Alumni Directory"),
        backgroundColor: const Color(0xFF1B5E3A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, 
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // 1. SEARCH BAR
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _runFilter(value),
              decoration: InputDecoration(
                labelText: 'Search Name, Company, or Year', // ✅ Updated Label
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1B5E3A)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              ),
            ),
          ),

          // 2. THE LIST
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1B5E3A)))
                : filteredAlumni.isEmpty
                    ? const Center(child: Text("No alumni found."))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredAlumni.length,
                        itemBuilder: (context, index) {
                          final user = filteredAlumni[index];

                          // Helper to get subtitle text (Job @ Org OR Programme)
                          String subtitle = user['programmeTitle'] ?? 'Alumnus';
                          if (user['jobTitle'] != null && user['jobTitle'].toString().isNotEmpty) {
                            subtitle = "${user['jobTitle']} at ${user['organization'] ?? 'Unknown'}";
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
                            child: Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 15),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    // ✅ NEW: AVATAR IN LIST
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: Colors.grey[200],
                                      backgroundImage: (user['profilePicture'] != null && user['profilePicture'].toString().isNotEmpty)
                                          ? MemoryImage(base64Decode(user['profilePicture']))
                                          : null,
                                      child: (user['profilePicture'] == null || user['profilePicture'].toString().isEmpty)
                                          ? const Icon(Icons.person, color: Colors.grey)
                                          : null,
                                    ),
                                    const SizedBox(width: 15),
                                    
                                    // TEXT INFO
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user['fullName'] ?? 'Unknown',
                                            style: GoogleFonts.inter(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF1B5E3A)),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            subtitle, // ✅ Shows Job Title now
                                            style: TextStyle(color: Colors.grey[800], fontSize: 13),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Class of ${user['yearOfAttendance']}",
                                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}