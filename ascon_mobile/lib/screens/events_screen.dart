import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; 
import '../config.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<dynamic> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchEvents();
  }

  Future<void> fetchEvents() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/events');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _events = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print(e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("News & Events"),
        backgroundColor: const Color(0xFF1B5E3A),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.grey[100],
      
      // ✅ Floating Button REMOVED. Only Admins can post from Web Portal now.

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? const Center(child: Text("No upcoming events."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    
                    // Simple Date Formatting
                    // We try-catch the date parsing just in case
                    String dateString = "TBD";
                    try {
                      final date = DateTime.parse(event['date']);
                      dateString = "${date.day}/${date.month}/${date.year}";
                    } catch (e) {
                      dateString = "Unknown Date";
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Colored Header strip
                          Container(
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1B5E3A),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12)
                              ),
                            ),
                          ),
                          
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(4)
                                      ),
                                      child: Text(
                                        event['type'] ?? 'News',
                                        style: const TextStyle(color: Color(0xFF1B5E3A), fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                    ),
                                    Text(
                                      dateString,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  event['title'] ?? 'No Title',
                                  style: GoogleFonts.inter(
                                    fontSize: 18, 
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      event['location'] ?? 'No Location',
                                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  event['description'] ?? '',
                                  style: TextStyle(color: Colors.grey[800], height: 1.4),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}