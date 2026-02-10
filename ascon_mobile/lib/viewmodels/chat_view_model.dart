import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/socket_service.dart';

class ChatState {
  final List<dynamic> conversations;
  final List<dynamic> filteredConversations;
  final List<dynamic> onlineUsers;
  final bool isLoading;
  final String myId;
  final Map<String, bool> typingStatus;

  const ChatState({
    this.conversations = const [],
    this.filteredConversations = const [],
    this.onlineUsers = const [],
    this.isLoading = true,
    this.myId = "",
    this.typingStatus = const {},
  });

  ChatState copyWith({
    List<dynamic>? conversations,
    List<dynamic>? filteredConversations,
    List<dynamic>? onlineUsers,
    bool? isLoading,
    String? myId,
    Map<String, bool>? typingStatus,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      filteredConversations: filteredConversations ?? this.filteredConversations,
      onlineUsers: onlineUsers ?? this.onlineUsers,
      isLoading: isLoading ?? this.isLoading,
      myId: myId ?? this.myId,
      typingStatus: typingStatus ?? this.typingStatus,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ApiClient _api = ApiClient();
  final AuthService _auth = AuthService();
  final SocketService _socket = SocketService();

  ChatNotifier() : super(const ChatState()) {
    init();
  }

  Future<void> init() async {
    final id = await _auth.currentUserId ?? "";
    state = state.copyWith(myId: id);
    await loadConversations();
    _setupSocket();
  }

  Future<void> loadConversations() async {
    try {
      final res = await _api.get('/api/chat');
      if (res['success'] == true) {
        final List<dynamic> data = res['data'];
        
        final online = data.where((c) {
           final other = _getOtherParticipant(c, state.myId);
           return other['isOnline'] == true;
        }).take(10).toList();

        if (mounted) {
          state = state.copyWith(
            conversations: data,
            filteredConversations: data,
            onlineUsers: online,
            isLoading: false
          );
        }
      }
    } catch (_) {
      if (mounted) state = state.copyWith(isLoading: false);
    }
  }

  void searchConversations(String query) {
    if (query.isEmpty) {
      state = state.copyWith(filteredConversations: state.conversations);
    } else {
      final filtered = state.conversations.where((c) {
        final other = _getOtherParticipant(c, state.myId);
        final name = (other['fullName'] ?? other['name'] ?? "").toString().toLowerCase();
        
        String lastMsgText = "";
        if (c['lastMessage'] is Map) {
          lastMsgText = c['lastMessage']['text'] ?? "";
        } else {
          lastMsgText = c['lastMessage'].toString();
        }
        
        return name.contains(query.toLowerCase()) || lastMsgText.toLowerCase().contains(query.toLowerCase());
      }).toList();
      state = state.copyWith(filteredConversations: filtered);
    }
  }

  Future<void> deleteConversation(String id) async {
    try {
      final newConvs = state.conversations.where((c) => c['_id'] != id).toList();
      state = state.copyWith(conversations: newConvs, filteredConversations: newConvs);
      await _api.delete('/api/chat/conversation/$id');
    } catch (_) {}
  }

  void _setupSocket() {
    final socket = _socket.socket;
    if (socket == null) return;

    socket.on('new_message', (data) {
      if (!mounted) return;
      _handleIncomingMessage(data);
    });

    socket.on('messages_read', (data) {
      if (!mounted) return;
      final convId = data['conversationId'];
      final updated = List<dynamic>.from(state.conversations);
      final index = updated.indexWhere((c) => c['_id'] == convId);
      if (index != -1) {
        updated[index] = Map.from(updated[index])..['unreadCount'] = 0;
        state = state.copyWith(conversations: updated, filteredConversations: updated);
      }
    });

    socket.on('typing_start', (data) {
      if (mounted) {
        final newStatus = Map<String, bool>.from(state.typingStatus);
        newStatus[data['conversationId']] = true;
        state = state.copyWith(typingStatus: newStatus);
      }
    });

    socket.on('typing_stop', (data) {
      if (mounted) {
        final newStatus = Map<String, bool>.from(state.typingStatus);
        newStatus[data['conversationId']] = false;
        state = state.copyWith(typingStatus: newStatus);
      }
    });
  }

  void _handleIncomingMessage(dynamic data) {
    final convId = data['conversationId'];
    final updated = List<dynamic>.from(state.conversations);
    final index = updated.indexWhere((c) => c['_id'] == convId);

    if (index != -1) {
      var chat = Map<String, dynamic>.from(updated.removeAt(index));
      chat['lastMessage'] = data['message']['text'] ?? "Media";
      chat['lastMessageAt'] = data['message']['createdAt'];
      
      if (data['message']['senderId'] != state.myId) {
        chat['unreadCount'] = (chat['unreadCount'] ?? 0) + 1;
      }

      updated.insert(0, chat);
      state = state.copyWith(conversations: updated, filteredConversations: updated);
    } else {
      loadConversations();
    }
  }

  // Helper
  Map<String, dynamic> _getOtherParticipant(Map<String, dynamic> conversation, String myId) {
    if (conversation['isGroup'] == true) {
      final group = conversation['groupId'];
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
      (p) => p['_id'] != myId,
      orElse: () => {'fullName': 'Unknown User', 'profilePicture': ''},
    );
    return other;
  }
}

final chatProvider = StateNotifierProvider.autoDispose<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});