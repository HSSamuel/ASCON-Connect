import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart'; // ✅ For Date Formatting

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../config.dart';
import 'event_detail_screen.dart'; // Ensure you have this or generic detail screen

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final DataService _dataService = DataService();
  final AuthService _authService = AuthService();
  final ApiClient _api = ApiClient();

  List<dynamic> _events = [];
  List<dynamic> _filteredEvents = [];
  bool _isLoading = true;
  bool _isAdmin = false;

  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadEvents();
  }

  Future<void> _checkPermissions() async {
    final adminStatus = await _authService.isAdmin;
    if (mounted) {
      setState(() => _isAdmin = adminStatus);
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      // Assuming fetchEvents returns a List of maps
      final events = await _dataService.fetchEvents();
      if (mounted) {
        setState(() {
          _events = events;
          _filteredEvents = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _filteredEvents = _events;
      } else {
        _filteredEvents = _events.where((e) {
          final title = (e['title'] ?? '').toString().toLowerCase();
          final desc = (e['description'] ?? '').toString().toLowerCase();
          return title.contains(query.toLowerCase()) || desc.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _deleteEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Event"),
        content: const Text("Are you sure you want to delete this event?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _api.delete('/api/admin/events/$eventId');
        await _loadEvents();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event deleted.")));
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete event.")));
        }
      }
    }
  }

  // =========================================================
  // 🗓️ ADD EVENT SHEET (With Image Upload)
  // =========================================================
  void _showAddEventSheet() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final locationController = TextEditingController();
    
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    String selectedType = "News";
    XFile? selectedImage; 
    bool isSubmitting = false;

    // Allowed Event Types
    final List<String> eventTypes = [
      "News", "Event", "Reunion", "Webinar", "Seminar", 
      "Conference", "Workshop", "Symposium", "AGM", "Induction"
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            
            Future<void> pickImage() async {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
              if (picked != null) setSheetState(() => selectedImage = picked);
            }

            Future<void> pickDate() async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2030),
              );
              if (picked != null) setSheetState(() => selectedDate = picked);
            }

            Future<void> pickTime() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.now(),
              );
              if (picked != null) setSheetState(() => selectedTime = picked);
            }

            Future<void> submit() async {
              if (titleController.text.isEmpty || descController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Title and Description are required.")));
                return;
              }
              
              setSheetState(() => isSubmitting = true);
              try {
                final token = await AuthService().getToken();
                var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/api/admin/events'));
                request.headers['auth-token'] = token ?? '';
                
                request.fields['title'] = titleController.text.trim();
                request.fields['description'] = descController.text.trim();
                request.fields['type'] = selectedType;
                
                if (locationController.text.isNotEmpty) request.fields['location'] = locationController.text.trim();
                if (selectedDate != null) request.fields['date'] = selectedDate!.toIso8601String();
                if (selectedTime != null) request.fields['time'] = selectedTime!.format(context);

                if (selectedImage != null) {
                   if (kIsWeb) {
                     var bytes = await selectedImage!.readAsBytes();
                     request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: selectedImage!.name));
                   } else {
                     request.files.add(await http.MultipartFile.fromPath('image', selectedImage!.path));
                   }
                }

                var response = await request.send();
                
                if (response.statusCode == 201) {
                  Navigator.pop(sheetCtx);
                  _loadEvents(); // Refresh list
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Event Created!"), backgroundColor: Colors.green));
                } else {
                   // Try to parse error
                   final respStr = await response.stream.bytesToString();
                   String err = "Failed to create event";
                   try { err = jsonDecode(respStr)['message']; } catch (_) {}
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              } finally {
                if (mounted) setSheetState(() => isSubmitting = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Create New Event", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title (Required)", border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(controller: descController, maxLines: 3, decoration: const InputDecoration(labelText: "Description (Required)", border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: "Type", border: OutlineInputBorder()),
                      items: eventTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setSheetState(() => selectedType = val!),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: pickDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: "Date", border: OutlineInputBorder()),
                              child: Text(selectedDate == null ? "Select Date" : DateFormat('MMM dd, yyyy').format(selectedDate!)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: pickTime,
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: "Time", border: OutlineInputBorder()),
                              child: Text(selectedTime == null ? "Select Time" : selectedTime!.format(context)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: locationController, decoration: const InputDecoration(labelText: "Location (Optional)", border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    
                    // Image Picker
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        width: double.infinity, height: 150,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[400]!), image: selectedImage != null ? DecorationImage(image: kIsWeb ? NetworkImage(selectedImage!.path) : FileImage(File(selectedImage!.path)) as ImageProvider, fit: BoxFit.cover) : null),
                        child: selectedImage == null ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey), Text("Add Cover Image")])) : null,
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: isSubmitting ? null : submit, style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)), child: const Text("Publish Event"))),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("Events & News", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go('/home')),
        ),
        floatingActionButton: _isAdmin 
          ? FloatingActionButton.extended(
              onPressed: _showAddEventSheet, // ✅ Opens the Add Event Sheet
              label: const Text("Add Event", style: TextStyle(fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.add),
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.white,
            )
          : null,
        body: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: "Search events...",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ),
            
            // List
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredEvents.isEmpty
                  ? Center(child: Text("No events found.", style: GoogleFonts.lato(color: Colors.grey)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredEvents.length,
                      itemBuilder: (context, index) {
                        return _buildEventCard(_filteredEvents[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(dynamic event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    
    // Parse Date
    String dateStr = "TBA";
    if (event['date'] != null) {
      try {
        final d = DateTime.parse(event['date']);
        dateStr = DateFormat('MMM dd, yyyy').format(d);
      } catch (e) {
        dateStr = event['date'].toString(); // Fallback if string
      }
    }

    final imageUrl = event['image'];
    final bool hasImage = imageUrl != null && imageUrl.toString().isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      color: cardColor,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Navigate to detail screen if you have one
          Navigator.push(context, MaterialPageRoute(builder: (_) => EventDetailScreen(eventData: event)));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Banner
            if (hasImage)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[300], height: 150),
                  errorWidget: (context, url, error) => Container(color: Colors.grey[300], height: 150, child: const Icon(Icons.broken_image)),
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
                        decoration: BoxDecoration(color: const Color(0xFFD4AF37).withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                        child: Text(event['type'] ?? 'Event', style: GoogleFonts.lato(color: const Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                      if (_isAdmin)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                          onPressed: () => _deleteEvent(event['_id']),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(event['title'] ?? 'No Title', style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(dateStr, style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[600])),
                      const SizedBox(width: 16),
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(event['time'] ?? 'TBA', style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                  if (event['location'] != null && event['location'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(child: Text(event['location'], style: GoogleFonts.lato(fontSize: 13, color: Colors.grey[600]), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}