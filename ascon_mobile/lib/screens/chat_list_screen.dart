import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async'; // ✅ Import Async for StreamSubscription
import 'package:shared_preferences/shared_preferences.dart'; 

import '../services/api_client.dart';
import '../services/socket_service.dart';
import '../models/chat_objects.dart';
import '../config/storage_config.dart';
import '../utils/presence_formatter.dart'; 
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ApiClient _api = ApiClient();
  final _storage = StorageConfig.storage;
  
  List<ChatConversation> _conversations = [];
  
  // ✅ Store presence data for Green Dot
  final Map<String, dynamic> _userPresence = {}; 
  
  bool _isLoading = true;
  String? _myUserId;
  
  // ✅ STREAM SUBSCRIPTION
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _loadChats();
    
    // ✅ NEW: Listen to the central Presence Stream
    _statusSubscription = SocketService().userStatusStream.listen((data) {
      if (!mounted) return;
      setState(() {
        _userPresence[data['userId']] = {
          'isOnline': data['isOnline'],
          'lastSeen': data['lastSeen']
        };
      });
    });
  }

  @override
  void dispose() {
    _statusSubscription?.cancel(); // ✅ Cancel the subscription
    super.dispose();
  }

  Future<void> _loadChats() async {
    _myUserId = await _storage.read(key: 'userId');
    if (_myUserId == null) {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('cached_user');
      if (userString != null) {
        final userData = jsonDecode(userString);
        _myUserId = userData['id'] ?? userData['_id'];
      }
    }

    try {
      final result = await _api.get('/api/chat');
      
      if (mounted && result['success'] == true) {
        final List<dynamic> data = result['data'];
        
        setState(() {
          _conversations = data
              .map((data) => ChatConversation.fromJson(data, _myUserId ?? ''))
              .where((chat) => chat.otherUserId != _myUserId) 
              .toList();
          _isLoading = false;
        });

        // ✅ Check statuses for everyone in the list
        _checkInitialStatuses();
      }
    } catch (e) {
      debugPrint("Error loading chats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _checkInitialStatuses() {
    // We can use the helper method to trigger checks
    // The responses will come through the Stream we are already listening to!
    for (var chat in _conversations) {
      if (chat.otherUserId != null) {
         SocketService().checkUserStatus(chat.otherUserId!);
      }
    }
  }

  // ✅ RESTORED DELETE LOGIC
  Future<void> _deleteChat(String conversationId) async {
    setState(() {
      _conversations.removeWhere((c) => c.id == conversationId);
    });

    try {
      await _api.delete('/api/chat/$conversationId');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Conversation deleted")),
        );
      }
    } catch (e) {
      _loadChats(); // Revert if failed
    }
  }

  void _confirmDelete(ChatConversation chat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Conversation?"),
        content: Text("Delete chat with ${chat.otherUserName}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteChat(chat.id);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
      body: RefreshIndicator(
        onRefresh: _loadChats, 
        color: primaryColor,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _conversations.isEmpty
                ? ListView(children: [SizedBox(height: MediaQuery.of(context).size.height * 0.3), _buildEmptyState()])
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.grey.withOpacity(0.1)),
                    itemBuilder: (context, index) {
                      final chat = _conversations[index];
                      
                      // ✅ Resolve Presence
                      final presence = _userPresence[chat.otherUserId];
                      final bool isOnline = presence != null && presence['isOnline'] == true;
                      final String? lastSeen = presence != null ? presence['lastSeen'] : null;

                      // ✅ Trailing is Message Time (Requested)
                      String trailingText = DateFormat('MMM d').format(chat.lastMessageTime.toLocal());

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        onTap: () async {
                          await Navigator.push(
                            context, 
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                conversationId: chat.id,
                                receiverName: chat.otherUserName,
                                receiverId: chat.otherUserId ?? '', 
                                receiverProfilePic: chat.otherUserImage, 
                                isOnline: isOnline, 
                                lastSeen: lastSeen,
                              )
                            )
                          );
                          _loadChats(); 
                        },
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.grey[300],
                              backgroundImage: (chat.otherUserImage != null && chat.otherUserImage!.startsWith('http'))
                                  ? CachedNetworkImageProvider(chat.otherUserImage!)
                                  : null,
                              child: (chat.otherUserImage == null || chat.otherUserImage!.isEmpty)
                                  ? Text(chat.otherUserName.isNotEmpty ? chat.otherUserName[0] : '?', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor))
                                  : null,
                            ),
                            // ✅ Green Dot Indicator
                            if (isOnline)
                              Positioned(
                                right: 0, bottom: 0,
                                child: Container(
                                  width: 14, height: 14,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                                  ),
                                ),
                              ),
                          ],
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
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              trailingText, // ✅ Shows Date (e.g. "Oct 25")
                              style: TextStyle(
                                fontSize: 12, 
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        onLongPress: () => _confirmDelete(chat),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.chat_bubble_outline, size: 60, color: Colors.grey[400]), const SizedBox(height: 16), Text("No messages yet", style: GoogleFonts.lato(fontSize: 18, color: Colors.grey[600]))]));
  }
}