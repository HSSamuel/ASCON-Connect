import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';

// ✅ NEW IMPORTS for Audio/Selection/Zoom/PDF
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart'; 

import '../services/api_client.dart';
import '../services/socket_service.dart';
import '../models/chat_objects.dart';
import '../config.dart';
import '../config/storage_config.dart';
import '../widgets/full_screen_image.dart'; 

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
  final _storage = StorageConfig.storage;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  List<ChatMessage> _messages = [];
  String? _activeConversationId;
  String? _myUserId;
  bool _isLoading = true;

  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  bool _isTyping = false;
  Timer? _typingDebounce;
  bool _isPeerTyping = false;

  late bool _isPeerOnline;
  String? _peerLastSeen;

  // ✅ SELECTION MODE VARIABLES
  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  // ✅ AUDIO RECORDING VARIABLES
  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  String? _recordedPath;
  int _recordDuration = 0;
  Timer? _recordTimer;

  // ✅ AUDIO PLAYING VARIABLES
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingMessageId; 
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _activeConversationId = widget.conversationId;
    _isPeerOnline = widget.isOnline;
    _peerLastSeen = widget.lastSeen;

    _audioRecorder = AudioRecorder();

    _initializeChat();
    _setupScrollListener();
    _setupSocketListeners();
    _setupAudioPlayerListeners();
  }

  void _setupAudioPlayerListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        setState(() {
          _playingMessageId = null;
          _currentPosition = Duration.zero;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((p) {
      setState(() => _currentPosition = p);
    });

    _audioPlayer.onDurationChanged.listen((d) {
      setState(() => _totalDuration = d);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _typingDebounce?.cancel();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();

    if (_isTyping && _activeConversationId != null) {
      SocketService().socket?.emit('stop_typing', {
        'receiverId': widget.receiverId,
        'conversationId': _activeConversationId
      });
    }

    SocketService().socket?.off('new_message');
    SocketService().socket?.off('user_status_update');
    SocketService().socket?.off('messages_read');
    SocketService().socket?.off('messages_deleted_bulk');
    SocketService().socket?.off('typing_start');
    SocketService().socket?.off('typing_stop');

    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.hasClients && _scrollController.position.pixels == 0) {
        _loadMoreMessages();
      }
    });
  }

  void _setupSocketListeners() {
    final socket = SocketService().socket;

    socket?.on('new_message', (data) {
      if (!mounted) return;
      if (data['conversationId'] == _activeConversationId) {
        setState(() {
            try {
              _messages.add(ChatMessage.fromJson(data['message']));
              _isPeerTyping = false;
            } catch (e) {
              debugPrint("Error parsing incoming message: $e");
            }
        });
        _scrollToBottom();
        _markMessagesAsRead();
        _cacheMessages();
      }
    });

    socket?.on('user_status_update', (data) { 
      if (mounted && data['userId'] == widget.receiverId) {
        setState(() {
          _isPeerOnline = data['isOnline'];
          if (!_isPeerOnline) _peerLastSeen = data['lastSeen'];
        });
      }
    });

    socket?.on('messages_read', (data) { 
      if (mounted && data['conversationId'] == _activeConversationId) {
        setState(() {
          for (var msg in _messages) {
            if (msg.senderId == _myUserId) msg.isRead = true;
          }
        });
        _cacheMessages();
      }
    });

    socket?.on('typing_start', (data) {
       if (mounted && data['conversationId'] == _activeConversationId && data['senderId'] == widget.receiverId) {
        setState(() => _isPeerTyping = true);
      }
    });

    socket?.on('typing_stop', (data) {
      if (mounted && data['conversationId'] == _activeConversationId && data['senderId'] == widget.receiverId) {
        setState(() => _isPeerTyping = false);
      }
    });

    socket?.on('messages_deleted_bulk', (data) {
      if (mounted && data['conversationId'] == _activeConversationId) {
        List<dynamic> ids = data['messageIds'];
        setState(() {
          _messages.removeWhere((m) => ids.contains(m.id));
        });
        _cacheMessages();
      }
    });
  }

  Future<void> _initializeChat() async {
    _myUserId = await _storage.read(key: 'userId');
    if (_myUserId == null) {
      final prefs = await SharedPreferences.getInstance();
      final userString = prefs.getString('cached_user');
      if (userString != null) {
        final userData = jsonDecode(userString);
        _myUserId = userData['id'] ?? userData['_id'];
        if (_myUserId != null) await _storage.write(key: 'userId', value: _myUserId!);
      }
    }
    if (_activeConversationId != null) {
      await _loadCachedMessages();
      await _loadMessages(initial: true);
    } else {
      await _findOrCreateConversation();
    }
  }

  Future<void> _cacheMessages() async {
     if (_activeConversationId == null || _messages.isEmpty) return;
     try {
       final prefs = await SharedPreferences.getInstance();
       final msgs = _messages.length > 50 ? _messages.sublist(_messages.length - 50) : _messages;
       await prefs.setString('chat_cache_$_activeConversationId', jsonEncode(msgs.map((m)=>m.toJson()).toList()));
     } catch (e) {
       debugPrint("Cache save error: $e");
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
          _hasMoreMessages = newMessages.length >= 20;
        });
        if (initial) {
          _scrollToBottom();
          _markMessagesAsRead();
        }
        _cacheMessages();
      }
    } catch (e) { setState(() => _isLoading = false); }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _messages.isEmpty) return;
    setState(() => _isLoadingMore = true);
    String oldestId = _messages.first.id;
    try {
      final result = await _api.get('/api/chat/$_activeConversationId?beforeId=$oldestId');
      if (mounted && result['success'] == true) {
        final List<dynamic> data = result['data'];
        final olderMessages = data.map((m) => ChatMessage.fromJson(m)).toList();
        if (olderMessages.isEmpty) {
          setState(() => _hasMoreMessages = false);
        } else {
          setState(() => _messages.insertAll(0, olderMessages));
        }
      }
    } catch (e) {
      debugPrint("Pagination error: $e");
    } finally { 
      if(mounted) setState(() => _isLoadingMore = false); 
    }
  }

  Future<void> _findOrCreateConversation() async {
    try {
      final result = await _api.post('/api/chat/start', {'receiverId': widget.receiverId});
      if (mounted && result['success'] == true) {
        setState(() => _activeConversationId = result['data']['_id']);
        await _loadMessages(initial: true);
      }
    } catch (_) {}
  }

  Future<void> _markMessagesAsRead() async {
     if (_activeConversationId != null) await _api.put('/api/chat/read/$_activeConversationId', {});
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
      return "Last seen ${DateFormat('MMM d, h:mm a').format(lastSeen)}";
    } catch (e) { return "Offline"; }
  }

  // --------------------------------------------------------
  // 🎤 RECORDING LOGIC
  // --------------------------------------------------------
  Future<void> _startRecording() async {
    if (await Permission.microphone.request().isGranted) {
      try {
        if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: 50);
        
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);
        
        setState(() {
          _isRecording = true;
          _recordedPath = path;
          _recordDuration = 0;
        });

        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _recordDuration++);
        });
      } catch (e) {
        debugPrint("Recording Error: $e");
      }
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();

    setState(() => _isRecording = false);

    if (send && path != null) {
      _sendMessage(file: File(path), type: 'audio');
    }
  }

  void _cancelRecording() {
    _stopRecording(send: false);
  }

  // --------------------------------------------------------
  // 📨 SEND LOGIC (Hardened)
  // --------------------------------------------------------
  Future<void> _sendMessage({String? text, File? file, String type = 'text'}) async {
    if ((text == null || text.trim().isEmpty) && file == null) return;
    if (_activeConversationId == null || _myUserId == null) return;

    String? token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("⚠️ Session expired. Please login again.")),
       );
       return;
    }

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMessage = ChatMessage(
      id: tempId,
      senderId: _myUserId!,
      text: text ?? "",
      type: type,
      fileUrl: file?.path, 
      fileName: file?.path.split('/').last,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );

    setState(() {
      _messages.add(tempMessage);
      _textController.clear();
      _isTyping = false;
    });
    _scrollToBottom();

    try {
      final baseUrl = AppConfig.baseUrl.endsWith('/')
          ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
          : AppConfig.baseUrl;

      final url = Uri.parse('$baseUrl/api/chat/$_activeConversationId');
      
      var request = http.MultipartRequest('POST', url);
      request.headers['auth-token'] = token; 

      if (text != null && text.isNotEmpty) {
        request.fields['text'] = text;
      }
      request.fields['type'] = type;

      if (file != null) {
        if (!file.existsSync()) {
          throw Exception("File does not exist locally.");
        }
        var stream = http.ByteStream(file.openRead());
        var length = await file.length();
        var multipartFile = http.MultipartFile(
          'file',
          stream,
          length,
          filename: file.path.split('/').last,
        );
        request.files.add(multipartFile);
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final realMessage = ChatMessage.fromJson(data);

        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempId);
          if (index != -1) {
            _messages[index] = realMessage;
          }
        });
        _cacheMessages();
      } else {
        String errorMsg = "Server Error (${response.statusCode})";
        try {
          final body = jsonDecode(response.body);
          if (body['message'] != null) errorMsg = body['message'];
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint("Send Failed: $e");
      setState(() {
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          _messages[index].status = MessageStatus.error;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to send: ${e.toString().split(':').last.trim()}"), backgroundColor: Colors.red),
      );
    }
  }

  // --------------------------------------------------------
  // ✅ SELECTION & BULK ACTIONS
  // --------------------------------------------------------
  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
        _selectedMessageIds.add(messageId);
      }
    });
  }

  Future<void> _deleteSelectedMessages() async {
    final idsToDelete = _selectedMessageIds.toList();
    
    setState(() {
      _messages.removeWhere((m) => idsToDelete.contains(m.id));
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });

    try {
      await _api.post('/api/chat/delete-multiple', {'messageIds': idsToDelete});
    } catch (e) {
      debugPrint("Bulk delete failed: $e");
    }
  }

  void _copySelectedMessages() {
    final selectedMsgs = _messages.where((m) => _selectedMessageIds.contains(m.id)).toList();
    final textToCopy = selectedMsgs
        .where((m) => m.type == 'text')
        .map((m) => m.text)
        .join("\n\n");

    if (textToCopy.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: textToCopy));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied to clipboard")));
    }
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _shareSelectedMessages() {
    final selectedMsgs = _messages.where((m) => _selectedMessageIds.contains(m.id)).toList();
    final textToShare = selectedMsgs
        .where((m) => m.type == 'text')
        .map((m) => "[${DateFormat('h:mm a').format(m.createdAt)}] ${m.text}")
        .join("\n\n");
    
    if (textToShare.isNotEmpty) {
      Share.share(textToShare);
    }
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  // --------------------------------------------------------
  // 🎨 UI BUILDERS
  // --------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        if (_isSelectionMode) {
          setState(() {
            _isSelectionMode = false;
            _selectedMessageIds.clear();
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: _isSelectionMode 
          ? AppBar(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedMessageIds.clear();
                }),
              ),
              title: Text("${_selectedMessageIds.length} Selected"),
              actions: [
                IconButton(icon: const Icon(Icons.copy), onPressed: _copySelectedMessages),
                IconButton(icon: const Icon(Icons.share), onPressed: _shareSelectedMessages),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _deleteSelectedMessages),
              ],
            )
          : AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (widget.receiverProfilePic != null && widget.receiverProfilePic!.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullScreenImage(
                            imageUrl: widget.receiverProfilePic,
                            heroTag: 'chat_profile_pic', 
                          ),
                        ),
                      );
                    }
                  },
                  child: Hero(
                    tag: 'chat_profile_pic', 
                    child: CircleAvatar(
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
                  ),
                ),
                
                const SizedBox(width: 10),
                
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.receiverName, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold)),
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
            if (_isLoadingMore) 
              const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)),

            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isSelected = _selectedMessageIds.contains(msg.id);
                  
                  return GestureDetector(
                    onLongPress: () {
                       if (msg.senderId == _myUserId && !msg.isDeleted) _toggleSelection(msg.id);
                    },
                    onTap: () {
                      if (_isSelectionMode && msg.senderId == _myUserId) _toggleSelection(msg.id);
                    },
                    child: Container(
                      color: isSelected ? primaryColor.withOpacity(0.2) : Colors.transparent,
                      child: _buildMessageBubble(msg, msg.senderId == _myUserId, isDark, primaryColor),
                    ),
                  );
                },
              ),
            ),
            
            if (_isPeerTyping) 
               Padding(
                 padding: const EdgeInsets.only(left: 16, bottom: 4),
                 child: Align(alignment: Alignment.centerLeft, child: Text("Typing...", style: TextStyle(color: Colors.grey, fontSize: 12))),
               ),

            _buildInputArea(isDark, primaryColor),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------
  // 🫧 BUBBLES
  // --------------------------------------------------------
  Widget _buildMessageBubble(ChatMessage msg, bool isMe, bool isDark, Color primary) {
    if (msg.isDeleted) return const SizedBox.shrink();

    Widget content;
    
    // 1. IMAGE
    if (msg.type == 'image') {
      bool isLocal = msg.fileUrl != null && !msg.fileUrl!.startsWith('http');
      content = GestureDetector(
        onTap: () {
           if (msg.fileUrl != null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(imageUrl: msg.fileUrl!, heroTag: msg.id)));
           }
        },
        child: Hero(
          tag: msg.id,
          child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isLocal 
                ? Image.file(File(msg.fileUrl!), height: 200, width: 200, fit: BoxFit.cover)
                : CachedNetworkImage(imageUrl: msg.fileUrl!, height: 200, fit: BoxFit.cover),
          ),
        ),
      );
    
    // 2. AUDIO
    } else if (msg.type == 'audio') {
      bool isPlaying = _playingMessageId == msg.id;
      content = Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            GestureDetector(
              onTap: () async {
                if (isPlaying) {
                  await _audioPlayer.pause();
                  setState(() => _playingMessageId = null);
                } else {
                  if (msg.fileUrl != null) {
                    Source urlSource = msg.fileUrl!.startsWith('http') 
                        ? UrlSource(msg.fileUrl!) 
                        : DeviceFileSource(msg.fileUrl!);
                    await _audioPlayer.play(urlSource);
                    setState(() => _playingMessageId = msg.id);
                  }
                }
              },
              child: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 36, color: isMe ? Colors.white : primary),
            ),
            Expanded(
              child: Slider(
                value: isPlaying ? _currentPosition.inSeconds.toDouble() : 0.0,
                max: isPlaying ? _totalDuration.inSeconds.toDouble() : 1.0,
                activeColor: isMe ? Colors.white : primary,
                inactiveColor: isMe ? Colors.white38 : Colors.grey[300],
                onChanged: (val) {
                  if(isPlaying) _audioPlayer.seek(Duration(seconds: val.toInt()));
                },
              ),
            ),
          ],
        ),
      );

    // 3. ✅ FILE / PDF (VIEWER FIX)
    } else if (msg.type == 'file') {
      bool isLocal = msg.fileUrl != null && !msg.fileUrl!.startsWith('http');
      String displayName = msg.fileName ?? "Document (PDF)"; 
      
      content = GestureDetector(
        onTap: () async {
          if (!isLocal && msg.fileUrl != null) {
             Uri url = Uri.parse(msg.fileUrl!);
             
             // ✅ CRITICAL FIX: Android WebView cannot render PDFs directly.
             // We route it through Google Docs Viewer so it "Views" instead of "Downloads".
             if (Platform.isAndroid && (msg.fileUrl!.toLowerCase().endsWith('.pdf') || displayName.toLowerCase().endsWith('.pdf'))) {
                url = Uri.parse("https://docs.google.com/viewer?url=${msg.fileUrl}&embedded=true");
             }

             if (await canLaunchUrl(url)) {
               // ✅ LaunchMode.inAppWebView keeps user IN the app (No redirect feel)
               if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
                  // Fallback if WebView fails
                  await launchUrl(url, mode: LaunchMode.externalApplication);
               }
             } else {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open file.")));
             }
          } else if (isLocal) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File is uploading...")));
          }
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf, color: isMe ? Colors.white : primary, size: 30),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMe ? Colors.white : Colors.black87,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(isLocal ? "Uploading..." : "Tap to view", 
                      style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey)
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      );

    // 4. TEXT
    } else {
       content = Text.rich(
        TextSpan(
          children: _parseFormattedText(
            msg.text, 
            TextStyle(
              color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
              fontSize: 15,
            )
          )
        )
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? primary : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            content,
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (msg.isEdited) const Text("edited • ", style: TextStyle(fontSize: 10, color: Colors.white70)),
                Text(DateFormat('h:mm a').format(msg.createdAt.toLocal()), style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey)),
                if (isMe) ...[const SizedBox(width: 4), _buildStatusIcon(msg)],
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
      case MessageStatus.sending: icon = Icons.access_time; color = Colors.white70; break;
      case MessageStatus.error: icon = Icons.error_outline; color = Colors.redAccent; break;
      case MessageStatus.read: icon = Icons.done_all; color = Colors.lightBlueAccent; break;
      default: icon = msg.isRead ? Icons.done_all : Icons.check; color = msg.isRead ? Colors.lightBlueAccent : Colors.white70; break;
    }
    return Icon(icon, size: 14, color: color);
  }

  List<TextSpan> _parseFormattedText(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final RegExp exp = RegExp(r'([*_~])(.*?)\1');
    text.splitMapJoin(exp, onMatch: (Match m) {
        final String marker = m.group(1)!;
        final String content = m.group(2)!;
        TextStyle newStyle = baseStyle;
        if (marker == '*') newStyle = newStyle.copyWith(fontWeight: FontWeight.bold);
        if (marker == '_') newStyle = newStyle.copyWith(fontStyle: FontStyle.italic);
        if (marker == '~') newStyle = newStyle.copyWith(decoration: TextDecoration.underline);
        spans.add(TextSpan(text: content, style: newStyle));
        return '';
      },
      onNonMatch: (String s) { spans.add(TextSpan(text: s, style: baseStyle)); return ''; },
    );
    return spans;
  }
  
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Wrap(
        alignment: WrapAlignment.spaceEvenly,
        children: [
          _attachOption(Icons.image, Colors.purple, "Gallery", () => _pickImage(ImageSource.gallery)),
          _attachOption(Icons.camera_alt, Colors.pink, "Camera", () => _pickImage(ImageSource.camera)),
          _attachOption(Icons.insert_drive_file, Colors.blue, "Document (PDF)", _pickFile),
        ],
      ),
    );
  }
  Widget _attachOption(IconData icon, Color color, String label, VoidCallback onTap) {
    return Padding(padding: const EdgeInsets.all(16.0), child: GestureDetector(onTap: () { Navigator.pop(context); onTap(); }, child: Column(children: [CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 12))])));
  }
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image != null) _sendMessage(file: File(image.path), type: 'image');
  }
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) _sendMessage(file: File(result.files.single.path!), type: 'file');
  }
  
  Widget _buildInputArea(bool isDark, Color primary) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            if (!_isRecording)
              IconButton(icon: Icon(Icons.add, color: primary), onPressed: _showAttachmentMenu),
            
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : const Color(0xFFF2F4F5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _isRecording 
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.mic, color: Colors.red, size: 20),
                        Text(
                          "Recording... ${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')}", 
                          style: const TextStyle(fontWeight: FontWeight.bold)
                        ),
                        TextButton(onPressed: _cancelRecording, child: const Text("Cancel", style: TextStyle(color: Colors.red)))
                      ],
                    )
                  : TextField(
                      controller: _textController,
                      maxLines: 4, minLines: 1,
                      onChanged: (val) {
                        setState((){});
                        if (val.isNotEmpty) {
                           if (!_isTyping) { _isTyping = true; SocketService().socket?.emit('typing', {'receiverId': widget.receiverId, 'conversationId': _activeConversationId}); }
                           _typingDebounce?.cancel();
                           _typingDebounce = Timer(const Duration(seconds: 2), () { _isTyping = false; SocketService().socket?.emit('stop_typing', {'receiverId': widget.receiverId, 'conversationId': _activeConversationId}); });
                        }
                      },
                      decoration: const InputDecoration(hintText: "Message...", border: InputBorder.none),
                      textCapitalization: TextCapitalization.sentences,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            
            CircleAvatar(
              backgroundColor: primary,
              child: IconButton(
                icon: Icon(
                  (_textController.text.trim().isNotEmpty || _isRecording) ? Icons.send : Icons.mic, 
                  color: Colors.white, size: 20
                ),
                onPressed: () {
                  if (_isRecording) {
                    _stopRecording(send: true);
                  } else if (_textController.text.trim().isNotEmpty) {
                    _sendMessage(text: _textController.text);
                  } else {
                    _startRecording();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}