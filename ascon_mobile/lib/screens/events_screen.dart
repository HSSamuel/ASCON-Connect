import 'dart:convert'; 
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart'; 
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../services/data_service.dart'; 
import '../services/api_client.dart'; 
import '../services/auth_service.dart';
import '../widgets/skeleton_loader.dart'; 
import '../config.dart';
import 'event_detail_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final DataService _dataService = DataService(); 
  final ApiClient _api = ApiClient();
  final AuthService _authService = AuthService();
  
  List<dynamic> _events = [];
  bool _isLoading = true;
  bool _isAdmin = false; 

  @override
  void initState() {
    super.initState();
    _checkAdmin();
    _loadEvents();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await _authService.isAdmin;
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  Future<void> _loadEvents() async {
    final events = await _dataService.fetchEvents();
    if (mounted) {
      setState(() {
        _events = events;
        _isLoading = false;
      });
    }
  }

  // =========================================================
  // 🗑️ DELETE EVENT
  // =========================================================
  Future<void> _deleteEvent(String eventId) async {
    final confirm = await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Event"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete")
          ),
        ],
      )
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _api.delete('/api/events/$eventId');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event deleted.")));
          _loadEvents(); 
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete event.")));
        }
      }
    }
  }

  // =========================================================
  // ➕ CREATE EVENT SHEET (Admin Only)
  // =========================================================
  void _showCreateEventSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final locCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    XFile? selectedImage;
    bool isPosting = false;
    String selectedType = "Event";

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
              final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
              if (pickedFile != null) setSheetState(() => selectedImage = pickedFile);
            }

            Future<void> submit() async {
              if (titleCtrl.text.isEmpty || descCtrl.text.isEmpty) return;
              setSheetState(() => isPosting = true);

              try {
                final token = await AuthService().getToken();
                var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/api/admin/events')); // Using existing endpoint
                // Note: If using /api/events endpoint, adjust accordingly. 
                // The backend route in server.js points to /api/events, but typically POST is restricted.
                // Assuming route is /api/events based on backend/routes/events.js which has router.post('/', verifyToken, verifyAdmin...)
                
                request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/api/events'));
                request.headers['auth-token'] = token ?? '';
                
                request.fields['title'] = titleCtrl.text;
                request.fields['description'] = descCtrl.text;
                request.fields['location'] = locCtrl.text;
                request.fields['time'] = timeCtrl.text;
                request.fields['type'] = selectedType;
                request.fields['date'] = DateTime.now().toIso8601String(); // Default to now for simplicity

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
                  _loadEvents();
                  if (mounted) ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Event Created!")));
                }
              } catch (e) {
                // error
              } finally {
                setSheetState(() => isPosting = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Create Event", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title", border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(controller: descCtrl, maxLines: 2, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(controller: locCtrl, decoration: const InputDecoration(labelText: "Location", border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(controller: timeCtrl, decoration: const InputDecoration(labelText: "Time (e.g. 10:00 AM)", border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      items: ["Event", "News", "Reunion", "Webinar", "Workshop"].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setSheetState(() => selectedType = val!),
                      decoration: const InputDecoration(labelText: "Type", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: const Icon(Icons.image),
                      title: Text(selectedImage == null ? "Select Image" : "Image Selected"),
                      trailing: selectedImage != null ? const Icon(Icons.check, color: Colors.green) : null,
                      onTap: pickImage,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isPosting ? null : submit,
                        style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
                        child: isPosting ? const CircularProgressIndicator(color: Colors.white) : const Text("Publish Event"),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  // =========================================================
  // 🎨 UI HELPERS
  // =========================================================
  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    String titleCased = text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
    return titleCased.replaceAllMapped(RegExp(r'\bascon\b', caseSensitive: false), (match) => 'ASCON');
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Reunion':    return const Color(0xFF1B5E3A); 
      case 'Webinar':    return const Color(0xFF1565C0);     
      case 'Seminar':    return const Color(0xFF6A1B9A);   
      case 'News':       return const Color(0xFFE65100);   
      case 'Conference': return const Color(0xFF0D47A1); 
      case 'Workshop':   return const Color(0xFF00695C); 
      case 'Symposium':  return const Color(0xFFC2185B); 
      case 'AGM':        return const Color(0xFFF57F17); 
      case 'Induction':  return const Color(0xFF2E7D32); 
      case 'Event':      return const Color(0xFF283593);     
      default:           return Colors.grey[800]!;
    }
  }

  Widget _buildSafeImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(color: Colors.grey[900], child: const Center(child: Icon(Icons.image_not_supported_outlined, color: Colors.white24, size: 40)));
    }
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl, fit: BoxFit.cover,
        placeholder: (context, url) => const SkeletonImage(),
        errorWidget: (context, url, error) => Container(color: Colors.grey[900], child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 40))),
      );
    }
    try {
      String cleanBase64 = imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl;
      return Image.memory(base64Decode(cleanBase64), fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey[900], child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white24, size: 40))));
    } catch (e) {
      return Container(color: Colors.grey[900], child: const Center(child: Icon(Icons.error_outline, color: Colors.white24, size: 40)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      appBar: AppBar(
        title: Text("News & Events", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      backgroundColor: scaffoldBg,
      
      body: RefreshIndicator(
        onRefresh: _loadEvents,
        color: primaryColor,
        child: _isLoading
            ? const EventSkeletonList() 
            : _events.isEmpty
                ? _buildEmptyState()
                : GridView.builder( 
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220, 
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.72, 
                    ),
                    itemCount: _events.length,
                    itemBuilder: (context, index) => _buildImmersiveEventCard(_events[index]),
                  ),
      ),

      // ✅ ADMIN FAB
      floatingActionButton: _isAdmin 
        ? FloatingActionButton(
            onPressed: _showCreateEventSheet,
            backgroundColor: const Color(0xFFD4AF37),
            child: const Icon(Icons.add, color: Colors.white),
          )
        : null,
    );
  }

  Widget _buildEmptyState() {
    final color = Theme.of(context).textTheme.bodyMedium?.color;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.newspaper_rounded, size: 70, color: color?.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text("No updates yet", style: GoogleFonts.lato(fontSize: 18, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Check back later for news & events.", style: GoogleFonts.lato(fontSize: 14, color: color?.withOpacity(0.6))),
        ],
      ),
    );
  }

  Widget _buildImmersiveEventCard(dynamic event) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String formattedDate = 'TBA';
    String rawDate = event['date']?.toString() ?? '';
    try {
      if (rawDate.isNotEmpty) {
        formattedDate = DateFormat("d MMM").format(DateTime.parse(rawDate)); 
      }
    } catch (e) { formattedDate = 'TBA'; }

    final String title = event['title']?.toString() ?? 'No Title';
    final String type = event['type'] ?? 'News';
    final String imageUrl = event['image'] ?? event['imageUrl'] ?? ''; 
    final String eventId = (event['_id'] ?? event['id'] ?? '').toString(); 

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20), 
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.15), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildSafeImage(imageUrl),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.0), Colors.black.withOpacity(0.2), Colors.black.withOpacity(0.8), Colors.black.withOpacity(0.95)],
                  stops: const [0.4, 0.6, 0.85, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 10, right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _getTypeColor(type), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]),
                child: Text(type.toUpperCase(), style: GoogleFonts.lato(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
              ),
            ),
            // ✅ ADMIN DELETE ICON
            if (_isAdmin)
              Positioned(
                top: 5, left: 5,
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 16,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                    onPressed: () => _deleteEvent(eventId),
                  ),
                ),
              ),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center, 
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today, size: 10, color: Colors.white.withOpacity(0.8)),
                        const SizedBox(width: 4),
                        Text(formattedDate.toUpperCase(), style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.9), letterSpacing: 0.5)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_toTitleCase(title), maxLines: 3, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2)),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    final Map<String, dynamic> safeEventData = {...event, '_id': eventId, 'date': formattedDate, 'rawDate': rawDate};
                    Navigator.push(context, MaterialPageRoute(builder: (context) => EventDetailScreen(eventData: safeEventData)));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}