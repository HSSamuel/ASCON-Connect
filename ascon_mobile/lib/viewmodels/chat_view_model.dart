import 'dart:async';
import 'package:flutter/foundation.dart';

import '../services/socket_service.dart';
import '../services/audio_service.dart'; 
import '../services/chat_service.dart';
import '../services/api_client.dart'; // ✅ Added ApiClient Import
import '../models/chat_objects.dart';
import '../config/storage_config.dart';

class ChatViewModel extends ChangeNotifier {
  // ✅ DELEGATED SERVICES
  final ChatService _chatService = ChatService();
  final AudioService _audioService = AudioService();
  final _storage = StorageConfig.storage;

  // --- STATE VARIABLES ---
  List<ChatMessage> messages = [];
  String? activeConversationId;
  String? myUserId;
  String? currentGroupId;
  
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
    
    // Initialize Chat via Service
    if (activeConversationId == null) {
      activeConversationId = await _chatService.startConversation(receiverId, groupId: groupId);
    }
    
    if (activeConversationId != null) {
      await _loadMessages(initial: true);
    }

    _setupAudioListeners();
    _setupSocketListeners(receiverId);

    // Context-Specific Setup
    if (!isGroup) {
      _startStatusPolling(receiverId);
    } else if (groupId != null) {
      // ✅ Now correctly implemented
      _fetchGroupAdmins(groupId);
    }
  }

  @override
  void dispose() {
    _typingDebounce?.cancel();
    _recordTimer?.cancel();
    _statusPollingTimer?.cancel();
    _statusSubscription?.cancel();
    
    _audioService.dispose(); 
    
    _stopSocketListeners();
    super.dispose();
  }

  // ==========================================
  // 1. DATA LOADING
  // ==========================================

  Future<void> _loadMessages({bool initial = false}) async {
    if (activeConversationId == null) return;
    
    final newMessages = await _chatService.fetchMessages(activeConversationId!);
    messages = newMessages;
    hasMoreMessages = newMessages.length >= 20;
    
    if (initial) await _chatService.markRead(activeConversationId!);
    notifyListeners();
  }

  Future<void> loadMoreMessages() async {
    if (isLoadingMore || !hasMoreMessages || messages.isEmpty || activeConversationId == null) return;
    
    isLoadingMore = true;
    notifyListeners();

    String oldestId = messages.first.id;
    final olderMessages = await _chatService.fetchMessages(activeConversationId!, beforeId: oldestId);
        
    if (olderMessages.isEmpty) {
      hasMoreMessages = false;
    } else {
      messages.insertAll(0, olderMessages);
    }
    
    isLoadingMore = false;
    notifyListeners();
  }

  Future<void> _fetchGroupAdmins(String groupId) async {
    // ✅ Implementation added using ApiClient
    try {
      final client = ApiClient();
      final result = await client.get('/api/groups/$groupId/info');
      
      if (result['success'] == true) {
        final List<dynamic> admins = result['data']['admins'] ?? [];
        groupAdminIds = admins.map((e) => e.toString()).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Failed to fetch group admins: $e");
    }
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
          final newMessage = ChatMessage.fromJson(data['message']);
          
          // ✅ FIX: Prevent Duplicate Messages
          // This stops the socket event from re-adding a message we just added optimistically
          if (messages.any((m) => m.id == newMessage.id)) return;

          messages.add(newMessage);
          isPeerTyping = false;
          notifyListeners();
          _chatService.markRead(activeConversationId!);
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
      // ✅ Allow typing events if sender is NOT me (for Group compatibility)
      if (data['conversationId'] == activeConversationId && data['senderId'] != myUserId) {
        isPeerTyping = true;
        notifyListeners();
      }
    });

    socket.on('typing_stop', (data) {
      if (data['conversationId'] == activeConversationId && data['senderId'] != myUserId) {
        isPeerTyping = false;
        notifyListeners();
      }
    });

    socket.on('messages_deleted_bulk', (data) {
      if (data['conversationId'] == activeConversationId) {
        List<dynamic> ids = data['messageIds'];
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

    // Handle Edit (Left largely as logic in VM for specific UI state manipulation)
    if (editingMessage != null && type == 'text') {
      editingMessage = null;
      notifyListeners();
      return;
    }

    String? token = await _storage.read(key: 'auth_token');
    if (token == null) return;

    // Optimistic UI Update
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

    // ✅ DELEGATE TO SERVICE
    final result = await _chatService.sendMessage(
      conversationId: activeConversationId!,
      token: token,
      text: text,
      type: type,
      replyToId: tempMessage.replyToId,
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName
    );

    final index = messages.indexWhere((m) => m.id == tempId);
    if (result != null && index != -1) {
      messages[index] = result;
    } else if (index != -1) {
      messages[index].status = MessageStatus.error;
    }
    notifyListeners();
  }

  // ==========================================
  // 4. AUDIO & RECORDING
  // ==========================================
  
  void _setupAudioListeners() {
    _audioService.playerStateStream.listen((state) {
      if (state.toString().contains('completed')) {
        playingMessageId = null;
        currentPosition = Duration.zero;
        notifyListeners();
      }
    });
    _audioService.positionStream.listen((p) {
      currentPosition = p;
      notifyListeners();
    });
    _audioService.durationStream.listen((d) {
      totalDuration = d;
      notifyListeners();
    });
  }

  Future<void> startRecording() async {
    if (await _audioService.startRecording() != null) {
      isRecording = true;
      recordDuration = 0;
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        recordDuration++;
        notifyListeners();
      });
      notifyListeners();
    }
  }

  Future<void> stopRecording({bool send = true, required String receiverName}) async {
    _recordTimer?.cancel();
    isRecording = false;
    final path = await _audioService.stopRecording();
    notifyListeners();
    
    if (send && path != null) {
      sendMessage(filePath: path, type: 'audio', receiverName: receiverName);
    }
  }

  void cancelRecording() {
    _recordTimer?.cancel();
    _audioService.stopRecording(); // Just stop, don't use path
    isRecording = false;
    notifyListeners();
  }

  Future<void> playAudio(String messageId, String url) async {
    await _audioService.play(url);
    playingMessageId = messageId;
    notifyListeners();
  }

  Future<void> pauseAudio() async {
    await _audioService.pause();
    playingMessageId = null;
    notifyListeners();
  }

  Future<void> seekAudio(Duration pos) async {
    await _audioService.seek(pos);
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

    // ✅ DELEGATE TO SERVICE
    await _chatService.deleteMessages(idsToDelete, isAdmin);
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