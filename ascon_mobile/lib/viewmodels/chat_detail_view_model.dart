import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../services/api_client.dart';
import '../services/socket_service.dart';
import '../services/auth_service.dart';
import '../models/chat_objects.dart';
import '../config.dart';

// ✅ STATE CLASS
class ChatDetailState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMoreMessages;
  final bool isPeerTyping;
  final bool isPeerOnline;
  final String? peerLastSeen;
  final String? conversationId;
  final String myUserId;
  final List<String> groupAdminIds;
  final bool isKicked;

  const ChatDetailState({
    this.messages = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMoreMessages = true,
    this.isPeerTyping = false,
    this.isPeerOnline = false,
    this.peerLastSeen,
    this.conversationId,
    this.myUserId = "",
    this.groupAdminIds = const [],
    this.isKicked = false,
  });

  ChatDetailState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMoreMessages,
    bool? isPeerTyping,
    bool? isPeerOnline,
    String? peerLastSeen,
    String? conversationId,
    String? myUserId,
    List<String>? groupAdminIds,
    bool? isKicked,
  }) {
    return ChatDetailState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      isPeerTyping: isPeerTyping ?? this.isPeerTyping,
      isPeerOnline: isPeerOnline ?? this.isPeerOnline,
      peerLastSeen: peerLastSeen ?? this.peerLastSeen,
      conversationId: conversationId ?? this.conversationId,
      myUserId: myUserId ?? this.myUserId,
      groupAdminIds: groupAdminIds ?? this.groupAdminIds,
      isKicked: isKicked ?? this.isKicked,
    );
  }
}

// ✅ NOTIFIER
class ChatDetailNotifier extends StateNotifier<ChatDetailState> {
  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();
  final SocketService _socket = SocketService();
  
  final String receiverId;
  final bool isGroup;
  final String? groupId;

  Timer? _statusTimer;
  StreamSubscription? _statusSubscription;

  ChatDetailNotifier({
    required this.receiverId, 
    required this.isGroup,
    this.groupId,
    String? conversationId,
    bool initialIsOnline = false,
    String? initialLastSeen,
  }) : super(ChatDetailState(
        conversationId: conversationId, 
        isPeerOnline: initialIsOnline, 
        peerLastSeen: initialLastSeen
      )) {
    _init();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _statusSubscription?.cancel();
    _stopTyping();
    if (isGroup && groupId != null) {
      _socket.socket?.emit('leave_room', groupId);
    }
    
    _socket.socket?.off('new_message');
    _socket.socket?.off('messages_read');
    _socket.socket?.off('messages_deleted_bulk');
    _socket.socket?.off('typing_start');
    _socket.socket?.off('typing_stop');
    _socket.socket?.off('removed_from_group');
    
    super.dispose();
  }

  Future<void> _init() async {
    final myId = await _auth.currentUserId ?? "";
    if (mounted) state = state.copyWith(myUserId: myId);

    if (isGroup && groupId != null) {
      _socket.socket?.emit('join_room', groupId);
      _fetchGroupAdmins();
    } else {
      if (!state.isPeerOnline) _startStatusPolling();
    }

    if (state.conversationId != null) {
      await loadMessages(initial: true);
    } else {
      // Attempt init, but don't crash if it fails (lazy init)
      try {
        await _findOrCreateConversation();
      } catch (e) {
        debugPrint("Initial chat creation check failed: $e");
      }
    }

    _setupSocketListeners();
  }

  Future<void> _fetchGroupAdmins() async {
    if (groupId == null) return;
    try {
      final result = await _api.get('/api/groups/$groupId/info');
      if (result['success'] == true) {
        final data = result['data']; // Check if this also needs ['data'] depending on backend
        final List<dynamic> admins = (data is Map && data.containsKey('data')) ? data['data']['admins'] : data['admins'] ?? [];
        if (mounted) {
          state = state.copyWith(groupAdminIds: admins.map((e) => e.toString()).toList());
        }
      }
    } catch (e) {
      debugPrint("Failed to fetch group admins: $e");
    }
  }

  // ✅ UPDATED: Correctly parses the nested API response
  Future<String?> _findOrCreateConversation() async {
    try {
      final result = await _api.post('/api/chat/start', {
        'receiverId': receiverId, 
        'groupId': isGroup ? groupId : null
      });
      
      if (result['success'] == true && result['data'] != null) {
        final body = result['data']; // This is the API body: {success: true, data: {...}}
        
        // Check if the body itself has a 'data' field (Double wrapping)
        final innerData = (body is Map && body.containsKey('data')) ? body['data'] : body;
        
        // Try both _id and id
        final newId = innerData['_id'] ?? innerData['id'];
        
        if (newId == null) {
          debugPrint("❌ CRITICAL: ID Missing. Parsed Body: $innerData");
          throw Exception("Server returned success but ID is missing in response.");
        }

        if (mounted) {
          state = state.copyWith(conversationId: newId.toString());
          await loadMessages(initial: true);
        }
        return newId.toString();
      } else {
        throw Exception(result['message'] ?? "Unknown server error");
      }
    } catch (e) {
      debugPrint("❌ Chat Initialization Error: $e");
      rethrow; 
    }
  }

