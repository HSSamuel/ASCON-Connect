import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:file_picker/file_picker.dart';   
import 'dart:convert';
import 'dart:async'; // For Timer
import 'dart:io';
import 'package:http/http.dart' as http; 
import 'package:cached_network_image/cached_network_image.dart';

import '../services/api_client.dart';
import '../services/socket_service.dart';
import '../models/chat_objects.dart';
import '../config.dart';

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String receiverId;
  final String receiverName;
  final String? receiverProfilePic;
  final bool isOnline;              
  final String? lastSeen;           

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
  
  // ✅ VERSION 2.0: Pagination & Typing Variables
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  bool _isTyping = false;
  Timer? _typingDebounce;
  bool _isPeerTyping = false;

  late bool _isPeerOnline;
  String? _peerLastSeen;

  @override
  void initState() {
    super.initState();
    _activeConversationId = widget.conversationId;
    _isPeerOnline = widget.isOnline;
    _peerLastSeen = widget.lastSeen;

    _initializeChat();
    _setupScrollListener();
    _setupSocketListeners();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Trigger pagination when reaching the top of the list
      if (_scrollController.hasClients && _scrollController.position.pixels == 0) { 
         _loadMoreMessages();
      }
    });
  }

  void _setupSocketListeners() {
    final socket = SocketService().socket;

    // 1. New Messages
    socket?.on('new_message', (data) { // ✅ FIX: Added ?.
      if (!mounted) return;
      if (data['conversationId'] == _activeConversationId) {
        setState(() {
           try {
             _messages.add(ChatMessage.fromJson(data['message']));
             _isPeerTyping = false; // Hide typing indicator if message arrives
           } catch (e) {
             debugPrint("Error parsing incoming message: $e");
           }
        });
        _scrollToBottom();
        _markMessagesAsRead();
        _cacheMessages(); // Update local cache
      }
    });

    // 2. Status Updates (Online/Offline)
    socket?.on('user_status_update', (data) { // ✅ FIX: Added ?.
      if (mounted && data['userId'] == widget.receiverId) {
        setState(() {
          _isPeerOnline = data['isOnline'];
          if (!_isPeerOnline) {
             _peerLastSeen = data['lastSeen'];
          }
        });
      }
    });

    // 3. Read Receipts
    socket?.on('messages_read', (data) { // ✅ FIX: Added ?.
      if (mounted && data['conversationId'] == _activeConversationId) {
        setState(() {
          for (var msg in _messages) {
            if (msg.senderId == _myUserId) {
              msg.isRead = true;
            }
          }
        });
        _cacheMessages();
      }
    });

    // 4. Message Deleted (Real-time Sync)
    socket?.on('message_deleted', (data) { // ✅ FIX: Added ?.
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == data['messageId']);
        });
        _cacheMessages();
      }
    });

    // ✅ 5. Typing Indicators
    socket?.on('typing_start', (data) { // ✅ FIX: Added ?.
      if (mounted && data['conversationId'] == _activeConversationId && data['senderId'] == widget.receiverId) {
        setState(() => _isPeerTyping = true);
      }
    });

    socket?.on('typing_stop', (data) { // ✅ FIX: Added ?.
      if (mounted && data['conversationId'] == _activeConversationId && data['senderId'] == widget.receiverId) {
        setState(() => _isPeerTyping = false);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _typingDebounce?.cancel();
    
    // Stop typing notification on exit
    if (_isTyping && _activeConversationId != null) {
       SocketService().socket?.emit('stop_typing', { // ✅ FIX: Added ?.
        'receiverId': widget.receiverId,
        'conversationId': _activeConversationId
      });
    }

    // Remove listeners to prevent memory leaks
    SocketService().socket?.off('new_message'); // ✅ FIX: Added ?.
    SocketService().socket?.off('user_status_update'); // ✅ FIX: Added ?.
    SocketService().socket?.off('messages_read'); // ✅ FIX: Added ?.
    SocketService().socket?.off('message_deleted'); // ✅ FIX: Added ?.
    SocketService().socket?.off('typing_start'); // ✅ FIX: Added ?.
    SocketService().socket?.off('typing_stop'); // ✅ FIX: Added ?.

    super.dispose();
  }

  // --------------------------------------------------------
  // 🛠️ DATA INIT, CACHING & PAGINATION
  // --------------------------------------------------------

  Future<void> _initializeChat() async {
    // 1. Get User ID
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

    // ✅ 2. LOAD CACHE FIRST (Instant UI)
    if (_activeConversationId != null) {
      await _loadCachedMessages();
    }

    // 3. FETCH FROM NETWORK
    if (_activeConversationId != null) {
      await _loadMessages(initial: true);
    } else {
      await _findOrCreateConversation();
    }
  }

  // ✅ LOCAL CACHE: Save last 50 messages to SharedPrefs
  Future<void> _cacheMessages() async {
    if (_activeConversationId == null || _messages.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Cache only the latest 50 messages to keep storage light
      final messagesToCache = _messages.length > 50 
          ? _messages.sublist(_messages.length - 50) 
          : _messages;
          
      final String jsonString = jsonEncode(messagesToCache.map((m) => m.toJson()).toList());
      await prefs.setString('chat_cache_$_activeConversationId', jsonString);
    } catch (e) {
      debugPrint("Caching error: $e");
    }
  }

  Future<void> _loadCachedMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('chat_cache_$_activeConversationId');
      
      if (jsonString != null && mounted) {
        final List<dynamic> data = jsonDecode(jsonString);
        setState(() {
          _messages = data.map((m) => ChatMessage.fromJson(m)).toList();
          _isLoading = false; 
        });
        // Scroll to bottom after build
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } catch (e) {
      debugPrint("Cache load error: $e");
    }
  }

  Future<void> _loadMessages({bool initial = false}) async {
    if (_activeConversationId == null) return;
    try {
      final result = await _api.get('/api/chat/$_activeConversationId');
      
      if (mounted && result['success'] == true) {
        final List<dynamic> data = result['data'];
        final newMessages = data.map((m) => ChatMessage.fromJson(m)).toList();

        setState(() {
          _messages = newMessages; 
          _isLoading = false;
          // If less than 20 messages returned, we assume we reached the start
          _hasMoreMessages = newMessages.length >= 20; 
        });
        
        if (initial) {
          _scrollToBottom();
          _markMessagesAsRead(); 
        }
        _cacheMessages(); // Sync cache with fresh data
      }
    } catch (e) {
      debugPrint("Network load error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ PAGINATION: Load older messages
  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _messages.isEmpty) return;

    setState(() => _isLoadingMore = true);
    
    // Use ID of the top-most message for pagination cursor
    String oldestId = _messages.first.id;

    try {
      final result = await _api.get('/api/chat/$_activeConversationId?beforeId=$oldestId');
      
      if (mounted && result['success'] == true) {
        final List<dynamic> data = result['data'];
        final olderMessages = data.map((m) => ChatMessage.fromJson(m)).toList();

        if (olderMessages.isEmpty) {
          setState(() => _hasMoreMessages = false);
        } else {
          setState(() {
            _messages.insertAll(0, olderMessages); // Prepend to top
          });
        }
      }
    } catch (e) {
      debugPrint("Pagination error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _findOrCreateConversation() async {
    try {
      final result = await _api.post('/api/chat/start', {'receiverId': widget.receiverId});
      
      if (mounted && result['success'] == true && result['data'] != null) {
        setState(() {
          _activeConversationId = result['data']['_id'];
        });
        await _loadMessages(initial: true);
      }
    } catch (e) {
      debugPrint("Error finding chat: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markMessagesAsRead() async {
    if (_activeConversationId == null) return;
    try {
      await _api.put('/api/chat/read/$_activeConversationId', {});
    } catch (e) { /* Fail silently */ }
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

  // ✅ DYNAMIC STATUS TEXT
  String _getStatusText() {
    if (_isPeerTyping) return "Typing..."; 
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
  // 🚀 SENDING & OPTIMISTIC UI
  // --------------------------------------------------------

  Future<void> _sendMessage({String? text, File? file, String type = 'text'}) async {
    if ((text == null || text.trim().isEmpty) && file == null) return;
    if (_activeConversationId == null || _myUserId == null) return;

    // 1. Create Temporary Message (Optimistic)
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMessage = ChatMessage(
      id: tempId,
      senderId: _myUserId!,
      text: text ?? "",
      type: type,
      fileUrl: file?.path, // Store local path for immediate display
      createdAt: DateTime.now(),
      status: MessageStatus.sending, // ✅ Shows Clock Icon
    );

    // 2. Update UI Immediately
    setState(() {
      _messages.add(tempMessage);
      _textController.clear();
      _isTyping = false; // Reset typing logic
    });
    _scrollToBottom();

    // 3. Send to API
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
        final realMessage = ChatMessage.fromJson(data);
        
        setState(() {
          // Replace temp message with real one from server
          final index = _messages.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            _messages[index] = realMessage; 
          }
        });
        _cacheMessages(); // Update cache with confirmed message
      } else {
        throw Exception("Failed to send");
      }
    } catch (e) {
      debugPrint("Send failed: $e");
      setState(() {
        // Mark as error in UI
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          _messages[index].status = MessageStatus.error;
        }
      });
    }
  }

  // ✅ TYPING HANDLER
  void _onTextChanged(String value) {
    if (_activeConversationId == null) return;

    if (!_isTyping) {
      _isTyping = true;
      // ✅ FIX: Safe access with ?.
      SocketService().socket?.emit('typing', {
        'receiverId': widget.receiverId,
        'conversationId': _activeConversationId
      });
    }

    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      _isTyping = false;
      // ✅ FIX: Safe access with ?.
      SocketService().socket?.emit('stop_typing', {
        'receiverId': widget.receiverId,
        'conversationId': _activeConversationId
      });
    });
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
    // Optimistic UI Update
    setState(() {
      _messages.removeWhere((m) => m.id == msg.id);
    });
    _cacheMessages();

    try {
      await _api.delete('/api/chat/message/${msg.id}'); 
    } catch (e) {
      debugPrint("Delete failed on server: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete message")));
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
              _cacheMessages();
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
                // ✅ DYNAMIC STATUS
                Text(
                  _getStatusText(), 
                  style: TextStyle(
                    fontSize: 11, 
                    color: _isPeerTyping ? Colors.white : (_isPeerOnline ? Colors.greenAccent : Colors.white70),
                    fontWeight: (_isPeerTyping || _isPeerOnline) ? FontWeight.w600 : FontWeight.normal
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
          // Loading Indicator for Pagination
          if (_isLoadingMore) 
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return GestureDetector(
                  onLongPress: () => _showMessageOptions(msg), 
                  child: _buildMessageBubble(msg, msg.senderId == _myUserId, isDark, primaryColor),
                );
              },
            ),
          ),
          
          // Typing Indicator at bottom left
          if (_isPeerTyping) 
             Padding(
               padding: const EdgeInsets.only(left: 16, bottom: 4),
               child: Align(
                 alignment: Alignment.centerLeft, 
                 child: Text("Typing...", style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic))
               ),
             ),
             
          _buildInputArea(isDark, primaryColor),
        ],
      ),
    );
  }

  // --------------------------------------------------------
  // 🎨 WIDGETS
  // --------------------------------------------------------

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, bool isDark, Color primary) {
    // 1. DELETED MESSAGE (Return Empty SizedBox to hide completely since we use Hard Delete)
    if (msg.isDeleted) return const SizedBox.shrink();

    // 2. CONTENT BUILDER
    Widget content;
    if (msg.type == 'image') {
      // ✅ Handle Local File (Optimistic) vs Network Image
      bool isLocal = msg.fileUrl != null && !msg.fileUrl!.startsWith('http');
      
      content = GestureDetector(
        onTap: () {
          // Future: Open Full Screen
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isLocal 
            ? Image.file(File(msg.fileUrl!), height: 200, width: 200, fit: BoxFit.cover)
            : CachedNetworkImage(
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
                // ✅ OPTIMISTIC STATUS ICONS
                if (isMe) ...[
                   const SizedBox(width: 4),
                   _buildStatusIcon(msg),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(ChatMessage msg) {
    IconData icon;
    Color color;

    switch (msg.status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        color = Colors.white70;
        break;
      case MessageStatus.error:
        icon = Icons.error_outline;
        color = Colors.redAccent;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.lightBlueAccent;
        break;
      case MessageStatus.delivered:
      case MessageStatus.sent:
      default:
        icon = msg.isRead ? Icons.done_all : Icons.check;
        color = msg.isRead ? Colors.lightBlueAccent : Colors.white70;
        break;
    }

    return Icon(icon, size: 14, color: color);
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
                  onChanged: _onTextChanged, // ✅ Detect typing
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