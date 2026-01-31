import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; 

import '../services/api_client.dart';
import '../models/chat_objects.dart';
import '../config/storage_config.dart';
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
  bool _isLoading = true;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    // 1. Get User ID (Critical for identifying "Other" user)
    _myUserId = await _storage.read(key: 'userId');
    
    // Fallback if not in secure storage
    if (_myUserId == null) {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('cached_user');
      if (userString != null) {
        final userData = jsonDecode(userString);
        _myUserId = userData['id'] ?? userData['_id'];
      }
    }

    if (_myUserId == null) {
      debugPrint("⚠️ Warning: Could not find My User ID. Chat names might be wrong.");
    }

    try {
      final result = await _api.get('/api/chat');
      
      if (mounted && result['success'] == true) {
        final List<dynamic> data = result['data'];
        
        setState(() {
          _conversations = data
              .map((data) => ChatConversation.fromJson(data, _myUserId ?? ''))
              // Filter out conversations where 'otherUserId' is ME.
              .where((chat) => chat.otherUserId != _myUserId) 
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading chats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Delete Logic
  Future<void> _deleteChat(String conversationId) async {
    // Optimistic Update: Remove from list immediately
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
      debugPrint("Delete failed: $e");
      _loadChats(); // Revert if failed
    }
  }

  // Confirmation Dialog
  void _confirmDelete(ChatConversation chat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Conversation?"),
        content: Text("Are you sure you want to remove ${chat.otherUserName} from your messages?"),
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
      // ✅ ADDED REFRESH INDICATOR
      body: RefreshIndicator(
        onRefresh: _loadChats, // Triggers reload on swipe down
        color: primaryColor,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _conversations.isEmpty
                // ✅ Wrap empty state in ListView so pull-to-refresh still works
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      _buildEmptyState(),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(), // Ensures bounce effect
                    padding: const EdgeInsets.all(12),
                    itemCount: _conversations.length,
                    separatorBuilder: (_, __) => Divider(color: Colors.grey.withOpacity(0.1)),
                    itemBuilder: (context, index) {
                      final chat = _conversations[index];
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
                              )
                            )
                          );
                          _loadChats(); 
                        },
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: (chat.otherUserImage != null && chat.otherUserImage!.startsWith('http'))
                              ? CachedNetworkImageProvider(chat.otherUserImage!)
                              : null,
                          child: (chat.otherUserImage == null || chat.otherUserImage!.isEmpty)
                              ? Text(
                                  chat.otherUserName.isNotEmpty ? chat.otherUserName[0].toUpperCase() : '?', 
                                  style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)
                                )
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
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              DateFormat('MMM d').format(chat.lastMessageTime.toLocal()),
                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
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