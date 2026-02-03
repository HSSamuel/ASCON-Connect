import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:async'; // ✅ Imported for StreamSubscription
import 'package:intl/intl.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'package:cached_network_image/cached_network_image.dart'; 
import '../widgets/full_screen_image.dart'; 
import 'chat_screen.dart'; 
// ✅ Import DataService for API calls
import '../services/data_service.dart';
// ✅ Import SocketService for Real-Time Presence
import '../services/socket_service.dart';
// ✅ Import PresenceFormatter for consistent times
import '../utils/presence_formatter.dart'; 

class AlumniDetailScreen extends StatefulWidget {
  final Map<String, dynamic> alumniData;

  const AlumniDetailScreen({super.key, required this.alumniData});

  @override
  State<AlumniDetailScreen> createState() => _AlumniDetailScreenState();
}

class _AlumniDetailScreenState extends State<AlumniDetailScreen> {
  // ✅ State for Mentorship Logic
  final DataService _dataService = DataService();
  String _mentorshipStatus = "Loading"; // None, Pending, Accepted, Rejected
  String? _requestId; // Store ID to allow cancellation
  bool _isLoadingStatus = false;

  // ✅ State for Real-Time Presence
  late bool _isOnline;
  String? _lastSeen;
  
  // ✅ STREAM SUBSCRIPTION
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    
    // Initialize Status from passed data first
    _isOnline = widget.alumniData['isOnline'] == true;
    _lastSeen = widget.alumniData['lastSeen'];

    // Only fetch mentorship status if they are actually a mentor
    if (widget.alumniData['isOpenToMentorship'] == true) {
      _checkStatus();
    } else {
      _mentorshipStatus = "None"; 
    }

