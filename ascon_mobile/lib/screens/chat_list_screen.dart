import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';
import '../widgets/shimmer_utils.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();
  final SocketService _socket = SocketService();
  
  List<dynamic> _conversations = [];
  List<dynamic> _filteredConversations = [];
  List<dynamic> _onlineUsers = []; 
  
  bool _isLoading = true;
  String _myId = "";
  final TextEditingController _searchController = TextEditingController();

  // ✅ PRO: Track typing status per conversation ID
  final Map<String, bool> _typingStatus = {};

  @override
  void initState() {
    super.initState();
    _initData();
    _setupSocket();
  }

  @override
  void dispose() {
    // Socket listeners for typing are global, careful removing them if used elsewhere
    // Ideally, turn off specific listeners here
    _socket.socket?.off('new_message');
    _socket.socket?.off('typing_start');
    _socket.socket?.off('typing_stop');
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    _myId = await _auth.currentUserId ?? "";
    await _loadConversations();
  }

  Future<void> _loadConversations() async {
    if (!mounted) return;
    try {
      final res = await _api.get('/api/chat'); // Ensure this endpoint returns full conversation objects
      
      if (mounted && res['success'] == true) {
        final List<dynamic> data = res['data'];
        
        setState(() {
          _conversations = data;
          _filteredConversations = data;
          _isLoading = false;
          
          // Logic for "Active Now" rail
          _onlineUsers = data.where((c) {
             final other = _getOtherParticipant(c);
             return other['isOnline'] == true;
          }).take(10).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ PRO: Live Socket Updates
  void _setupSocket() {
    final socket = _socket.socket;
    if (socket == null) return;

    // 1. Live Message Updates (Optimistic)
    socket.on('new_message', (data) {
      if (!mounted) return;
      _handleIncomingMessage(data);
    });

    // 2. Typing Indicators
    socket.on('typing_start', (data) {
      if (mounted) setState(() => _typingStatus[data['conversationId']] = true);
    });

    socket.on('typing_stop', (data) {
      if (mounted) setState(() => _typingStatus[data['conversationId']] = false);
    });
  }

  // ✅ PRO: Handle incoming message without full reload
  void _handleIncomingMessage(dynamic data) {
    final convId = data['conversationId'];
    final index = _conversations.indexWhere((c) => c['_id'] == convId);

    if (index != -1) {
      setState(() {
        var chat = _conversations.removeAt(index);
        
        // Update last message preview
        chat['lastMessage'] = data['message']['text'] ?? "Media";
        chat['lastMessageAt'] = data['message']['createdAt'];
        
        // Handle lastMessage object if your API supports it structure
        chat['lastMessageObj'] = data['message']; 

        // Increment unread count if not from me
        if (data['message']['senderId'] != _myId) {
          chat['unreadCount'] = (chat['unreadCount'] ?? 0) + 1;
        }

        _conversations.insert(0, chat);
        // Re-apply search filter if active
        if (_searchController.text.isNotEmpty) {
          _onSearchChanged(_searchController.text);
        } else {
          _filteredConversations = _conversations;
        }
      });
    } else {
      _loadConversations(); // New chat created remotely
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredConversations = _conversations;
      } else {
        _filteredConversations = _conversations.where((c) {
          final other = _getOtherParticipant(c);
          final name = (other['fullName'] ?? other['name'] ?? "").toString().toLowerCase();
          
          // Handle dynamic lastMessage type (String or Map)
          String lastMsgText = "";
          if (c['lastMessage'] is Map) {
            lastMsgText = c['lastMessage']['text'] ?? "";
          } else {
            lastMsgText = c['lastMessage'].toString();
          }
          
          return name.contains(query.toLowerCase()) || lastMsgText.toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  // ✅ PRO: Delete Conversation Action
  Future<void> _deleteConversation(String id) async {
    try {
      // Optimistic remove
      setState(() {
        _conversations.removeWhere((c) => c['_id'] == id);
        _filteredConversations.removeWhere((c) => c['_id'] == id);
      });
      await _api.delete('/api/chat/conversation/$id');
    } catch (e) {
      // Revert if failed (optional, usually not needed for delete)
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not delete chat")));
    }
  }

  Map<String, dynamic> _getOtherParticipant(Map<String, dynamic> conversation) {
    if (conversation['isGroup'] == true) {
      final group = conversation['groupId'];
      // Handle case where group info might be populated or ID string
      if (group is Map) {
        return {
          '_id': group['_id'],
          'fullName': group['name'] ?? "Group",
          'profilePicture': group['icon'],
          'isOnline': false, 
          'isGroup': true
        };
      } else {
         return {'fullName': "Group Chat", 'isGroup': true, 'isOnline': false};
      }
    }

    final participants = conversation['participants'] as List;
    final other = participants.firstWhere(
      (p) => p['_id'] != _myId,
      orElse: () => {'fullName': 'Unknown User', 'profilePicture': ''},
    );
    return other;
  }

  // ==========================================
  // 🎨 UI BUILDER
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // 1. CUSTOM APP BAR (Search & Title)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Messages", style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: "Search chats...",
                      prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ],
              ),
            ),

            // 2. CONTENT
            Expanded(
              child: _isLoading 
                ? const ChatListSkeleton() // ✅ Using new skeleton from utils
                : RefreshIndicator(
                    onRefresh: _loadConversations,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // A. ACTIVE NOW RAIL
                          if (_onlineUsers.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                              child: Text("Active Now", style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                            ),
                            SizedBox(
                              height: 90,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: _onlineUsers.length,
                                itemBuilder: (context, index) {
                                  final user = _getOtherParticipant(_onlineUsers[index]);
                                  return _buildActiveUserBubble(user);
                                },
                              ),
                            ),
                          ],

                          // B. CHAT LIST
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                            child: Text("Recent", style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                          ),
                          
                          if (_filteredConversations.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Center(child: Column(
                                children: [
                                  Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[300]),
                                  const SizedBox(height: 10),
                                  Text("No conversations found.", style: TextStyle(color: Colors.grey[500])),
                                ],
                              )),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _filteredConversations.length,
                              separatorBuilder: (c, i) => Divider(height: 1, indent: 80, color: Colors.grey.withOpacity(0.1)),
                              itemBuilder: (context, index) => _buildChatTile(_filteredConversations[index]),
                            ),
                            
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveUserBubble(Map<String, dynamic> user) {
    return GestureDetector(
      onTap: () => _openChat(user, null),
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: (user['profilePicture'] != null && user['profilePicture'] != "") 
                      ? CachedNetworkImageProvider(user['profilePicture']) 
                      : null,
                  child: (user['profilePicture'] == null || user['profilePicture'] == "") 
                      ? const Icon(Icons.person, color: Colors.grey) 
                      : null,
                ),
                Positioned(
                  right: 2, bottom: 2,
                  child: Container(
                    width: 14, height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2.5)
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 60,
              child: Text(
                (user['fullName'] ?? "User").split(" ")[0], 
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            )
          ],
        ),
      ),
    );
  }

  // ✅ PRO WIDGET: Chat Tile with Swipe-to-Delete
  Widget _buildChatTile(Map<String, dynamic> chat) {
    final other = _getOtherParticipant(chat);
    final String convId = chat['_id'];
    
    // Handle message data safely
    dynamic lastMsgObj = chat['lastMessage']; // Could be String or Map depending on API
    String lastMessageText = "Photo";
    String? senderId;
    bool isRead = true;

    if (lastMsgObj is Map) {
      lastMessageText = lastMsgObj['text'] ?? (lastMsgObj['fileUrl'] != null ? "Attachment" : "Message");
      senderId = lastMsgObj['senderId'];
      isRead = lastMsgObj['isRead'] ?? true;
    } else if (lastMsgObj is String) {
      lastMessageText = lastMsgObj;
    }

    final int unreadCount = chat['unreadCount'] ?? 0;
    final bool isOnline = other['isOnline'] == true;
    final bool isTyping = _typingStatus[convId] ?? false;
    final String time = _formatTime(chat['lastMessageAt']);
    final bool isMe = senderId == _myId;

    

    return Dismissible(
      key: Key(convId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Chat?"),
            content: const Text("This conversation will be removed from your list."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      onDismissed: (direction) => _deleteConversation(convId),
      child: InkWell(
        onTap: () {
          // Clear unread count visually immediately
          setState(() {
             chat['unreadCount'] = 0;
          });
          _openChat(other, convId);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: (other['profilePicture'] != null && other['profilePicture'] != "") 
                        ? CachedNetworkImageProvider(other['profilePicture']) 
                        : null,
                    child: (other['profilePicture'] == null || other['profilePicture'] == "") 
                        ? const Icon(Icons.person, color: Colors.grey) 
                        : null,
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0, bottom: 0,
                      child: Container(
                        width: 14, height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2)
                        ),
                      ),
                    )
                ],
              ),
              const SizedBox(width: 14),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            other['fullName'] ?? "Unknown", 
                            maxLines: 1, 
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lato(
                              fontWeight: unreadCount > 0 ? FontWeight.w900 : FontWeight.bold, 
                              fontSize: 16,
                              color: Theme.of(context).textTheme.bodyLarge?.color
                            )
                          ),
                        ),
                        Text(
                          time, 
                          style: TextStyle(
                            fontSize: 11, 
                            color: unreadCount > 0 ? Theme.of(context).primaryColor : Colors.grey,
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal
                          )
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    
                    // Subtitle Row: Typing OR (Status Tick + Message)
                    
                    Row(
                      children: [
                        Expanded(
                          child: isTyping 
                            ? Text(
                                "Typing...", 
                                style: TextStyle(color: Theme.of(context).primaryColor, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600)
                              )
                            : Row(
                                children: [
                                  // ✅ Message Status Tick
                                  if (isMe) ...[
                                    Icon(
                                      // If API doesn't give 'isRead', assume read for now or check logic
                                      isRead ? Icons.done_all : Icons.check, 
                                      size: 16, 
                                      color: isRead ? Colors.blue : Colors.grey
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Expanded(
                                    child: Text(
                                      lastMessageText, 
                                      maxLines: 1, 
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: unreadCount > 0 ? Theme.of(context).textTheme.bodyLarge?.color : Colors.grey[600],
                                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 14
                                      )
                                    ),
                                  ),
                                ],
                              ),
                        ),
                        
                        // ✅ Unread Badge
                        if (unreadCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
                            child: Text(
                              unreadCount > 9 ? "9+" : unreadCount.toString(), 
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                            ),
                          )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return "";
    final date = DateTime.parse(dateString).toLocal();
    final now = DateTime.now();
    
    if (now.difference(date).inDays == 0 && now.day == date.day) {
      return DateFormat('h:mm a').format(date); 
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('E').format(date); // Mon
    } else {
      return DateFormat('dd/MM').format(date); 
    }
  }

  void _openChat(Map<String, dynamic> user, String? conversationId) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: user['_id'],
          receiverName: user['fullName'],
          receiverProfilePic: user['profilePicture'],
          isOnline: user['isOnline'] ?? false,
          isGroup: user['isGroup'] ?? false,
          groupId: user['isGroup'] == true ? user['_id'] : null,
          conversationId: conversationId,
        ),
      ),
    ).then((_) => _loadConversations()); 
  }
}