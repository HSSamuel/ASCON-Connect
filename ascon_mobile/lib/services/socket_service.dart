import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // ✅ Needed for SchedulerBinding
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import '../config/storage_config.dart';
import '../router.dart'; 

class SocketService with WidgetsBindingObserver {
  IO.Socket? socket;
  final _storage = StorageConfig.storage;
  String? _currentUserId;
  String? _connectedUserId; 

  final _userStatusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get userStatusStream => _userStatusController.stream;

  final _callEventsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get callEvents => _callEventsController.stream;

  // ✅ New Streams for Status Updates
  final _messageStatusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStatusStream => _messageStatusController.stream;

  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  SocketService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (socket == null || !socket!.connected) {
        initSocket();
      }
    }
  }

  IO.Socket? getSocket() {
    return socket;
  }

  Future<void> initSocket({String? userIdOverride}) async {
    String? token = await _storage.read(key: "auth_token");
    if (userIdOverride != null) {
      _currentUserId = userIdOverride;
    } else {
      _currentUserId = await _storage.read(key: "userId");
    }

    if (token == null || _currentUserId == null) {
      debugPrint("⚠️ Socket Init Skipped: Missing Token or UserId");
      return;
    }

    String socketUrl = AppConfig.baseUrl;
    if (socketUrl.endsWith('/')) socketUrl = socketUrl.substring(0, socketUrl.length - 1);
    if (socketUrl.endsWith('/api')) socketUrl = socketUrl.replaceAll('/api', '');

    if (socket == null || _connectedUserId != _currentUserId) {
      if (socket != null) {
        socket!.disconnect();
        socket!.dispose();
      }

      debugPrint("🔌 Socket Connecting to: $socketUrl as User: $_currentUserId");

      socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'timeout': 20000,
        'reconnection': true,
        'reconnectionDelay': 1000,
        'auth': {'token': token},
        'query': {'userId': _currentUserId},
      });

      _setupListeners();
      socket!.connect();
      _connectedUserId = _currentUserId;
    } else if (!socket!.connected) {
      socket!.connect();
    }
  }

  void _setupListeners() {
    if (socket == null) return;

    socket!.onConnect((_) {
      debugPrint('✅ Socket Connected');
      if (_currentUserId != null) {
        socket!.emit("user_connected", _currentUserId);
      }
    });

    socket!.onReconnect((_) {
      debugPrint('🔄 Socket Reconnected');
      if (_currentUserId != null) {
        socket!.emit("user_connected", _currentUserId);
      }
    });

    socket!.on('user_status_update', (data) {
      if (data != null) _userStatusController.add(Map<String, dynamic>.from(data));
    });

    socket!.on('user_status_result', (data) {
      if (data != null) _userStatusController.add(Map<String, dynamic>.from(data));
    });

    // ✅ Listen for incoming messages to send Delivery Receipts
    socket!.on('new_message', (data) {
      // Auto-acknowledge delivery immediately
      if (data != null && data['message'] != null && data['conversationId'] != null) {
        final msgId = data['message']['_id'] ?? data['message']['id'];
        final senderId = data['message']['sender'] is Map 
            ? data['message']['sender']['_id'] 
            : data['message']['sender'];

        // Only mark delivered if I am NOT the sender
        if (senderId != _currentUserId) {
          markMessageAsDelivered(msgId, data['conversationId']);
        }
      }
    });

    // ✅ Listen for updates to MY sent messages (Sent -> Delivered / Read)
    socket!.on('messages_read_update', (data) {
       _messageStatusController.add({'type': 'read', 'data': data});
    });

    socket!.on('message_status_update', (data) {
       _messageStatusController.add({'type': 'status_update', 'data': data});
    });

    // ============================================
    // 📞 CALL SIGNALING EVENTS (CRASH FIX)
    // ============================================

    socket!.on('call_made', (data) {
      debugPrint("📞 INCOMING CALL RECEIVED! Payload: $data");
      
      // ✅ FIX 1: Use SchedulerBinding to ensure we are not in the middle of a build
      SchedulerBinding.instance.addPostFrameCallback((_) {
        // ✅ FIX 2: Check if Navigator is mounted before pushing
        if (rootNavigatorKey.currentState != null) {
          try {
            debugPrint("🚀 Safe Navigation to CallScreen...");
            appRouter.push('/call', extra: {
              'remoteName': data['callerName'] ?? "Unknown Caller",
              'remoteId': data['callerId'] ?? "Unknown",
              'remoteAvatar': data['callerPic'],
              'isCaller': false,
              'offer': data['offer'],
            });
          } catch (e) {
            debugPrint("❌ Navigation Failed: $e");
          }
        } else {
          debugPrint("⚠️ Navigator not ready. Call notification missed.");
        }
      });
    });

    socket!.on('answer_made', (data) {
      debugPrint("✅ Call Answered by Peer");
      _callEventsController.add({'type': 'answer_made', 'data': data});
    });

    socket!.on('ice_candidate_received', (data) {
      _callEventsController.add({'type': 'ice_candidate', 'data': data});
    });

    socket!.onDisconnect((_) => debugPrint('❌ Socket Disconnected'));
    socket!.onError((data) => debugPrint('⚠️ Socket Error: $data'));
  }

  // ✅ New Methods for Status Updates

  void markMessagesAsRead(String chatId, List<String> messageIds, String userId) {
    if (socket != null && socket!.connected) {
      socket!.emit('mark_messages_read', {
        'chatId': chatId,
        'messageIds': messageIds,
        'userId': userId,
      });
    }
  }

  void markMessageAsDelivered(String messageId, String chatId) {
    if (socket != null && socket!.connected) {
      socket!.emit('message_delivered', {
        'messageId': messageId,
        'chatId': chatId,
      });
    }
  }

  void checkUserStatus(String targetUserId) {
    if (socket != null && socket!.connected) {
      socket!.emit("check_user_status", {'userId': targetUserId});
    }
  }

  void connectUser(String userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      initSocket(userIdOverride: userId);
    }
  }

  void logoutUser() {
    if (socket != null && _currentUserId != null) {
      socket!.emit('user_logout', _currentUserId);
      Future.delayed(const Duration(milliseconds: 100), () {
        disconnect();
        _currentUserId = null;
      });
    } else {
      disconnect();
      _currentUserId = null;
    }
  }

  void disconnect() {
    if (socket != null) {
      socket!.disconnect();
      socket = null;
      _connectedUserId = null;
    }
  }
}