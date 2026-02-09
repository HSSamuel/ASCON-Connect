import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:async'; 
import 'package:shared_preferences/shared_preferences.dart'; 

import '../services/api_client.dart';
import '../services/socket_service.dart';
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
  List<ChatConversation> _filteredConversations = [];
  
  final Map<String, dynamic> _userPresence = {}; 
  
  bool _isLoading = true;
  bool _isSearching = false;
  String? _myUserId;
  final TextEditingController _searchController = TextEditingController();
  
  StreamSubscription? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _loadChats();
    
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
    _statusSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredConversations = _conversations;
        _isSearching = false;
      } else {
        _isSearching = true;
        _filteredConversations = _conversations.where((chat) {
          return chat.otherUserName.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  Future<void> _loadChats() async {
    // ✅ Ensure ID is loaded BEFORE parsing chats
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
        
        final loaded = data
            .map((data) => ChatConversation.fromJson(data, _myUserId ?? ''))
            // Filter out self-chats unless it's a test/group
            .where((chat) => chat.isGroup || chat.otherUserId != _myUserId) 
            .toList();

        loaded.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));

        setState(() {
          _conversations = loaded;
          _filteredConversations = loaded;
          _isLoading = false;
        });

        _checkInitialStatuses();
      }
    } catch (e) {
      debugPrint("Error loading chats: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _checkInitialStatuses() {
    for (var chat in _conversations) {
      if (!chat.isGroup && chat.otherUserId != null) {
         SocketService().checkUserStatus(chat.otherUserId!);
      }
    }
  }

  Future<void> _deleteChat(String conversationId) async {
    setState(() {
      _conversations.removeWhere((c) => c.id == conversationId);
      _filteredConversations.removeWhere((c) => c.id == conversationId);
    });

    try {
      await _api.delete('/api/chat/$conversationId');
    } catch (e) {
      _loadChats(); 
    }
  }

  String _getSmartDate(DateTime date) {
    final now = DateTime.now();
    final localDate = date.toLocal();
    final difference = now.difference(localDate).inDays;

    if (difference == 0 && localDate.day == now.day) {
      return DateFormat('h:mm a').format(localDate); 
    } else if (difference == 1 || (difference == 0 && localDate.day != now.day)) {
      return "Yesterday";
    } else if (difference < 7) {
      return DateFormat('EEEE').format(localDate); 
    } else {
      return DateFormat('MMM d').format(localDate); 
    }
  }

  Widget _buildAvatar(String? url, String name, bool isGroup) {
    final primaryColor = Theme.of(context).primaryColor;
    
    // Fallback Icon
    Widget fallback = Center(
      child: isGroup 
        ? Icon(Icons.groups, color: primaryColor)
        : Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?', 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: primaryColor)
          )
    );

    bool isInvalid = url == null || 
                     url.isEmpty || 
                     url.contains('profile/picture/1') || 
                     url.contains('googleusercontent.com/profile/picture');

    if (isInvalid) {
      return CircleAvatar(radius: 28, backgroundColor: Colors.grey[300], child: fallback);
    }

    if (kIsWeb) {
       return CircleAvatar(
         radius: 28,
         backgroundColor: Colors.grey[300],
         child: ClipOval(
           child: Image.network(
             url!,
             width: 56,
             height: 56,
             fit: BoxFit.cover,
             errorBuilder: (ctx, err, stack) => fallback, 
           ),
         ),
       );
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: Colors.grey[300],
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.grey[300]),
          errorWidget: (context, url, error) => fallback, 
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final bg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              title: Text("Messages", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 22, color: isDark ? Colors.white : Colors.black)),
              backgroundColor: bg,
              elevation: 0,
              centerTitle: false,
              pinned: true,
              floating: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: "Search chats...",
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: _isLoading
            ? _buildSkeletonLoader()
            : _filteredConversations.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadChats,
                    color: primaryColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(top: 0, bottom: 80),
                      itemCount: _filteredConversations.length,
                      itemBuilder: (context, index) {
                        final chat = _filteredConversations[index];
                        final presence = _userPresence[chat.otherUserId];
                        final bool isOnline = !chat.isGroup && (presence != null && presence['isOnline'] == true);
                        final String? lastSeen = presence != null ? presence['lastSeen'] : null;

                        return Dismissible(
                          key: Key(chat.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Delete Chat?"),
                                content: const Text("This cannot be undone."),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                          },
                          onDismissed: (direction) => _deleteChat(chat.id),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            onTap: () async {
                              // ✅ PASS CORRECT GROUP DATA HERE
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(
                                conversationId: chat.id,
                                receiverName: chat.otherUserName,
                                receiverId: chat.otherUserId ?? '', 
                                receiverProfilePic: chat.otherUserImage, 
                                isOnline: isOnline, 
                                lastSeen: lastSeen,
                                isGroup: chat.isGroup, // ✅ NEW
                                groupId: chat.groupId, // ✅ NEW
                              )));
                              _loadChats(); 
                            },
                            leading: Stack(
                              children: [
                                _buildAvatar(chat.otherUserImage, chat.otherUserName, chat.isGroup),
                                if (isOnline)
                                  Positioned(
                                    right: 2, bottom: 2,
                                    child: Container(
                                      width: 14, height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent[400],
                                        shape: BoxShape.circle,
                                        border: Border.all(color: bg, width: 2.5),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              chat.otherUserName,
                              style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                chat.lastMessage,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.lato(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              ),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _getSmartDate(chat.lastMessageTime.toLocal()), 
                                  style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 10),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const CircleAvatar(radius: 28, backgroundColor: Colors.black12),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 16, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 8),
                    Container(width: 200, height: 12, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.chat_bubble_outline_rounded, size: 50, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(
            _isSearching ? "No chats found" : "No messages yet", 
            style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600])
          ),
          if (!_isSearching)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text("Start a conversation from the Directory", style: GoogleFonts.lato(color: Colors.grey[500])),
            ),
        ],
      ),
    );
  }
}