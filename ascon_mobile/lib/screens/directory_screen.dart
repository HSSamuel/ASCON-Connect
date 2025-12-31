import 'package:flutter/material.dart';
import 'alumni_detail_screen.dart'; // Import the detail screen
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  List<dynamic> allAlumni = [];      // Stores the master list from DB
  List<dynamic> filteredAlumni = []; // Stores the list shown on screen (filtered)
  bool isLoading = true;             // Tracks if we are fetching data
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchAlumni();
  }

  // Function to filter the list when user types
  void _runFilter(String enteredKeyword) {
    List<dynamic> results = [];
    if (enteredKeyword.isEmpty) {
      // If search is empty, show everyone
      results = allAlumni;
    } else {
      // Check if Name OR Year matches the search query (Case Insensitive)
      results = allAlumni
          .where((user) =>
              user['fullName'].toString().toLowerCase().contains(enteredKeyword.toLowerCase()) ||
              user['yearOfAttendance'].toString().contains(enteredKeyword))
          .toList();
    }

    // Update the UI
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
          filteredAlumni = allAlumni; // Initially, show everyone
          isLoading = false;
        });
      } else {
        // Handle server errors silently
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
        backgroundColor: const Color(0xFF006400),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Removes back button
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // 1. THE SEARCH BAR
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _runFilter(value), // Filter as you type
              decoration: InputDecoration(
                labelText: 'Search by Name or Year',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF006400)),
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
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF006400)),
                        SizedBox(height: 16),
                        Text("Fetching Alumni Records..."),
                      ],
                    ),
                  )
                : filteredAlumni.isEmpty
                    ? const Center(child: Text("No alumni found."))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredAlumni.length,
                        itemBuilder: (context, index) {
                          final user = filteredAlumni[index];

                          return GestureDetector(
                            onTap: () {
                              // Navigate to Detail Screen
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
                                padding: const EdgeInsets.all(16.0),
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
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: const Color(0xFF006400)),
                                          ),
                                        ),
                                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      user['programmeTitle'] ?? 'N/A',
                                      style: TextStyle(color: Colors.grey[800]),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Class of ${user['yearOfAttendance']}",
                                      style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                                    ),
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