    // ✅ Start Listening for Real-Time Updates via Stream
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel(); // ✅ Cancel Stream Listener
    super.dispose();
  }

  // ✅ REAL-TIME PRESENCE LOGIC
  void _setupSocketListeners() {
    final socket = SocketService().socket;
    if (socket == null) return;
    final targetUserId = widget.alumniData['_id'];

    // 1. Initial Check
    SocketService().checkUserStatus(targetUserId);

    // 2. Listen to the Stream
    _statusSubscription = SocketService().userStatusStream.listen((data) {
      if (!mounted) return;
      if (data['userId'] == targetUserId) {
        setState(() {
          _isOnline = data['isOnline'];
          if (!_isOnline) _lastSeen = data['lastSeen'];
        });
      }
    });
  }

  // ✅ 1. Check current relationship status from Backend
  Future<void> _checkStatus() async {
    // Only show loading on initial load or manual actions, not silent refresh
    if (_mentorshipStatus == "Loading") setState(() => _isLoadingStatus = true);
    
    // Uses the new Phase 4 method that returns a Map {status, requestId}
    final result = await _dataService.getMentorshipStatusFull(widget.alumniData['_id']);
    if (mounted) {
      setState(() {
        _mentorshipStatus = result['status'];
        _requestId = result['requestId']; // Capture the ID
        _isLoadingStatus = false;
      });
    }
  }

  // ✅ 2. Handle Pull-to-Refresh
  Future<void> _onRefresh() async {
    // 1. Refresh Mentorship Status
    if (widget.alumniData['isOpenToMentorship'] == true) {
      await _checkStatus();
    }

    // 2. Force Refresh Presence
    final targetUserId = widget.alumniData['_id'];
    SocketService().checkUserStatus(targetUserId);
    
    // 3. Small artificial delay for better UX (so the spinner doesn't disappear instantly)
    await Future.delayed(const Duration(milliseconds: 800));
  }

  // ✅ 3. Handle sending the request with a pitch
  Future<void> _handleRequest() async {
    TextEditingController pitchCtrl = TextEditingController();
    
    // Show Pitch Dialog
    final bool? send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Request Mentorship", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Write a short note introducing yourself and why you'd like mentorship:"),
            const SizedBox(height: 10),
            TextField(
              controller: pitchCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "Hi, I admire your work in...",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white),
            child: const Text("Send Request"),
          ),
        ],
      ),
    );

    // If user clicked Send
    if (send == true) {
      setState(() => _isLoadingStatus = true);
      final success = await _dataService.sendMentorshipRequest(widget.alumniData['_id'], pitchCtrl.text);
      
      if (mounted) {
        // Refresh status immediately to get the new Request ID
        await _checkStatus();
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? "Request Sent Successfully!" : "Failed to send request."),
          backgroundColor: success ? Colors.green : Colors.red,
        ));
      }
    }
  }

  Future<void> _launchURL(String urlString) async {
    if (urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  // ✅ UPDATED: Use PresenceFormatter logic
  String _formatLastSeen(String? dateString) {
    if (dateString == null) return "Offline";
    final formatted = PresenceFormatter.format(dateString);
    if (formatted == "Just now" || formatted == "Active just now") return "Active just now";
    return "Last seen $formatted";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final scaffoldBg = isDark ? const Color(0xFF121212) : Colors.grey[50];
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryColor = const Color(0xFF1B5E3A);
    
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[700];

    // ✅ Access via widget.alumniData
    final String fullName = widget.alumniData['fullName'] ?? 'Unknown Alumnus';
    final String job = widget.alumniData['jobTitle'] ?? '';
    final String org = widget.alumniData['organization'] ?? '';
    
    String rawBio = widget.alumniData['bio'] ?? '';
    final String bio = rawBio.trim().isNotEmpty ? rawBio : 'No biography provided.';

    final bool showPhone = widget.alumniData['isPhoneVisible'] == true;
    final bool isMentor = widget.alumniData['isOpenToMentorship'] == true;
    
    // ✅ Use Live State for Status
    final String statusText = _isOnline ? "Active Now" : _formatLastSeen(_lastSeen);

    final String phone = widget.alumniData['phoneNumber'] ?? '';
    final String linkedin = widget.alumniData['linkedin'] ?? '';
    final String email = widget.alumniData['email'] ?? '';
    final String year = widget.alumniData['yearOfAttendance']?.toString() ?? 'Unknown';
    final String imageString = widget.alumniData['profilePicture'] ?? '';
    
    final String zoomHeroTag = "zoom_profile_${widget.alumniData['_id'] ?? DateTime.now().millisecondsSinceEpoch}";

    final String programme = (widget.alumniData['programmeTitle'] != null && widget.alumniData['programmeTitle'].toString().isNotEmpty) 
        ? widget.alumniData['programmeTitle'] 
        : 'Not Specified';

    // ✅ 4. Helper to Build the Smart Button
    Widget buildMentorshipButton() {
      if (!isMentor) return const SizedBox.shrink();

      if (_isLoadingStatus) {
        return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
      }

      String label = "Request Mentorship";
      Color btnColor = Colors.amber[800]!;
      VoidCallback? action = _handleRequest;
      IconData icon = Icons.handshake_rounded;

      // Logic based on API Status
      if (_mentorshipStatus == "Pending") {
        label = "Withdraw Request"; // ✅ Cancel Option
        btnColor = Colors.orange[800]!;
        icon = Icons.cancel_outlined;
        
        // ✅ Withdraw Logic
        action = () async {
           final confirm = await showDialog(
             context: context, 
             builder: (c) => AlertDialog(
               title: const Text("Withdraw Request?"),
               content: const Text("Are you sure you want to cancel this mentorship request?"),
               actions: [
                 TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("No")),
                 TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Yes, Withdraw", style: TextStyle(color: Colors.red))),
               ],
             )
           );

           if (confirm == true && _requestId != null) {
             setState(() => _isLoadingStatus = true);
             final success = await _dataService.deleteMentorshipInteraction(_requestId!, 'cancel');
             if (mounted) {
               await _checkStatus(); // Refresh to "None"
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                 content: Text(success ? "Request Withdrawn" : "Failed to withdraw"),
                 backgroundColor: success ? Colors.grey : Colors.red,
               ));
             }
           }
        };
      } else if (_mentorshipStatus == "Accepted") {
        label = "Message Mentor";
        btnColor = Colors.green[700]!;
        icon = Icons.chat;
        action = () {
           // ✅ FIX: Use rootNavigator to hide Bottom Nav Bar
           Navigator.of(context, rootNavigator: true).push(
             MaterialPageRoute(builder: (_) => ChatScreen(
              receiverId: widget.alumniData['_id'],
              receiverName: fullName,
              receiverProfilePic: imageString,
              isOnline: _isOnline, 
              lastSeen: _lastSeen, 
           )));
        };
      } else if (_mentorshipStatus == "Rejected") {
        label = "Request Declined";
        btnColor = Colors.red[300]!;
        action = null;
        icon = Icons.block;
      }

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 60, vertical: 10),
        child: ElevatedButton.icon(
          onPressed: action,
          icon: Icon(icon, color: Colors.white, size: 20),
          label: Text(label, style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: btnColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(vertical: 10),
            elevation: 2,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      // ❌ Removed standard AppBar
      body: Stack(
        children: [
          // 1️⃣ Main Scrollable Content Wrapped in RefreshIndicator
          RefreshIndicator(
            onRefresh: _onRefresh,
            color: primaryColor, // Matches app theme
            backgroundColor: isDark ? Colors.grey[800] : Colors.white,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(), // Ensures swipe works even if content is short
              child: Column(
                children: [
                  // --- 1. HEADER SECTION ---
                  SizedBox(
                    height: 180, // Increased height for immersive look
                    child: Stack(
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 140, 
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1B5E3A), Color(0xFF2E8B57)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                          ),
                        ),
                        Positioned(
                          top: 90, // Adjusted position
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (imageString.isNotEmpty && !imageString.contains('https://lh3.googleusercontent.com/a/ACg8ocLUAgz3dKVYY5ttmmjOi3u8H9kodBXwT0ZrOX2YK7DghVqRhopX=s96-c')) {
                                // ✅ FIX: Use rootNavigator for Full Screen Image too
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                    builder: (_) => FullScreenImage(
                                      imageUrl: imageString,
                                      heroTag: zoomHeroTag,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Hero(
                              tag: zoomHeroTag,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cardColor, width: 4),
                                  boxShadow: [
                                    if (!isDark)
                                      BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 5))
                                  ],
                                ),
                                child: _buildRobustAvatar(imageString, isDark),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10), 

                  // --- 2. IDENTITY SECTION ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Text(
                          fullName,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(
                            fontSize: 22, 
                            fontWeight: FontWeight.bold, 
                            color: textColor 
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        if (job.isNotEmpty || org.isNotEmpty)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.work_outline, size: 14, color: subTextColor),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  "$job${(job.isNotEmpty && org.isNotEmpty) ? ' at ' : ''}$org",
                                  style: GoogleFonts.lato(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        
                        // Presence Status
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  color: _isOnline ? Colors.green : Colors.grey[400],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusText, 
                                style: GoogleFonts.lato(
                                  color: _isOnline ? Colors.green[700] : Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 10),
                        
                        if (isMentor)
                          Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.amber.shade600),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.stars_rounded, color: Colors.amber.shade700, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "Open to Mentoring",
                                  style: GoogleFonts.lato(color: Colors.amber.shade800, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ],
                            ),
                          ),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                          ),
                          child: Text(
                            "Class of $year",
                            style: GoogleFonts.lato(color: const Color(0xFFB8860B), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ✅ SMART MENTORSHIP BUTTON (Replaces static one)
                  buildMentorshipButton(),

                  const SizedBox(height: 10),

                  // --- 3. CONTACT ACTION BUTTONS ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCircleAction(context, Icons.chat_bubble_outline, "Message", primaryColor, () {
                        // ✅ FIX: Use rootNavigator here as well
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              receiverId: widget.alumniData['_id'] ?? '',
                              receiverName: fullName,
                              receiverProfilePic: imageString,
                              isOnline: _isOnline, // ✅ Pass live status
                              lastSeen: _lastSeen, // ✅ Pass live last seen
                            ),
                          ),
                        );
                      }),

                      if (linkedin.isNotEmpty)
                        _buildCircleAction(context, Icons.link, "LinkedIn", Colors.blue[700]!, () => _launchURL(linkedin)),
                      
                      if (email.isNotEmpty)
                        _buildCircleAction(context, Icons.email, "Email", Colors.red[400]!, () => _launchURL("mailto:$email")),
                      
                      if (showPhone && phone.isNotEmpty)
                        _buildCircleAction(context, Icons.phone, "Call", Colors.green[600]!, () => _launchURL("tel:$phone")),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // --- 4. DETAILS CARDS ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        // About Me Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.person_outline_rounded, size: 20, color: primaryColor),
                                  const SizedBox(width: 8),
                                  Text(
                                    "About Me",
                                    style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                bio,
                                style: GoogleFonts.lato(fontSize: 14, height: 1.6, color: subTextColor),
                                textAlign: TextAlign.justify,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Programme Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.school_outlined, color: primaryColor, size: 22),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Programme Attended",
                                      style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      programme,
                                      style: GoogleFonts.lato(
                                        fontSize: 14, 
                                        fontWeight: FontWeight.bold, 
                                        color: programme == 'Not Specified' ? Colors.grey : textColor
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // 2️⃣ Custom Floating Back Button (Top Left)
          Positioned(
            top: 40, // Standard safe area top padding
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2), // Semi-transparent for visibility
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRobustAvatar(String imageString, bool isDark) {
    if (imageString.isEmpty || imageString.contains('googleusercontent.com/profile/picture/0')) {
      return _buildPlaceholder(isDark);
    }

    if (imageString.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageString,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 45,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => _buildPlaceholder(isDark),
        errorWidget: (context, url, error) => _buildPlaceholder(isDark),
      );
    }

    try {
      return CircleAvatar(
        radius: 45,
        backgroundImage: MemoryImage(base64Decode(imageString)),
      );
    } catch (e) {
      return _buildPlaceholder(isDark);
    }
  }

  Widget _buildPlaceholder(bool isDark) {
    return CircleAvatar(
      radius: 45,
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      child: Icon(Icons.person, size: 45, color: isDark ? Colors.grey[500] : Colors.grey),
    );
  }

  Widget _buildCircleAction(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white; 
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardColor,
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.3)),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 3))
                ],
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}