  Future<void> loadMessages({bool initial = false}) async {
    if (state.conversationId == null) return;
    if (initial && mounted) state = state.copyWith(isLoading: true);

    try {
      final result = await _api.get('/api/chat/${state.conversationId}');
      
      if (result['success'] == true) {
        // ✅ Handle nested data for GET requests too
        final body = result['data'];
        final rawList = (body is Map && body.containsKey('data')) ? body['data'] : body;

        if (rawList is List) {
          final newMessages = rawList.map((m) => ChatMessage.fromJson(m)).toList();
          
          if (mounted) {
            state = state.copyWith(
              messages: newMessages,
              isLoading: false,
              hasMoreMessages: newMessages.length >= 20
            );
            if (initial) _markRead();
          }
        }
      } else if (result['statusCode'] == 403) {
        if (mounted) state = state.copyWith(isKicked: true);
      }
    } catch (e) {
      debugPrint("Load Messages Error: $e");
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  Future<void> loadMoreMessages() async {
    if (!mounted || state.isLoadingMore || !state.hasMoreMessages || state.messages.isEmpty || state.conversationId == null) return;
    
    state = state.copyWith(isLoadingMore: true);
    String oldestId = state.messages.first.id;
    
    try {
      final result = await _api.get('/api/chat/${state.conversationId}?beforeId=$oldestId');
      if (result['success'] == true) {
        // ✅ Handle nested data here as well
        final body = result['data'];
        final rawList = (body is Map && body.containsKey('data')) ? body['data'] : body;

        if (rawList is List) {
          final olderMessages = rawList.map((m) => ChatMessage.fromJson(m)).toList();
          
          if (mounted) {
            if (olderMessages.isEmpty) {
              state = state.copyWith(hasMoreMessages: false, isLoadingMore: false);
            } else {
              state = state.copyWith(
                messages: [...olderMessages, ...state.messages],
                isLoadingMore: false
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<bool> editMessage(String messageId, String newText) async {
    try {
      await _api.put('/api/chat/message/$messageId', {'text': newText});
      if (!mounted) return true;

      final updated = state.messages.map((m) {
        if (m.id == messageId) {
          m.text = newText;
          m.isEdited = true;
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updated);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ✅ UPDATED: Captures errors and displays them
  Future<String?> sendMessage({
    String? text, 
    String? filePath, 
    Uint8List? fileBytes, 
    String? fileName, 
    String type = 'text', 
    String? replyToId,
    ChatMessage? replyingToMessage,
  }) async {
    if (!mounted) return "View disposed";

    // 1. AUTO-INITIALIZE CHAT if missing
    String? currentConvId = state.conversationId;
    if (currentConvId == null) {
      try {
        currentConvId = await _findOrCreateConversation();
      } catch (e) {
        return "Chat Init Failed: ${e.toString().replaceAll('Exception: ', '')}";
      }
      
      if (currentConvId == null) return "Could not start conversation";
    }

    final token = await _auth.getToken();
    if (token == null) return "Authentication error";

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final tempMessage = ChatMessage(
      id: tempId,
      senderId: state.myUserId,
      text: text ?? "",
      type: type,
      fileUrl: filePath,
      fileName: fileName ?? (filePath != null ? filePath.split('/').last : "File"),
      localBytes: fileBytes,
      replyToId: replyToId,
      replyToText: replyingToMessage?.text,
      replyToSenderName: replyingToMessage != null ? (replyingToMessage.senderId == state.myUserId ? "You" : "User") : null,
      replyToType: replyingToMessage?.type,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );

    // Optimistic Update
    state = state.copyWith(messages: [...state.messages, tempMessage]);

    try {
      final baseUrl = AppConfig.baseUrl.endsWith('/')
          ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
          : AppConfig.baseUrl;

      final url = Uri.parse('$baseUrl/api/chat/$currentConvId');
      
      var request = http.MultipartRequest('POST', url);
      request.headers['auth-token'] = token; 

      request.fields['text'] = text ?? ""; 
      request.fields['type'] = type;
      if (replyToId != null) request.fields['replyToId'] = replyToId;

      if (fileBytes != null) {
        request.files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: fileName ?? 'upload'));
      } else if (filePath != null) {
        request.files.add(await http.MultipartFile.fromPath('file', filePath));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return null; 

      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body);
          final realMessage = ChatMessage.fromJson(data);
          
          final updated = state.messages.map((m) => m.id == tempId ? realMessage : m).toList();
          state = state.copyWith(messages: updated);
          return null; // Success
        } catch (e) {
          return "Server response error";
        }
      } else {
        _markMessageError(tempId);
        try {
          final errBody = jsonDecode(response.body);
          return "Failed: ${errBody['message'] ?? response.statusCode}";
        } catch (_) {
          return "Failed: ${response.statusCode}";
        }
      }
    } catch (e) {
      if (mounted) _markMessageError(tempId);
      return "Connection error: ${e.toString()}";
    }
  }

  void _markMessageError(String tempId) {
    if (!mounted) return;
    final updated = state.messages.map((m) {
      if (m.id == tempId) {
        m.status = MessageStatus.error;
      }
      return m;
    }).toList();
    state = state.copyWith(messages: updated);
  }

  void _markRead() {
    if (state.conversationId != null) {
      _api.put('/api/chat/read/${state.conversationId}', {});
    }
  }

  void _setupSocketListeners() {
    final socket = _socket.socket;
    if (socket == null) return;

    socket.on('new_message', (data) {
      if (!mounted) return;
      if (data['conversationId'] == state.conversationId) {
        try {
          final newMessage = ChatMessage.fromJson(data['message']);
          if (newMessage.senderId == state.myUserId) return; 
          if (state.messages.any((m) => m.id == newMessage.id)) return;

          state = state.copyWith(
            messages: [...state.messages, newMessage],
            isPeerTyping: false
          );
          _markRead();
        } catch (e) {
          debugPrint("Error parsing incoming message: $e");
        }
      }
    });

    socket.on('messages_read', (data) {
      if (mounted && data['conversationId'] == state.conversationId) {
        final updated = state.messages.map((m) {
          if (m.senderId == state.myUserId) m.isRead = true;
          return m;
        }).toList();
        state = state.copyWith(messages: updated);
      }
    });

    socket.on('typing_start', (data) {
      if (mounted && data['conversationId'] == state.conversationId && data['senderId'] != state.myUserId) {
        state = state.copyWith(isPeerTyping: true);
      }
    });

    socket.on('typing_stop', (data) {
      if (mounted && data['conversationId'] == state.conversationId && data['senderId'] != state.myUserId) {
        state = state.copyWith(isPeerTyping: false);
      }
    });

    socket.on('messages_deleted_bulk', (data) {
      if (mounted && data['conversationId'] == state.conversationId) {
        List<dynamic> ids = data['messageIds'];
        final updated = state.messages.where((m) => !ids.contains(m.id)).toList();
        state = state.copyWith(messages: updated);
      }
    });

    socket.on('removed_from_group', (data) {
      if (mounted && isGroup && groupId == data['groupId']) {
        state = state.copyWith(isKicked: true);
      }
    });
    
    if (!isGroup) {
      _statusSubscription = _socket.userStatusStream.listen((data) {
        if (!mounted) return;
        if (data['userId'] == receiverId) {
          state = state.copyWith(
            isPeerOnline: data['isOnline'],
            peerLastSeen: !data['isOnline'] ? data['lastSeen'] : state.peerLastSeen
          );
          if (data['isOnline']) _statusTimer?.cancel();
        }
      });
    }
  }

  void sendTyping() {
    if (state.conversationId != null) {
      _socket.socket?.emit('typing', {
        'receiverId': receiverId,
        'conversationId': state.conversationId,
        'groupId': isGroup ? groupId : null
      });
    }
  }

  void _stopTyping() {
    try {
      if (state.conversationId != null) {
        _socket.socket?.emit('stop_typing', {
          'receiverId': receiverId,
          'conversationId': state.conversationId,
          'groupId': isGroup ? groupId : null
        });
      }
    } catch (_) {} 
  }

  void _startStatusPolling() {
    _checkStatusSafe();
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) {
        _statusTimer?.cancel();
        return;
      }
      if (!state.isPeerOnline) _checkStatusSafe();
    });
  }

  void _checkStatusSafe() {
    if(!isGroup) _socket.checkUserStatus(receiverId);
  }
  
  Future<void> deleteMessages(List<String> ids) async {
    final updated = state.messages.where((m) => !ids.contains(m.id)).toList();
    if (mounted) state = state.copyWith(messages: updated);
    try {
      await _api.post('/api/chat/delete-multiple', {'messageIds': ids, 'deleteForEveryone': false});
    } catch (_) {}
  }
}

final chatDetailProvider = StateNotifierProvider.family.autoDispose<ChatDetailNotifier, ChatDetailState, Map<String, dynamic>>((ref, args) {
  return ChatDetailNotifier(
    receiverId: args['receiverId'],
    isGroup: args['isGroup'] ?? false,
    groupId: args['groupId'],
    conversationId: args['conversationId'],
    initialIsOnline: args['isOnline'] ?? false,
    initialLastSeen: args['lastSeen'],
  );
});