import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';

import '../services/api_client.dart';
import '../services/socket_service.dart';
import '../models/chat_objects.dart';
import '../config.dart';
import '../config/storage_config.dart';

class ChatViewModel extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final _storage = StorageConfig.storage;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- STATE VARIABLES ---
  List<ChatMessage> messages = [];
  String? activeConversationId;
  String? myUserId;
  String? currentGroupId; // ✅ Track Group Context
  
  bool isLoadingMore = false;
  bool hasMoreMessages = true;
  
  bool isPeerOnline = false;
  String? peerLastSeen;
  bool isPeerTyping = false;
  bool isTyping = false;

  // Recording State
  bool isRecording = false;
  int recordDuration = 0;
  Timer? _recordTimer;

  // Audio Playback State
  String? playingMessageId;
  Duration currentPosition = Duration.zero;
  Duration totalDuration = Duration.zero;

  // Selection Mode
  bool isSelectionMode = false;
  final Set<String> selectedMessageIds = {};

  // Reply / Edit
  ChatMessage? replyingTo;
  ChatMessage? editingMessage;

  // Group Admin IDs (for Permissions)
  List<String> groupAdminIds = [];

  // Debounce for Typing Indicator
  Timer? _typingDebounce;
  
  // Socket & Status Timers
  Timer? _statusPollingTimer;
  StreamSubscription? _statusSubscription;

  // --- INITIALIZATION ---
  Future<void> init(String receiverId, String? conversationId, bool isGroup, String? groupId) async {
    myUserId = await _storage.read(key: 'userId');
    activeConversationId = conversationId;
    currentGroupId = groupId;
    
    // Initialize Chat
    if (activeConversationId != null) {
      await _loadMessages(initial: true);
    } else {
      await _findOrCreateConversation(receiverId, isGroup, groupId);
    }

    _setupSocketListeners(receiverId);
    _setupAudioPlayerListeners();

    // Context-Specific Setup
    if (!isGroup) {
      _startStatusPolling(receiverId);
    } else if (groupId != null) {
      _fetchGroupAdmins(groupId);
    }
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _recordTimer?.cancel();
    _statusPollingTimer?.cancel();
    _statusSubscription?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    
    _stopSocketListeners();
    super.dispose();
  }

  // ==========================================
  // 1. DATA LOADING & API
  // ==========================================

  Future<void> _loadMessages({bool initial = false}) async {
    if (activeConversationId == null) return;
    try {
      final result = await _api.get('/api/chat/$activeConversationId');
      if (result['success'] == true) {
        final List<dynamic> data = result['data'];
        final newMessages = data.map((m) => ChatMessage.fromJson(m)).toList();
        
        messages = newMessages;
        hasMoreMessages = newMessages.length >= 20;
        
        if (initial) _markMessagesAsRead();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loadMoreMessages() async {
    if (isLoadingMore || !hasMoreMessages || messages.isEmpty || activeConversationId == null) return;
    
    isLoadingMore = true;
    notifyListeners();

    String oldestId = messages.first.id;
    try {
      final result = await _api.get('/api/chat/$activeConversationId?beforeId=$oldestId');
      if (result['success'] == true) {
        final List<dynamic> data = result['data'];
        final olderMessages = data.map((m) => ChatMessage.fromJson(m)).toList();
        
        if (olderMessages.isEmpty) {
          hasMoreMessages = false;
        } else {
          messages.insertAll(0, olderMessages);
        }
      }
    } catch (_) {
    } finally {
      isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _findOrCreateConversation(String receiverId, bool isGroup, String? groupId) async {
    try {
      final Map<String, dynamic> body = {'receiverId': receiverId};
      
      // ✅ Pass Group ID to Backend to ensure correct context
      if (isGroup && groupId != null) {
        body['groupId'] = groupId;
      }

      final result = await _api.post('/api/chat/start', body);
      if (result['success'] == true) {
        activeConversationId = result['data']['_id'];
        await _loadMessages(initial: true);
      }
    } catch (_) {}
  }

  Future<void> _fetchGroupAdmins(String groupId) async {
    try {
      final result = await _api.get('/api/groups/$groupId/info');
      if (result['success'] == true) {
        final List<dynamic> admins = result['data']['admins'] ?? [];
        groupAdminIds = admins.map((e) => e.toString()).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _markMessagesAsRead() async {
    if (activeConversationId != null) await _api.put('/api/chat/read/$activeConversationId', {});
  }

  // ==========================================
  // 2. SOCKET & STATUS
  // ==========================================

  void _setupSocketListeners(String receiverId) {
    final socket = SocketService().socket;
    if (socket == null) return; 

    socket.on('new_message', (data) {
      if (data['conversationId'] == activeConversationId) {
        try {
          messages.add(ChatMessage.fromJson(data['message']));
          isPeerTyping = false;
          notifyListeners();
          _markMessagesAsRead();
        } catch (e) {
          debugPrint("Parse Error: $e");
        }
      }
    });

    socket.on('messages_read', (data) {
      if (data['conversationId'] == activeConversationId) {
        for (var msg in messages) {
          if (msg.senderId == myUserId) msg.isRead = true;
        }
        notifyListeners();
      }
    });

    socket.on('typing_start', (data) {
      if (data['conversationId'] == activeConversationId && data['senderId'] == receiverId) {
        isPeerTyping = true;
        notifyListeners();
      }
    });

    socket.on('typing_stop', (data) {
      if (data['conversationId'] == activeConversationId && data['senderId'] == receiverId) {
        isPeerTyping = false;
        notifyListeners();
      }
    });

    socket.on('messages_deleted_bulk', (data) {
      if (data['conversationId'] == activeConversationId) {
        List<dynamic> ids = data['messageIds'];
        // Remove locally immediately
        messages.removeWhere((m) => ids.contains(m.id));
        notifyListeners();
      }
    });

    // Presence Stream
    _statusSubscription = SocketService().userStatusStream.listen((data) {
      if (data['userId'] == receiverId) {
        isPeerOnline = data['isOnline'];
        if (!isPeerOnline) peerLastSeen = data['lastSeen'];
        notifyListeners();
      }
    });
  }

  void _stopSocketListeners() {
    final socket = SocketService().socket;
    socket?.off('new_message');
    socket?.off('messages_read');
    socket?.off('messages_deleted_bulk');
    socket?.off('typing_start');
    socket?.off('typing_stop');
  }

  void _startStatusPolling(String receiverId) {
    SocketService().checkUserStatus(receiverId);
    _statusPollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (isPeerOnline) {
        timer.cancel();
      } else {
        SocketService().checkUserStatus(receiverId);
      }
    });
  }

  void sendTypingEvent(String receiverId) {
    if (!isTyping) {
      isTyping = true;
      SocketService().socket?.emit('typing', {'receiverId': receiverId, 'conversationId': activeConversationId});
    }
    _typingDebounce?.cancel();
    _typingDebounce = Timer(const Duration(seconds: 2), () {
      isTyping = false;
      SocketService().socket?.emit('stop_typing', {'receiverId': receiverId, 'conversationId': activeConversationId});
    });
  }

  // ==========================================
  // 3. SENDING & EDITING MESSAGES
  // ==========================================

  Future<void> sendMessage({String? text, String? filePath, Uint8List? fileBytes, String? fileName, String type = 'text', required String receiverName}) async {
    if ((text == null || text.trim().isEmpty) && filePath == null && fileBytes == null) return;
    if (activeConversationId == null || myUserId == null) return;

    // Handle Edit
    if (editingMessage != null && type == 'text') {
      try {
        await _api.put('/api/chat/message/${editingMessage!.id}', {'text': text});
        editingMessage!.text = text!;
        editingMessage!.isEdited = true;
        editingMessage = null;
        notifyListeners();
      } catch (_) {}
      return;
    }

    String? token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMessage = ChatMessage(
      id: tempId,
      senderId: myUserId!,
      text: text ?? "",
      type: type,
      fileUrl: filePath,
      fileName: fileName ?? (filePath != null ? filePath.split('/').last : "File"),
      localBytes: fileBytes,
      replyToId: replyingTo?.id,
      replyToText: replyingTo?.text,
      replyToSenderName: replyingTo != null ? (replyingTo!.senderId == myUserId ? "You" : receiverName) : null,
      replyToType: replyingTo?.type,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );

    messages.add(tempMessage);
    replyingTo = null;
    notifyListeners();

    try {
      final baseUrl = AppConfig.baseUrl.endsWith('/')
          ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
          : AppConfig.baseUrl;

      final url = Uri.parse('$baseUrl/api/chat/$activeConversationId');
      
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
        final index = messages.indexWhere((m) => m.id == tempId);
        if (index != -1) messages[index] = realMessage;
        notifyListeners();
      }
    } catch (e) {
      final index = messages.indexWhere((m) => m.id == tempId);
      if (index != -1) messages[index].status = MessageStatus.error;
      notifyListeners();
    }
  }

  // ==========================================
  // 4. AUDIO & RECORDING
  // ==========================================

  Future<void> startRecording() async {
    if (kIsWeb) return; 
    if (await Permission.microphone.request().isGranted) {
      try {
        if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: 50);
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(const RecordConfig(), path: path);
        
        isRecording = true;
        recordDuration = 0;
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          recordDuration++;
          notifyListeners();
        });
        notifyListeners();
      } catch (e) {
        debugPrint("Recording Error: $e");
      }
    }
  }

  Future<void> stopRecording({bool send = true, required String receiverName}) async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    isRecording = false;
    notifyListeners();
    
    if (send && path != null) {
      sendMessage(filePath: path, type: 'audio', receiverName: receiverName);
    }
  }

  void cancelRecording() {
    _recordTimer?.cancel();
    _audioRecorder.stop();
    isRecording = false;
    notifyListeners();
  }

  void _setupAudioPlayerListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        playingMessageId = null;
        currentPosition = Duration.zero;
        notifyListeners();
      }
    });
    _audioPlayer.onPositionChanged.listen((p) {
      currentPosition = p;
      notifyListeners();
    });
    _audioPlayer.onDurationChanged.listen((d) {
      totalDuration = d;
      notifyListeners();
    });
  }

  Future<void> playAudio(String messageId, String url) async {
    if (url.startsWith('http')) {
      await _audioPlayer.play(UrlSource(url));
    } else {
      await _audioPlayer.play(DeviceFileSource(url));
    }
    playingMessageId = messageId;
    notifyListeners();
  }

  Future<void> pauseAudio() async {
    await _audioPlayer.pause();
    playingMessageId = null;
    notifyListeners();
  }

  Future<void> seekAudio(Duration pos) async {
    await _audioPlayer.seek(pos);
  }

  // ==========================================
  // 5. SELECTION & MANAGEMENT
  // ==========================================

  void toggleSelection(String messageId) {
    if (selectedMessageIds.contains(messageId)) {
      selectedMessageIds.remove(messageId);
      if (selectedMessageIds.isEmpty) isSelectionMode = false;
    } else {
      isSelectionMode = true;
      selectedMessageIds.add(messageId);
    }
    notifyListeners();
  }

  void clearSelection() {
    isSelectionMode = false;
    selectedMessageIds.clear();
    notifyListeners();
  }

  Future<void> deleteSelectedMessages() async {
    final idsToDelete = selectedMessageIds.toList();
    bool isAdmin = groupAdminIds.contains(myUserId);
    
    messages.removeWhere((m) => idsToDelete.contains(m.id));
    isSelectionMode = false;
    selectedMessageIds.clear();
    notifyListeners();

    try {
      // ✅ Admin Delete (Hard Delete) vs User Delete (Soft Delete)
      await _api.post('/api/chat/delete-multiple', {
        'messageIds': idsToDelete, 
        'deleteForEveryone': isAdmin // Admins can delete for everyone
      });
    } catch (_) {}
  }

  void setReplyingTo(ChatMessage msg) {
    replyingTo = msg;
    editingMessage = null;
    notifyListeners();
  }

  void setEditingMessage(ChatMessage msg) {
    editingMessage = msg;
    replyingTo = null;
    notifyListeners();
  }

  void cancelReplyOrEdit() {
    replyingTo = null;
    editingMessage = null;
    notifyListeners();
  }
}