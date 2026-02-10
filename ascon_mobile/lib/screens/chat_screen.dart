import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart'; 

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
import '../utils/presence_formatter.dart';
import 'group_info_screen.dart'; 

// ✅ IMPORT EXISTING WIDGET
import '../widgets/full_screen_image.dart';

// Check if these exist in your project, otherwise comment them out temporarily
import '../widgets/chat/poll_creation_sheet.dart';
import '../widgets/active_poll_card.dart';

class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String receiverId;
  final String receiverName;
  final String? receiverProfilePic;
  final bool isOnline;
  final String? lastSeen;
  final bool isGroup; 
  final String? groupId; 

  const ChatScreen({
    super.key,
    this.conversationId,
    required this.receiverId,
    required this.receiverName,
    this.receiverProfilePic,
    this.isOnline = false,
    this.lastSeen,
    this.isGroup = false, 
    this.groupId,
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
  
  Timer? _statusPollingTimer;
  StreamSubscription? _statusSubscription;

  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};

  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;

  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingMessageId; 
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  String? _downloadingFileId;
  List<String> _groupAdminIds = [];

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

    if (widget.isGroup && widget.groupId != null) {
      SocketService().socket?.emit('join_room', widget.groupId);
      _fetchGroupAdmins();
    } else if (!_isPeerOnline) {
      _startStatusPolling();
    }
    
    if (!widget.isGroup) {
      _statusSubscription = SocketService().userStatusStream.listen((data) {
        if (!mounted) return;
        if (data['userId'] == widget.receiverId) {
          setState(() {
            _isPeerOnline = data['isOnline'];
            if (!_isPeerOnline && data['lastSeen'] != null) {
              _peerLastSeen = data['lastSeen'];
            }
            if (_isPeerOnline) {
              _statusPollingTimer?.cancel();
            }
          });
        }
      });
    }
  }

  Future<void> _fetchGroupAdmins() async {
    try {
      final result = await _api.get('/api/groups/${widget.groupId}/info');
      if (mounted && result['success'] == true) {
        final data = result['data'];
        final List<dynamic> admins = data['admins'] ?? [];
        setState(() {
          _groupAdminIds = admins.map((e) => e.toString()).toList();
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch group admins: $e");
    }
  }

  void _startStatusPolling() {
    _checkStatusSafe();
    _statusPollingTimer?.cancel();
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_isPeerOnline || !mounted) {
        timer.cancel(); 
      } else if (timer.tick > 5) {
        timer.cancel(); 
      } else {
        _checkStatusSafe();
      }
    });
  }

  void _checkStatusSafe() {
    if(!widget.isGroup) SocketService().checkUserStatus(widget.receiverId);
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
    _audioPlayer.onPositionChanged.listen((p) => setState(() => _currentPosition = p));
    _audioPlayer.onDurationChanged.listen((d) => setState(() => _totalDuration = d));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose(); 
    _typingDebounce?.cancel();
    _recordTimer?.cancel();
    _statusPollingTimer?.cancel(); 
    _statusSubscription?.cancel(); 
    _audioRecorder.dispose();
    _audioPlayer.dispose();

    if (_isTyping && _activeConversationId != null) {
      SocketService().socket?.emit('stop_typing', {
        'receiverId': widget.receiverId,
        'conversationId': _activeConversationId,
        'groupId': widget.isGroup ? widget.groupId : null
      });
    }

    if (widget.isGroup && widget.groupId != null) {
      SocketService().socket?.emit('leave_room', widget.groupId);
    }

    SocketService().socket?.off('new_message');
    SocketService().socket?.off('messages_read');
    SocketService().socket?.off('messages_deleted_bulk');
    SocketService().socket?.off('typing_start');
    SocketService().socket?.off('typing_stop');
    SocketService().socket?.off('removed_from_group');

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
    if (socket == null) {
      SocketService().initSocket();
      Future.delayed(const Duration(milliseconds: 500), _setupSocketListeners);
      return;
    }

    socket.on('new_message', (data) {
      if (!mounted) return;
      if (data['conversationId'] == _activeConversationId) {
        setState(() {
            try {
              final newMessage = ChatMessage.fromJson(data['message']);
              if (newMessage.senderId == _myUserId) return; 
              if (_messages.any((m) => m.id == newMessage.id)) return;

              _messages.add(newMessage);
              _isPeerTyping = false;
            } catch (e) {
              debugPrint("Error parsing incoming message: $e");
            }
        });
        _scrollToBottom();
        _markMessagesAsRead();
      }
    });

    socket.on('messages_read', (data) { 
      if (mounted && data['conversationId'] == _activeConversationId) {
        setState(() {
          for (var msg in _messages) {
            if (msg.senderId == _myUserId) msg.isRead = true;
          }
        });
      }
    });

    socket.on('typing_start', (data) {
       if (mounted && data['conversationId'] == _activeConversationId && data['senderId'] != _myUserId) {
        setState(() => _isPeerTyping = true);
      }
    });

    socket.on('typing_stop', (data) {
      if (mounted && data['conversationId'] == _activeConversationId && data['senderId'] != _myUserId) {
        setState(() => _isPeerTyping = false);
      }
    });

    socket.on('messages_deleted_bulk', (data) {
      if (mounted && data['conversationId'] == _activeConversationId) {
        List<dynamic> ids = data['messageIds'];
        bool isHardDelete = data['isHardDelete'] ?? true;
        setState(() {
          if (isHardDelete) {
             _messages.removeWhere((m) => ids.contains(m.id));
          } else {
             _messages.removeWhere((m) => ids.contains(m.id));
          }
        });
      }
    });

    socket.on('removed_from_group', (data) {
      if (!mounted) return;
      if (widget.isGroup && widget.groupId == data['groupId']) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: const Text("Access Revoked"),
            content: const Text("You have been removed from this group by an admin."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.pop(context);
                },
                child: const Text("OK"),
              )
            ],
          ),
        );
      }
    });
  }

  Future<void> _initializeChat() async {
    _myUserId = await _storage.read(key: 'userId');
    if (_activeConversationId != null) {
      await _loadMessages(initial: true);
    } else {
      await _findOrCreateConversation();
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
      } else {
        if (result['statusCode'] == 403) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You no longer have access to this chat.")));
           Navigator.pop(context);
        }
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
      final result = await _api.post('/api/chat/start', {
        'receiverId': widget.receiverId, 
        'groupId': widget.isGroup ? widget.groupId : null
      });
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
    if (widget.isGroup) return "Group";
    if (_isPeerTyping) return "Typing...";
    if (_isPeerOnline) return "Active Now";
    if (_peerLastSeen == null) return "Offline";
    return "Last seen ${PresenceFormatter.format(_peerLastSeen)}";
  }

  // --- ACTIONS ---
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

  Future<void> _downloadAndOpenWith(String messageId, String url, String fileName) async {
    if (kIsWeb) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
      return;
    }

    try {
      setState(() => _downloadingFileId = messageId);

      final dir = await getTemporaryDirectory();
      final safeFileName = fileName.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final savePath = "${dir.path}/$safeFileName"; 

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);

        final result = await OpenFile.open(savePath);
        
        if (result.type != ResultType.done) {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
               content: Text("Could not open file: ${result.message}"),
               backgroundColor: Colors.red,
             ));
           }
        }
      } else {
        throw Exception("Download failed with status: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Failed to download file."),
          backgroundColor: Colors.red,
        ));
      }
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } finally {
      if (mounted) setState(() => _downloadingFileId = null);
    }
  }

  Future<void> _sendMessage({String? text, String? filePath, Uint8List? fileBytes, String? fileName, String type = 'text'}) async {
    if ((text == null || text.trim().isEmpty) && filePath == null && fileBytes == null) return;
    if (_activeConversationId == null || _myUserId == null) return;

    if (_editingMessage != null && type == 'text') {
      try {
        await _api.put('/api/chat/message/${_editingMessage!.id}', {'text': text});
        setState(() {
          _editingMessage!.text = text!;
          _editingMessage!.isEdited = true;
          _editingMessage = null;
          _textController.clear();
        });
      } catch (e) { debugPrint("Edit Failed"); }
      return;
    }

    String? token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMessage = ChatMessage(
      id: tempId,
      senderId: _myUserId!,
      text: text ?? "",
      type: type,
      fileUrl: filePath, 
      fileName: fileName ?? (filePath != null ? filePath.split('/').last : "File"),
      localBytes: fileBytes, 
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

      if (text != null && text.isNotEmpty) request.fields['text'] = text;
      request.fields['type'] = type;
      if (tempMessage.replyToId != null) request.fields['replyToId'] = tempMessage.replyToId!;

      if (fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName ?? 'upload'));
      } else if (filePath != null) {
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final realMessage = ChatMessage.fromJson(data);
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempId);
          if (index != -1) _messages[index] = realMessage;
        });
      } else {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempId);
          if (index != -1) _messages[index].status = MessageStatus.error;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Message failed.")));
      }
    } catch (e) {
      setState(() {
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1) _messages[index].status = MessageStatus.error;
      });
    }
  }

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
        if (file.bytes != null) _sendMessage(fileBytes: file.bytes, fileName: file.name, type: 'file');
      } else {
        if (result.files.single.path != null) _sendMessage(filePath: result.files.single.path!, type: 'file');
      }
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent, 
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly, 
          children: [
            _attachOption(Icons.image, Colors.purple, "Gallery", () => _pickImage(ImageSource.gallery)), 
            _attachOption(Icons.camera_alt, Colors.pink, "Camera", () => _pickImage(ImageSource.camera)), 
            _attachOption(Icons.insert_drive_file, Colors.blue, "Document", _pickFile),
            if (widget.isGroup)
              _attachOption(Icons.bar_chart_rounded, Colors.orange, "Poll", () {
                  Navigator.pop(context); 
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true, 
                    backgroundColor: Colors.transparent,
                    builder: (c) => PollCreationSheet(groupId: widget.groupId!),
                  );
              }),
          ]
        ),
      )
    );
  }
  
  Widget _attachOption(IconData icon, Color color, String label, VoidCallback onTap) {
    return Padding(padding: const EdgeInsets.all(16.0), child: GestureDetector(onTap: () { Navigator.pop(context); onTap(); }, child: Column(children: [CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 12))])));
  }

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
      await _api.post('/api/chat/delete-multiple', {'messageIds': idsToDelete, 'deleteForEveryone': false});
    } catch (_) {}
  }

  Widget _buildDateHeader(String dateStr) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
          child: Text(dateStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        if (_isSelectionMode) {
          setState(() { _isSelectionMode = false; _selectedMessageIds.clear(); });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF2F4F7),
        appBar: _isSelectionMode 
          ? AppBar(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _isSelectionMode = false; _selectedMessageIds.clear(); })),
              title: Text("${_selectedMessageIds.length} Selected"),
              actions: [
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _deleteSelectedMessages),
              ],
            )
          : AppBar(
            titleSpacing: 0,
            backgroundColor: Theme.of(context).cardColor,
            foregroundColor: isDark ? Colors.white : Colors.black,
            elevation: 1,
            shadowColor: Colors.black.withOpacity(0.05),
            title: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: (widget.receiverProfilePic != null && widget.receiverProfilePic!.isNotEmpty)
                          ? CachedNetworkImageProvider(widget.receiverProfilePic!)
                          : null,
                      child: (widget.receiverProfilePic == null || widget.receiverProfilePic!.isEmpty)
                          ? Text(widget.receiverName.substring(0, 1).toUpperCase(), style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))
                          : null,
                    ),
                    if (widget.isOnline && !widget.isGroup)
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).cardColor, width: 1.5)),
                        ),
                      )
                  ],
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.receiverName, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (!widget.isGroup)
                      Text(_getStatusText(), style: TextStyle(fontSize: 11, color: widget.isOnline ? Colors.green : Colors.grey)),
                  ],
                ),
              ],
            ),
            actions: [
              if (widget.isGroup && widget.groupId != null)
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(groupId: widget.groupId!, groupName: widget.receiverName)));
                  },
                ),
            ],
          ),
        body: Column(
          children: [
            if (widget.isGroup && widget.groupId != null)
               ActivePollCard(groupId: widget.groupId),

            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  bool showDate = false;
                  if (index == 0) {
                    showDate = true;
                  } else {
                    final prevMsg = _messages[index - 1];
                    if (msg.createdAt.day != prevMsg.createdAt.day || msg.createdAt.month != prevMsg.createdAt.month) {
                      showDate = true;
                    }
                  }

                  String dateLabel = "";
                  if (showDate) {
                    final now = DateTime.now();
                    final diff = now.difference(msg.createdAt).inDays;
                    if (diff == 0 && now.day == msg.createdAt.day) dateLabel = "Today";
                    else if (diff == 1) dateLabel = "Yesterday";
                    else dateLabel = DateFormat("MMM d, y").format(msg.createdAt);
                  }

                  return Column(
                    children: [
                      if (showDate) _buildDateHeader(dateLabel),
                      
                      MessageBubble(
                        msg: msg,
                        myUserId: _myUserId ?? "",
                        isMe: msg.senderId == _myUserId,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        isSelectionMode: _isSelectionMode,
                        isSelected: _selectedMessageIds.contains(msg.id),
                        playingMessageId: _playingMessageId,
                        currentPosition: _currentPosition,
                        totalDuration: _totalDuration,
                        downloadingFileId: _downloadingFileId,
                        isAdmin: widget.isGroup && _groupAdminIds.contains(msg.senderId),
                        
                        showSenderName: widget.isGroup && msg.senderId != _myUserId,
                        
                        onSwipeReply: (id) {
                          setState(() { _replyingTo = msg; _editingMessage = null; });
                          _focusNode.requestFocus();
                        },
                        onToggleSelection: _toggleSelection,
                        onReply: (id, _) {
                          setState(() { _replyingTo = msg; _editingMessage = null; });
                          _focusNode.requestFocus();
                        },
                        onEdit: (id) {
                          setState(() { _editingMessage = msg; _replyingTo = null; _textController.text = msg.text; });
                          _focusNode.requestFocus();
                        },
                        onDelete: (id) { _toggleSelection(id); _deleteSelectedMessages(); },
                        onPlayAudio: (url) async {
                          if (url.startsWith('http')) { await _audioPlayer.play(UrlSource(url)); } 
                          else { await _audioPlayer.play(DeviceFileSource(url)); }
                          setState(() => _playingMessageId = msg.id);
                        },
                        onPauseAudio: (id, _) async { await _audioPlayer.pause(); setState(() => _playingMessageId = null); },
                        onSeekAudio: (pos) => _audioPlayer.seek(pos),
                        onDownloadFile: (url, name) => _downloadAndOpenWith(msg.id, url, name),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_isPeerTyping) 
               const Padding(padding: EdgeInsets.only(left: 16, bottom: 4), child: Align(alignment: Alignment.centerLeft, child: Text("Typing...", style: TextStyle(color: Colors.grey, fontSize: 12)))),

            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]
              ),
              child: SafeArea(
                child: ChatInputArea(
                  controller: _textController,
                  focusNode: _focusNode,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  isRecording: _isRecording,
                  recordDuration: _recordDuration,
                  replyingTo: _replyingTo,
                  editingMessage: _editingMessage,
                  myUserId: _myUserId ?? "",
                  onCancelReply: () => setState(() => _replyingTo = null),
                  onCancelEdit: () => setState(() { _editingMessage = null; _textController.clear(); }),
                  onStartRecording: _startRecording,
                  onStopRecording: () => _stopRecording(send: true),
                  onCancelRecording: _cancelRecording,
                  onSendMessage: () => _sendMessage(text: _textController.text),
                  onAttachmentMenu: _showAttachmentMenu,
                  onTyping: (val) {
                    setState(() {});
                    if (val.isNotEmpty) {
                       if (!_isTyping) { 
                         _isTyping = true; 
                         SocketService().socket?.emit('typing', {
                           'receiverId': widget.receiverId, 
                           'conversationId': _activeConversationId,
                           'groupId': widget.isGroup ? widget.groupId : null
                         }); 
                       }
                       _typingDebounce?.cancel();
                       _typingDebounce = Timer(const Duration(seconds: 2), () { 
                         _isTyping = false; 
                         SocketService().socket?.emit('stop_typing', {
                           'receiverId': widget.receiverId, 
                           'conversationId': _activeConversationId,
                           'groupId': widget.isGroup ? widget.groupId : null
                         }); 
                       });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 🎨 INTERNAL WIDGET: Message Bubble (PRO)
// ==========================================
class MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final String myUserId;
  final bool isMe;
  final bool isDark;
  final Color primaryColor;
  final bool isSelectionMode;
  final bool isSelected;
  final String? playingMessageId;
  final Duration currentPosition;
  final Duration totalDuration;
  final String? downloadingFileId;
  final bool isAdmin;
  final bool showSenderName;
  
  final Function(String) onSwipeReply;
  final Function(String) onToggleSelection;
  final Function(String, String) onReply;
  final Function(String) onEdit;
  final Function(String) onDelete;
  final Function(String) onPlayAudio;
  final Function(String, String) onPauseAudio;
  final Function(Duration) onSeekAudio;
  final Function(String, String) onDownloadFile;

  const MessageBubble({
    super.key, required this.msg, required this.myUserId, required this.isMe, required this.isDark, required this.primaryColor,
    required this.isSelectionMode, required this.isSelected, required this.playingMessageId, required this.currentPosition, required this.totalDuration,
    required this.downloadingFileId, required this.isAdmin, required this.showSenderName,
    required this.onSwipeReply, required this.onToggleSelection, required this.onReply, required this.onEdit, required this.onDelete,
    required this.onPlayAudio, required this.onPauseAudio, required this.onSeekAudio, required this.onDownloadFile
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a').format(msg.createdAt);
    final statusIcon = msg.status == MessageStatus.sending ? Icons.access_time : (msg.isRead ? Icons.done_all : Icons.check);
    final statusColor = msg.status == MessageStatus.sending ? Colors.grey : (msg.isRead ? Colors.blue : Colors.grey);

    return Dismissible(
      key: Key(msg.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (d) async { onSwipeReply(msg.id); return false; },
      background: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), color: Colors.transparent, child: Icon(Icons.reply, color: primaryColor)),
      child: GestureDetector(
        onLongPress: () => onToggleSelection(msg.id),
        onTap: () { if (isSelectionMode) onToggleSelection(msg.id); },
        child: Container(
          color: isSelected ? primaryColor.withOpacity(0.2) : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (showSenderName && !isMe)
                    Padding(padding: const EdgeInsets.only(left: 12, bottom: 4), child: Text(msg.senderName ?? "User", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[800]))),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: isMe 
                          ? LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.85)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                          : null,
                      color: isMe ? null : (isDark ? Colors.grey[800] : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                        bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (msg.replyToId != null) 
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: isMe ? Colors.white : primaryColor, width: 4))),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(msg.replyToSenderName ?? "Reply", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text(msg.replyToText ?? "Message", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))]),
                          ),
                        
                        if (msg.fileUrl != null || msg.localBytes != null)
                           _buildMediaContent(context),

                        if (msg.text.isNotEmpty)
                          Text(msg.text, style: GoogleFonts.lato(fontSize: 15, color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87))),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        if (isMe) ...[const SizedBox(width: 4), Icon(statusIcon, size: 12, color: statusColor)],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ✅ FIX: Added heroTag to FullScreenImage parameters to support existing widget
  Widget _buildMediaContent(BuildContext context) {
    if (msg.type == 'image') {
      return GestureDetector(
        onTap: () {
           // We use msg.id as a unique heroTag for the animation
           if (msg.fileUrl != null) Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(imageUrl: msg.fileUrl!, heroTag: msg.id)));
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: msg.localBytes != null 
              ? Image.memory(msg.localBytes!, fit: BoxFit.cover)
              : CachedNetworkImage(imageUrl: msg.fileUrl!, placeholder: (c, u) => const CircularProgressIndicator(), errorWidget: (c, u, e) => const Icon(Icons.broken_image)),
        ),
      );
    }
    return const SizedBox.shrink(); 
  }
}

