import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import '../config/storage_config.dart';
import '../router.dart'; // ✅ Needed for Navigation
import '../screens/call_screen.dart'; // ✅ Needed to open call

class SocketService with WidgetsBindingObserver {
  IO.Socket? socket;
  final _storage = StorageConfig.storage;
  String? _currentUserId;
  String? _connectedUserId; 

  // ✅ 1. General User Status Stream
  final _userStatusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get userStatusStream => _userStatusController.stream;

  // ✅ 2. Call Signaling Stream (Answer, ICE Candidates)
  final _callEventsController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get callEvents => _callEventsController.stream;

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

    if (token == null || _currentUserId == null) return;

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

    // ============================================
    // 📞 CALL SIGNALING EVENTS
    // ============================================

    // 1. INCOMING CALL (Global Navigation)
    socket!.on('call_made', (data) {
      debugPrint("📞 Incoming Call Detected: $data");
      if (rootNavigatorKey.currentState != null) {
        rootNavigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => CallScreen(
              remoteName: "Incoming Call...", 
              remoteId: data['callerId'],
              isCaller: false,
              offer: data['offer'],
            ),
          ),
        );
      }
    });

    // 2. ANSWER RECEIVED (For Caller)
    socket!.on('answer_made', (data) {
      debugPrint("✅ Call Answered by Peer");
      _callEventsController.add({'type': 'answer_made', 'data': data});
    });

    // 3. ICE CANDIDATE (Connectivity)
    socket!.on('ice_candidate_received', (data) {
      // debugPrint("❄️ ICE Candidate Received");
      _callEventsController.add({'type': 'ice_candidate', 'data': data});
    });

    socket!.onDisconnect((_) => debugPrint('❌ Socket Disconnected'));
    socket!.onError((data) => debugPrint('⚠️ Socket Error: $data'));
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