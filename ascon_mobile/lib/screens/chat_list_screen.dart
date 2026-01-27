import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../services/api_client.dart';
import '../models/chat_objects.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ApiClient _api = ApiClient();
  final _storage = const FlutterSecureStorage();
  
  List<ChatConversation> _conversations = [];
  bool _isLoading = true;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    _myUserId = await _storage.read(key: 'userId');
    try {
      final result = await _api.get('/api/chat');
      
      // ✅ FIX: Access 'data' and ensure it is a List
      if (mounted && result['success'] == true) {
        final List<dynamic> data = result['data'];
        
        setState(() {
          _conversations = data
              .map((data) => ChatConversation.fromJson(data, _myUserId!))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading chats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text("Messages", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _conversations.isEmpty
              ? _buildEmptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _conversations.length,
                  separatorBuilder: (_, __) => Divider(color: Colors.grey.withOpacity(0.1)),
                  itemBuilder: (context, index) {
                    final chat = _conversations[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      onTap: () async {
                        // Navigate to Chat and refresh when back
                        await Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              conversationId: chat.id,
                              receiverName: chat.otherUserName,
                              receiverId: chat.otherUserId!,
                            )
                          )
                        );
                        _loadChats(); // Refresh inbox on return
                      },
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.grey[300],
                        backgroundImage: (chat.otherUserImage != null && chat.otherUserImage!.startsWith('http'))
                            ? CachedNetworkImageProvider(chat.otherUserImage!)
                            : null,
                        child: chat.otherUserImage == null 
                            ? Text(chat.otherUserName[0], style: const TextStyle(fontWeight: FontWeight.bold))
                            : null,
                      ),
                      title: Text(
                        chat.otherUserName,
                        style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      subtitle: Text(
                        chat.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      trailing: Text(
                        DateFormat('MMM d').format(chat.lastMessageTime),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("No messages yet", style: GoogleFonts.lato(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text("Visit the directory to start networking!", style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}