// ==========================================
// 🎨 INTERNAL WIDGET: Floating Input Area (PRO)
// ==========================================
class ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final Color primaryColor;
  final bool isRecording;
  final int recordDuration;
  final ChatMessage? replyingTo;
  final ChatMessage? editingMessage;
  final String myUserId;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelEdit;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onSendMessage;
  final VoidCallback onAttachmentMenu;
  final Function(String) onTyping;

  const ChatInputArea({
    super.key, required this.controller, required this.focusNode, required this.isDark, required this.primaryColor,
    required this.isRecording, required this.recordDuration, required this.replyingTo, required this.editingMessage,
    required this.myUserId, required this.onCancelReply, required this.onCancelEdit, required this.onStartRecording,
    required this.onStopRecording, required this.onCancelRecording, required this.onSendMessage, required this.onAttachmentMenu,
    required this.onTyping
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingTo != null || editingMessage != null)
            Container(
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(editingMessage != null ? Icons.edit : Icons.reply, color: primaryColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(editingMessage != null ? "Editing Message" : "Replying to ${replyingTo!.replyToSenderName}", style: const TextStyle(fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.close, size: 18), onPressed: editingMessage != null ? onCancelEdit : onCancelReply),
                ],
              ),
            ),
          
          if (isRecording)
             Row(children: [
                const Icon(Icons.mic, color: Colors.red, size: 24),
                const SizedBox(width: 10),
                Text("${(recordDuration ~/ 60).toString().padLeft(2, '0')}:${(recordDuration % 60).toString().padLeft(2, '0')}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(onPressed: onCancelRecording, child: const Text("Cancel")),
                const SizedBox(width: 10),
                GestureDetector(onTap: onStopRecording, child: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.send, color: Colors.white))),
             ])
          else
             Row(
               children: [
                 IconButton(icon: Icon(Icons.add, color: primaryColor), onPressed: onAttachmentMenu),
                 Expanded(
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 16),
                     decoration: BoxDecoration(color: isDark ? Colors.grey[800] : Colors.grey[100], borderRadius: BorderRadius.circular(24)),
                     child: TextField(
                       controller: controller,
                       focusNode: focusNode,
                       minLines: 1, maxLines: 4,
                       onChanged: onTyping,
                       style: GoogleFonts.lato(fontSize: 16),
                       decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12)),
                     ),
                   ),
                 ),
                 const SizedBox(width: 8),
                 GestureDetector(
                   onLongPress: onStartRecording,
                   onTap: onSendMessage,
                   child: Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                     child: Icon(controller.text.isEmpty ? Icons.mic : Icons.send_rounded, color: Colors.white, size: 20),
                   ),
                 ),
               ],
             ),
        ],
      ),
    );
  }
}