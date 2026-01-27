import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ✅ Added for fallback
import 'dart:convert'; // ✅ Added for JSON decode
import '../services/api_client.dart';
import '../services/socket_service.dart';
import '../models/chat_objects.dart';

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    this.conversationId,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiClient _api = ApiClient();
  final _storage = const FlutterSecureStorage();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  String? _activeConversationId;
  String? _myUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _activeConversationId = widget.conversationId;
    _initializeChat();
    
    // ✅ REAL-TIME LISTENER
    SocketService().socket.on('new_message', (data) {
      if (!mounted) return;
      // Only add if it belongs to THIS conversation
      if (data['conversationId'] == _activeConversationId) {
        setState(() {
          try {
            _messages.add(ChatMessage.fromJson(data['message']));
            _scrollToBottom();
          } catch (e) {
            debugPrint("Error parsing incoming message: $e");
          }
        });
      }
    });
  }

  @override
  void dispose() {
    SocketService().socket.off('new_message'); 
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    // ✅ FIX: Robust User ID Retrieval
    _myUserId = await _storage.read(key: 'userId');
    
    // Fallback: If SecureStorage is empty (legacy session), try SharedPrefs
    if (_myUserId == null) {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('cached_user');
      if (userString != null) {
        final userData = jsonDecode(userString);
        _myUserId = userData['_id'];
        // Heal the session
        if (_myUserId != null) {
          await _storage.write(key: 'userId', value: _myUserId);
        }
      }
    }

    if (_activeConversationId != null) {
      await _loadMessages();
    } else {
      await _findOrCreateConversation();
    }
  }

  Future<void> _findOrCreateConversation() async {
    try {
      final result = await _api.post('/api/chat/start', {'receiverId': widget.receiverId});
      
      // ✅ FIX: Access 'data' from response wrapper
      if (mounted && result['success'] == true && result['data'] != null) {
        setState(() {
          _activeConversationId = result['data']['_id'];
        });
        await _loadMessages();
      }
    } catch (e) {
      debugPrint("Error finding chat: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMessages() async {
    if (_activeConversationId == null) return;
    try {
      final result = await _api.get('/api/chat/$_activeConversationId');
      
      // ✅ FIX: Access 'data' and Cast properly
      if (mounted && result['success'] == true) {
        final List<dynamic> data = result['data'];
        setState(() {
          _messages = data.map((m) => ChatMessage.fromJson(m)).toList();
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Error loading messages: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    
    // ✅ FIX: Guard clauses
    if (text.isEmpty) return;
    if (_activeConversationId == null) {
      debugPrint("⚠️ Cannot send: No active conversation ID.");
      return;
    }
    if (_myUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session error. Please log out and log in again.")),
      );
      return;
    }

    _textController.clear();

    try {
      final result = await _api.post('/api/chat/$_activeConversationId', {'text': text});
      
      // ✅ FIX: Access 'data' for the saved message
      if (mounted && result['success'] == true && result['data'] != null) {
        final messageData = result['data'];
        setState(() {
          _messages.add(ChatMessage(
            id: messageData['_id'] ?? 'temp',
            senderId: _myUserId!, 
            text: text,
            createdAt: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Send failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send message")));
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receiverName, style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(child: Text("Say hi to ${widget.receiverName} 👋", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.senderId == _myUserId;
                          return _buildMessageBubble(msg, isMe, isDark, primaryColor);
                        },
                      ),
          ),
          _buildInputArea(isDark, primaryColor),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, bool isDark, Color primary) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? primary : (isDark ? Colors.grey[800] : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('h:mm a').format(msg.createdAt),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  filled: true,
                  fillColor: isDark ? Colors.grey[900] : Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: primary,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}