import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart'; // ✅ For Camera/Gallery
import 'package:file_picker/file_picker.dart';   // ✅ For Files
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http; // For Multipart Request
import 'package:cached_network_image/cached_network_image.dart';

import '../services/api_client.dart';
import '../services/socket_service.dart';
import '../models/chat_objects.dart';
import '../config.dart'; // To access Base URL

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String receiverId;
  final String receiverName;
  final String? receiverProfilePic; // ✅ UI: Avatar
  final bool isOnline;              // ✅ Status: Initial State
  final String? lastSeen;           // ✅ Status: Initial Time

  const ChatScreen({
    super.key,
    this.conversationId,
    required this.receiverId,
    required this.receiverName,
    this.receiverProfilePic,
    this.isOnline = false,
    this.lastSeen,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ApiClient _api = ApiClient();
  final _storage = const FlutterSecureStorage();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<ChatMessage> _messages = [];
  String? _activeConversationId;
  String? _myUserId;
  bool _isLoading = true;
  bool _isSending = false;

  // ✅ REAL-TIME STATUS STATE
  late bool _isPeerOnline;
  String? _peerLastSeen;

  @override
  void initState() {
    super.initState();
    _activeConversationId = widget.conversationId;
    
    // Initialize Status
    _isPeerOnline = widget.isOnline;
    _peerLastSeen = widget.lastSeen;

    _initializeChat();
    
    // 1. LISTEN FOR NEW MESSAGES
    SocketService().socket.on('new_message', (data) {
      if (!mounted) return;
      if (data['conversationId'] == _activeConversationId) {
        setState(() {
           try {
             _messages.add(ChatMessage.fromJson(data['message']));
             _scrollToBottom();
             // ✅ If I am viewing the chat, mark this new message as read immediately
             _markMessagesAsRead();
           } catch (e) {
             debugPrint("Error parsing incoming message: $e");
           }
        });
      }
    });

    // 2. LISTEN FOR STATUS UPDATES (Online/Offline)
    SocketService().socket.on('user_status_update', (data) {
      if (!mounted) return;
      if (data['userId'] == widget.receiverId) {
        setState(() {
          _isPeerOnline = data['isOnline'];
          // Update last seen only if they went offline
          if (!_isPeerOnline) {
             _peerLastSeen = data['lastSeen'] ?? DateTime.now().toIso8601String();
          }
        });
      }
    });

    // ✅ 3. LISTEN FOR "READ RECEIPT" EVENTS
    SocketService().socket.on('messages_read', (data) {
      if (!mounted) return;
      if (data['conversationId'] == _activeConversationId) {
        setState(() {
          // Mark all my messages as read in the UI
          for (var msg in _messages) {
            if (msg.senderId == _myUserId) {
              msg.isRead = true;
            }
          }
        });
      }
    });
  }

  @override
  void dispose() {
    SocketService().socket.off('new_message'); 
    SocketService().socket.off('user_status_update');
    SocketService().socket.off('messages_read'); // ✅ Cleanup
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------
  // 🛠️ DATA INIT & HELPERS
  // --------------------------------------------------------

  Future<void> _initializeChat() async {
    // 1. Get User ID (Secure Storage -> SharedPrefs Fallback)
    _myUserId = await _storage.read(key: 'userId');
    
    if (_myUserId == null) {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('cached_user');
      if (userString != null) {
        final userData = jsonDecode(userString);
        _myUserId = userData['id'] ?? userData['_id'];
        if (_myUserId != null) {
          await _storage.write(key: 'userId', value: _myUserId!);
        }
      }
    }

    if (_activeConversationId != null) {
      await _loadMessages();
    } else {
      await _findOrCreateConversation();
    }
  }

  // ✅ NEW: Mark messages as read on server
  Future<void> _markMessagesAsRead() async {
    if (_activeConversationId == null) return;
    try {
      await _api.put('/api/chat/read/$_activeConversationId', {});
    } catch (e) {
      // Fail silently
    }
  }

  Future<void> _findOrCreateConversation() async {
    try {
      final result = await _api.post('/api/chat/start', {'receiverId': widget.receiverId});
      
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
      
      if (mounted && result['success'] == true) {
        final List<dynamic> data = result['data'];
        setState(() {
          _messages = data.map((m) => ChatMessage.fromJson(m)).toList();
          _isLoading = false;
        });
        _scrollToBottom();
        _markMessagesAsRead(); // ✅ Mark as read when loaded
      }
    } catch (e) {
      debugPrint("Error loading messages: $e");
      setState(() => _isLoading = false);
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

  // ✅ Helper: Authentic Status Text
  String _getStatusText() {
    if (_isPeerOnline) return "Active Now";
    
    if (_peerLastSeen == null) return "Offline";

    try {
      final lastSeen = DateTime.parse(_peerLastSeen!).toLocal();
      final now = DateTime.now();
      
      if (now.day == lastSeen.day && now.month == lastSeen.month && now.year == lastSeen.year) {
        return "Last seen today at ${DateFormat('h:mm a').format(lastSeen)}";
      }
      
      final yesterday = now.subtract(const Duration(days: 1));
      if (yesterday.day == lastSeen.day && yesterday.month == lastSeen.month && yesterday.year == lastSeen.year) {
        return "Last seen yesterday at ${DateFormat('h:mm a').format(lastSeen)}";
      }

      return "Last seen ${DateFormat('MMM d, h:mm a').format(lastSeen)}";
    } catch (e) {
      return "Offline";
    }
  }

  // --------------------------------------------------------
  // 🚀 SENDING LOGIC (Text & Files)
  // --------------------------------------------------------

  Future<void> _sendMessage({String? text, File? file, String type = 'text'}) async {
    if ((text == null || text.trim().isEmpty) && file == null) return;
    if (_activeConversationId == null || _myUserId == null) return;

    setState(() => _isSending = true);

    try {
      var request = http.MultipartRequest(
        'POST', 
        Uri.parse('${AppConfig.baseUrl}/api/chat/$_activeConversationId')
      );
      
      String? token = await _storage.read(key: 'auth_token');
      request.headers['auth-token'] = token ?? '';

      if (text != null) request.fields['text'] = text;
      request.fields['type'] = type;

      if (file != null) {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages.add(ChatMessage.fromJson(data));
          _textController.clear();
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Upload failed: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to send message")));
    } finally {
      setState(() => _isSending = false);
    }
  }

  // --------------------------------------------------------
  // 🗑️ EDIT & DELETE LOGIC
  // --------------------------------------------------------

  void _showMessageOptions(ChatMessage msg) {
    if (msg.senderId != _myUserId || msg.isDeleted) return; 

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (msg.type == 'text') 
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Message'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(msg);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(msg);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(ChatMessage msg) async {
    // ✅ HARD DELETE: Remove from list immediately
    setState(() {
      _messages.removeWhere((m) => m.id == msg.id);
    });

    try {
      await _api.delete('/api/chat/message/${msg.id}'); 
    } catch (e) {
      debugPrint("Delete failed on server: $e");
    }
  }

  void _showEditDialog(ChatMessage msg) {
    TextEditingController editCtrl = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Message"),
        content: TextField(controller: editCtrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() {
                msg.text = editCtrl.text;
                msg.isEdited = true;
              });
              await _api.put('/api/chat/message/${msg.id}', {'text': editCtrl.text});
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // 📎 ATTACHMENT MENU
  // --------------------------------------------------------
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          children: [
            _attachOption(Icons.image, Colors.purple, "Gallery", () => _pickImage(ImageSource.gallery)),
            _attachOption(Icons.camera_alt, Colors.pink, "Camera", () => _pickImage(ImageSource.camera)),
            _attachOption(Icons.insert_drive_file, Colors.blue, "File", _pickFile),
          ],
        ),
      ),
    );
  }

  Widget _attachOption(IconData icon, Color color, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GestureDetector(
        onTap: () { Navigator.pop(context); onTap(); },
        child: Column(
          children: [
            CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      _sendMessage(file: File(image.path), type: 'image');
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      _sendMessage(file: file, type: 'file');
    }
  }

  // --------------------------------------------------------
  // 🎨 UI BUILD
  // --------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            // ✅ PRO AVATAR (From Widget Param)
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[300],
              backgroundImage: (widget.receiverProfilePic != null && widget.receiverProfilePic!.isNotEmpty)
                  ? CachedNetworkImageProvider(widget.receiverProfilePic!)
                  : null,
              child: (widget.receiverProfilePic == null || widget.receiverProfilePic!.isEmpty)
                  ? Text(widget.receiverName.substring(0, 1).toUpperCase(),
                      style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.receiverName,
                  style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                // ✅ DYNAMIC STATUS (Socket Powered)
                Text(
                  _getStatusText(), 
                  style: TextStyle(
                    fontSize: 11, 
                    color: _isPeerOnline ? Colors.greenAccent : Colors.white70,
                    fontWeight: _isPeerOnline ? FontWeight.w600 : FontWeight.normal
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return GestureDetector(
                  onLongPress: () => _showMessageOptions(msg), // ✅ Long press to Edit/Delete
                  child: _buildMessageBubble(msg, msg.senderId == _myUserId, isDark, primaryColor),
                );
              },
            ),
          ),
          if (_isSending) const LinearProgressIndicator(minHeight: 2),
          _buildInputArea(isDark, primaryColor),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // 🎨 WIDGETS
  // --------------------------------------------------------

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, bool isDark, Color primary) {
    // 1. DELETED MESSAGE (Return Empty SizedBox to hide completely)
    if (msg.isDeleted) return const SizedBox.shrink();

    // 2. CONTENT BUILDER
    Widget content;
    if (msg.type == 'image') {
      content = GestureDetector(
        onTap: () {
          // Future: Open Full Screen
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: msg.fileUrl ?? "",
            placeholder: (c, u) => Container(
              height: 150, width: 200, 
              color: Colors.black12, 
              child: const Center(child: CircularProgressIndicator())
            ),
            errorWidget: (c, u, e) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
            height: 200, fit: BoxFit.cover,
          ),
        ),
      );
    } else if (msg.type == 'file') {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, color: isMe ? Colors.white : Colors.blue),
          const SizedBox(width: 8),
          const Text("Attachment", style: TextStyle(decoration: TextDecoration.underline)),
        ],
      );
    } else {
      content = Text(
        msg.text, 
        style: TextStyle(
          color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
          fontSize: 15,
        )
      );
    }

    // 3. BUBBLE LAYOUT
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? primary : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
          ],
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
            content,
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg.isEdited) 
                  const Text("edited • ", style: TextStyle(fontSize: 10, color: Colors.white70)),
                Text(
                  DateFormat('h:mm a').format(msg.createdAt), 
                  style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey)
                ),
                // ✅ AUTHENTIC TICKS LOGIC
                if (isMe) ...[
                   const SizedBox(width: 4),
                   Icon(
                     msg.isRead ? Icons.done_all : Icons.check, // ✅ Check vs Done All
                     size: 14, 
                     color: msg.isRead ? Colors.lightBlueAccent : Colors.white70 // ✅ Blue if read
                   ),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.add, color: primary),
              onPressed: _showAttachmentMenu,
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : const Color(0xFFF2F4F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: 4,
                  minLines: 1,
                  decoration: const InputDecoration(
                    hintText: "Message...",
                    border: InputBorder.none,
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: primary,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: () => _sendMessage(text: _textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}