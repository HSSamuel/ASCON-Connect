import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/data_service.dart';
import '../screens/chat_screen.dart'; // ✅ Import Chat Screen

class ChapterCard extends StatefulWidget {
  const ChapterCard({super.key});

  @override
  State<ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<ChapterCard> {
  List<dynamic> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  Future<void> _fetchGroups() async {
    try {
      final groups = await DataService().fetchMyGroups();
      if (mounted) {
        setState(() {
          _groups = groups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    
    // Fallback if no groups
    if (_groups.isEmpty) {
       return Container(
         margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
         child: const Text("You are not in any Chapters yet."),
       );
    }

    final group = _groups.first;
    final name = group['name'];
    final id = group['_id']; // Group ID for API calls
    final count = group['memberCount'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.groups, color: Colors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("MY COMMUNITY", style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey[600])),
                Text(name, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text("$count Members", style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
               // ✅ Navigate to Group Chat
               Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                 receiverId: id, // For groups, we use GroupID as receiver
                 receiverName: name,
                 isGroup: true,  // ✅ Flag enabled
                 groupId: id,    // ✅ Pass ID for Polls
               )));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text("Chat", style: TextStyle(fontSize: 12)),
          )
        ],
      ),
    );
  }
}