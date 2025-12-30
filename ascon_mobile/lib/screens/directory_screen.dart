import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  List<dynamic> allAlumni = []; // Stores EVERYONE
  List<dynamic> filteredAlumni = []; // Stores only what matches search
  bool isLoading = true;
  TextEditingController _searchController = TextEditingController();

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
      // Check if Name OR Year matches the search
      results = allAlumni
          .where((user) =>
              user['fullName'].toLowerCase().contains(enteredKeyword.toLowerCase()) ||
              user['yearOfAttendance'].toString().contains(enteredKeyword))
          .toList();
    }

    // Update the UI
    setState(() {
      filteredAlumni = results;
    });
  }

  Future<void> fetchAlumni() async {
    final url = Uri.parse('http://localhost:5000/api/directory');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          allAlumni = jsonDecode(response.body);
          filteredAlumni = allAlumni; // Initially, show everyone
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
        title: Text("Alumni Directory"),
        backgroundColor: Color(0xFF006400),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // 1. THE SEARCH BAR
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _runFilter(value), // Filter as you type
              decoration: InputDecoration(
                labelText: 'Search by Name or Year',
                prefixIcon: Icon(Icons.search, color: Color(0xFF006400)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
              ),
            ),
          ),

          // 2. THE LIST
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: Color(0xFF006400)))
                : filteredAlumni.isEmpty
                    ? Center(child: Text("No alumni found."))
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: filteredAlumni.length,
                        itemBuilder: (context, index) {
                          final user = filteredAlumni[index];
                          return Card(
                            elevation: 2,
                            margin: EdgeInsets.only(bottom: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    user['fullName'] ?? 'Unknown',
                                    style: GoogleFonts.inter(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF006400)),
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    user['programmeTitle'] ?? 'N/A',
                                    style: TextStyle(color: Colors.grey[800]),
                                  ),
                                  Text(
                                    "Class of ${user['yearOfAttendance']}",
                                    style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic),
                                  ),
                                ],
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