import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
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

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
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
  final FocusNode _focusNode = FocusNode(); 

  List<ChatMessage> _messages = [];
  String? _activeConversationId;
  String? _myUserId;
  
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  bool _isTyping = false;
  Timer? _typingDebounce;
  bool _isPeerTyping = false;

  late bool _isPeerOnline;
  String? _peerLastSeen;

  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  // ✅ Reply & Edit State
  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;

  // Audio Recording
  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;

  // Audio Playing
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingMessageId; 
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  // Track downloading file
  String? _downloadingFileId;

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

    // ✅ ROBUST RETRY: Check status again after 1.5s
    // This catches cases where socket was connecting when screen opened (Notifications)
    Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
         final socket = SocketService().socket;
         if (socket != null && socket.connected) {
           socket.emit('check_user_status', {'userId': widget.receiverId});
         }
      }
    });
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
    _focusNode.dispose(); 
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
    // ✅ NEW LISTENER
    SocketService().socket?.off('user_status_result');

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
    
    // ✅ SAFETY CHECK: If socket not initialized yet, force it.
    if (socket == null) {
      SocketService().initSocket();
      Future.delayed(const Duration(milliseconds: 500), _setupSocketListeners);
      return;
    }

    // ✅ 1. Active Check Function
    void checkStatus() {
      // debugPrint("🔍 Checking status for: ${widget.receiverId}");
      socket.emit('check_user_status', {'userId': widget.receiverId});
    }

    // ✅ 2. Trigger check immediately if connected
    if (socket.connected) {
      checkStatus();
    }

    // ✅ 3. Trigger check on reconnection 
    socket.on('connect', (_) => checkStatus());
    socket.on('reconnect', (_) => checkStatus());

    // ✅ 4. Listen for Status Result
    socket.on('user_status_result', (data) {
      if (!mounted) return;
      if (data['userId'] == widget.receiverId) {
        setState(() {
          _isPeerOnline = data['isOnline'];
          if (!_isPeerOnline) _peerLastSeen = data['lastSeen'];
        });
      }
    });

    socket.on('new_message', (data) {
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

    socket.on('user_status_update', (data) { 
      if (mounted && data['userId'] == widget.receiverId) {
        setState(() {
          _isPeerOnline = data['isOnline'];
          if (!_isPeerOnline) _peerLastSeen = data['lastSeen'];
        });
      }
    });

    socket.on('messages_read', (data) { 
      if (mounted && data['conversationId'] == _activeConversationId) {
        setState(() {
          for (var msg in _messages) {
            if (msg.senderId == _myUserId) msg.isRead = true;
          }
        });
        _cacheMessages();
      }
    });

    socket.on('typing_start', (data) {
       if (mounted && data['conversationId'] == _activeConversationId && data['senderId'] == widget.receiverId) {
        setState(() => _isPeerTyping = true);
      }
    });

    socket.on('typing_stop', (data) {
      if (mounted && data['conversationId'] == _activeConversationId && data['senderId'] == widget.receiverId) {
        setState(() => _isPeerTyping = false);
      }
    });

    socket.on('messages_deleted_bulk', (data) {
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
          _hasMoreMessages = newMessages.length >= 20;
        });
        if (initial) {
          _scrollToBottom();
          _markMessagesAsRead();
        }
        _cacheMessages();
      }
    } catch (e) { 
      debugPrint("Load error: $e");
    }
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

  // ✅ UPDATED STATUS TEXT LOGIC (From Alumni Detail Screen)
  String _getStatusText() {
    if (_isPeerTyping) return "Typing...";
    if (_isPeerOnline) return "Active Now";
    if (_peerLastSeen == null) return "Offline";
    
    try {
      final lastSeen = DateTime.parse(_peerLastSeen!).toLocal();
      final now = DateTime.now();
      final diff = now.difference(lastSeen);

      if (diff.inMinutes < 1) return "Last seen just now";
      if (diff.inMinutes < 60) return "Last seen ${diff.inMinutes}m ago";
      
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
  // 🎤 RECORDING LOGIC
  // --------------------------------------------------------
  Future<void> _startRecording() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Voice recording not supported on Web yet.")));
      return;
    }

    if (await Permission.microphone.request().isGranted) {
      try {
        if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: 50);
        
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);
        
        setState(() {
          _isRecording = true;
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
      _sendMessage(filePath: path, type: 'audio');
    }
  }

  void _cancelRecording() {
    _stopRecording(send: false);
  }

  // --------------------------------------------------------
  // 📂 SMART DOWNLOAD & OPEN (Caches Files)
  // --------------------------------------------------------
  Future<void> _downloadAndOpenWith(String url, String fileName, String messageId) async {
    // 1. Web: Just launch URL
    if (kIsWeb) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      return;
    }

    try {
      // 2. Get Local Path
      final tempDir = await getTemporaryDirectory();
      final safeName = fileName.replaceAll(RegExp(r'[^\w\s\.]'), '_'); 
      final file = File('${tempDir.path}/$safeName');

      // ✅ 3. CHECK: Does file already exist?
      if (await file.exists()) {
        debugPrint("📂 Opening cached file: ${file.path}");
        final result = await OpenFile.open(file.path);
        
        if (result.type != ResultType.done) {
           _shareFile(file.path, fileName);
        }
        return; 
      }

      // 4. Download (Only if file doesn't exist)
      setState(() => _downloadingFileId = messageId);
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode != 200) {
        throw Exception("Server Error ${response.statusCode}");
      }
      
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        setState(() => _downloadingFileId = null);
        
        final result = await OpenFile.open(file.path);
        if (result.type != ResultType.done) {
           _shareFile(file.path, fileName);
        }
      }
    } catch (e) {
      debugPrint("Download Error: $e");
      if (mounted) {
        setState(() => _downloadingFileId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open file: ${e.toString().split(':').last.trim()}"))
        );
      }
    }
  }

  // Helper for fallback sharing
  void _shareFile(String path, String text) {
    Share.shareXFiles([XFile(path)], text: 'Open $text');
  }

  // --------------------------------------------------------
  // 💾 DOWNLOAD & SAVE (Explicit User Action)
  // --------------------------------------------------------
  Future<void> _downloadAndSave(String url, String fileName, String messageId) async {
    if (kIsWeb) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final safeName = fileName.replaceAll(RegExp(r'[^\w\s\.]'), '_');
      final file = File('${tempDir.path}/$safeName');

      if (!await file.exists()) {
        setState(() => _downloadingFileId = messageId);
        
        final response = await http.get(Uri.parse(url));
        if (response.statusCode != 200) throw Exception("Download Failed");
        
        await file.writeAsBytes(response.bodyBytes);
        
        if (mounted) setState(() => _downloadingFileId = null);
      }

      await Share.shareXFiles([XFile(file.path)], text: 'Save $fileName');

    } catch (e) {
      debugPrint("Save Error: $e");
      if (mounted) {
        setState(() => _downloadingFileId = null);
      }
    }
  }

  // --------------------------------------------------------
  // 📨 SEND LOGIC
  // --------------------------------------------------------
  Future<void> _sendMessage({
    String? text, 
    String? filePath, 
    Uint8List? fileBytes, 
    String? fileName, 
    String type = 'text'
  }) async {
    if ((text == null || text.trim().isEmpty) && filePath == null && fileBytes == null) return;
    if (_activeConversationId == null || _myUserId == null) return;

    // ✅ EDIT MODE LOGIC
    if (_editingMessage != null && type == 'text') {
      try {
        final baseUrl = AppConfig.baseUrl.endsWith('/')
            ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
            : AppConfig.baseUrl;
        
        final url = Uri.parse('$baseUrl/api/chat/message/${_editingMessage!.id}');
        String? token = await _storage.read(key: 'auth_token');
        
        final response = await http.put(
          url, 
          headers: {'auth-token': token!, 'Content-Type': 'application/json'},
          body: jsonEncode({'text': text})
        );
        
        if (response.statusCode == 200) {
          setState(() {
            _editingMessage!.text = text!;
            _editingMessage!.isEdited = true;
            _editingMessage = null;
            _textController.clear();
          });
        }
      } catch (e) {
        debugPrint("Edit Failed: $e");
      }
      return;
    }

    String? token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text("⚠️ Session expired. Please login again.")),
       );
       return;
    }

    // Optimistic UI
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMessage = ChatMessage(
      id: tempId,
      senderId: _myUserId!,
      text: text ?? "",
      type: type,
      fileUrl: filePath, 
      fileName: fileName ?? (filePath != null ? filePath.split('/').last : "File"),
      localBytes: fileBytes, 
      // ✅ Add Reply Info Optimistically
      replyToId: _replyingTo?.id,
      replyToText: _replyingTo?.text,
      replyToSenderName: _replyingTo != null ? (_replyingTo!.senderId == _myUserId ? "You" : widget.receiverName) : null,
      replyToType: _replyingTo?.type,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );

    setState(() {
      _messages.add(tempMessage);
      _textController.clear();
      _isTyping = false;
      // ✅ Clear Reply State
      _replyingTo = null;
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
      
      // ✅ Add Reply ID to Request
      if (tempMessage.replyToId != null) {
        request.fields['replyToId'] = tempMessage.replyToId!;
      }

      if (fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file', 
          fileBytes, 
          filename: fileName ?? 'upload'
        ));
      } else if (filePath != null) {
        if (!File(filePath).existsSync()) {
          throw Exception("File does not exist locally.");
        }
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
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
  // ✅ ATTACHMENT PICKERS
  // --------------------------------------------------------
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        _sendMessage(fileBytes: bytes, fileName: image.name, type: 'image');
      } else {
        _sendMessage(filePath: image.path, type: 'image');
      }
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
    
    if (result != null) {
      if (kIsWeb) {
        PlatformFile file = result.files.first;
        if (file.bytes != null) {
          _sendMessage(fileBytes: file.bytes, fileName: file.name, type: 'file');
        }
      } else {
        if (result.files.single.path != null) {
          _sendMessage(filePath: result.files.single.path!, type: 'file');
        }
      }
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
    if (kIsWeb) {
       _copySelectedMessages(); 
       return;
    }
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

    // ✅ WRAP IN DISMISSIBLE FOR SWIPE-TO-REPLY
    return Dismissible(
      key: Key(msg.id),
      direction: DismissDirection.startToEnd, // Swipe Left-to-Right
      confirmDismiss: (direction) async {
        setState(() {
          _replyingTo = msg;
          _editingMessage = null; // Cancel edit if replying
        });
        Vibration.vibrate(duration: 50);
        _focusNode.requestFocus(); // Auto-focus input
        return false; // Do not dismiss
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(Icons.reply_rounded, color: isDark ? Colors.white70 : Colors.grey[700]),
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          // ✅ ADD EDIT TO LONG PRESS (Only for my text messages)
          onLongPress: () {
            if (!isMe || _isSelectionMode) return;
            
            showModalBottomSheet(context: context, builder: (c) => Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.reply), 
                  title: const Text("Reply"), 
                  onTap: () { 
                    Navigator.pop(c); 
                    setState(() {
                      _replyingTo = msg;
                      _editingMessage = null;
                    });
                    _focusNode.requestFocus();
                  }
                ),
                if (msg.type == 'text') 
                  ListTile(
                    leading: const Icon(Icons.edit), 
                    title: const Text("Edit"), 
                    onTap: () { 
                      Navigator.pop(c); 
                      setState(() {
                        _editingMessage = msg;
                        _replyingTo = null;
                        _textController.text = msg.text;
                      }); 
                      _focusNode.requestFocus();
                    }
                  ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red), 
                  title: const Text("Delete", style: TextStyle(color: Colors.red)), 
                  onTap: () { 
                    Navigator.pop(c); 
                    _toggleSelection(msg.id); 
                    _deleteSelectedMessages(); 
                  }
                ),
              ],
            ));
          },
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: isMe ? primary : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ RENDER QUOTED REPLY
                if (msg.replyToId != null) 
                  _buildReplyPreviewInBubble(msg, isMe, isDark, primary),

                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildMessageContent(msg, isMe, isDark, primary),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ HELPER: Reply Preview inside Bubble
  Widget _buildReplyPreviewInBubble(ChatMessage msg, bool isMe, bool isDark, Color primary) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(8),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: isMe ? Colors.white : primary, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg.replyToSenderName ?? "User",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isMe ? Colors.white70 : primary)
          ),
          const SizedBox(height: 2),
          Text(
            msg.replyToType == 'text' ? (msg.replyToText ?? "") : "Media Attachment",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: isMe ? Colors.white60 : Colors.grey[700])
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(ChatMessage msg, bool isMe, bool isDark, Color primary) {
    if (msg.type == 'image') {
      if (msg.localBytes != null) return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(msg.localBytes!, height: 200, width: 200, fit: BoxFit.cover));
      if (msg.fileUrl != null && !msg.fileUrl!.startsWith('http')) return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(msg.fileUrl!), height: 200, width: 200, fit: BoxFit.cover));
      return GestureDetector(onTap: () { if (msg.fileUrl != null) Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(imageUrl: msg.fileUrl!, heroTag: msg.id))); }, child: Hero(tag: msg.id, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: CachedNetworkImage(imageUrl: msg.fileUrl!, height: 200, fit: BoxFit.cover))));
    }
    
    if (msg.type == 'audio') {
      bool isPlaying = _playingMessageId == msg.id;
      return Container(width: 200, padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [GestureDetector(onTap: () async { if (isPlaying) { await _audioPlayer.pause(); setState(() => _playingMessageId = null); } else { if (msg.fileUrl != null) { Source urlSource = msg.fileUrl!.startsWith('http') ? UrlSource(msg.fileUrl!) : DeviceFileSource(msg.fileUrl!); await _audioPlayer.play(urlSource); setState(() => _playingMessageId = msg.id); } } }, child: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 36, color: isMe ? Colors.white : primary)), Expanded(child: Slider(value: isPlaying ? _currentPosition.inSeconds.toDouble() : 0.0, max: isPlaying ? _totalDuration.inSeconds.toDouble() : 1.0, activeColor: isMe ? Colors.white : primary, inactiveColor: isMe ? Colors.white38 : Colors.grey[300], onChanged: (val) { if(isPlaying) _audioPlayer.seek(Duration(seconds: val.toInt())); }))]));
    }

    if (msg.type == 'file') {
      bool isDownloading = _downloadingFileId == msg.id;
      return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [GestureDetector(onTap: () => _downloadAndOpenWith(msg.fileUrl!, msg.fileName ?? "Doc", msg.id), child: Icon(Icons.description, color: isMe ? Colors.white : primary, size: 30)), const SizedBox(width: 8), Flexible(child: GestureDetector(onTap: () => _downloadAndOpenWith(msg.fileUrl!, msg.fileName ?? "Doc", msg.id), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(msg.fileName ?? "Document", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.white : Colors.black87, decoration: TextDecoration.underline)), const SizedBox(height: 2), Text(isDownloading ? "Downloading..." : "Tap to open", style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey))]))), if (!isDownloading) InkWell(onTap: () => _downloadAndSave(msg.fileUrl!, msg.fileName ?? "Doc", msg.id), borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.all(6.0), child: Icon(Icons.download_rounded, color: isMe ? Colors.white70 : Colors.grey, size: 20))), if (isDownloading) const Padding(padding: EdgeInsets.only(left: 8.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))]));
    }

    return Text.rich(TextSpan(children: _parseFormattedText(msg.text, TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87), fontSize: 15))));
  }

  Widget _buildStatusIcon(ChatMessage msg) {
    IconData icon; Color color;
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
        final String marker = m.group(1)!; final String content = m.group(2)!;
        TextStyle newStyle = baseStyle;
        if (marker == '*') newStyle = newStyle.copyWith(fontWeight: FontWeight.bold);
        if (marker == '_') newStyle = newStyle.copyWith(fontStyle: FontStyle.italic);
        if (marker == '~') newStyle = newStyle.copyWith(decoration: TextDecoration.underline);
        spans.add(TextSpan(text: content, style: newStyle));
        return '';
      }, onNonMatch: (String s) { spans.add(TextSpan(text: s, style: baseStyle)); return ''; },
    );
    return spans;
  }
  
  void _showAttachmentMenu() {
    showModalBottomSheet(context: context, builder: (context) => Wrap(alignment: WrapAlignment.spaceEvenly, children: [_attachOption(Icons.image, Colors.purple, "Gallery", () => _pickImage(ImageSource.gallery)), _attachOption(Icons.camera_alt, Colors.pink, "Camera", () => _pickImage(ImageSource.camera)), _attachOption(Icons.insert_drive_file, Colors.blue, "Document (PDF)", _pickFile)]));
  }
  
  Widget _attachOption(IconData icon, Color color, String label, VoidCallback onTap) {
    return Padding(padding: const EdgeInsets.all(16.0), child: GestureDetector(onTap: () { Navigator.pop(context); onTap(); }, child: Column(children: [CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 12))])));
  }
  
  Widget _buildInputArea(bool isDark, Color primary) {
    return Column(
      children: [
        // ✅ REPLY / EDIT PREVIEW BAR
        if (_replyingTo != null || _editingMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            child: Row(
              children: [
                Icon(_editingMessage != null ? Icons.edit : Icons.reply, color: primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _editingMessage != null ? "Editing Message" : "Replying to ${_replyingTo!.senderId == _myUserId ? 'Yourself' : 'User'}",
                        style: TextStyle(fontWeight: FontWeight.bold, color: primary),
                      ),
                      Text(
                        _editingMessage != null ? _editingMessage!.text : (_replyingTo!.type == 'text' ? _replyingTo!.text : "Media"),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () { setState(() { _replyingTo = null; _editingMessage = null; _textController.clear(); }); })
              ],
            ),
          ),

        // STANDARD INPUT
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: SafeArea(
            child: Row(
              children: [
                if (!_isRecording && !kIsWeb) IconButton(icon: Icon(Icons.add, color: primary), onPressed: _showAttachmentMenu),
                if (kIsWeb) IconButton(icon: Icon(Icons.add, color: primary), onPressed: _showAttachmentMenu),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: isDark ? Colors.grey[900] : const Color(0xFFF2F4F5), borderRadius: BorderRadius.circular(24)),
                    child: _isRecording 
                      ? Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Icon(Icons.mic, color: Colors.red, size: 20), Text("Recording... ${_recordDuration ~/ 60}:${(_recordDuration % 60).toString().padLeft(2, '0')}", style: const TextStyle(fontWeight: FontWeight.bold)), TextButton(onPressed: _cancelRecording, child: const Text("Cancel", style: TextStyle(color: Colors.red)))])
                      : TextField(
                          controller: _textController, focusNode: _focusNode, // ✅ Attach Focus Node
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
                    icon: Icon((_textController.text.trim().isNotEmpty || _isRecording || kIsWeb) ? Icons.send : Icons.mic, color: Colors.white, size: 20),
                    onPressed: () {
                      if (_isRecording) { _stopRecording(send: true); }
                      else if (_textController.text.trim().isNotEmpty) { _sendMessage(text: _textController.text); }
                      else if (!kIsWeb) { _startRecording(); }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}