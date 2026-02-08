import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import '../config/storage_config.dart';

class SocketService with WidgetsBindingObserver {
  IO.Socket? socket;
  final _storage = StorageConfig.storage;
  String? _currentUserId;

  // Stream Controller to broadcast updates to UI
  final _userStatusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get userStatusStream => _userStatusController.stream;

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

  // Getter for the Socket instance
  IO.Socket getSocket() {
    if (socket == null) {
      initSocket();
    }
    return socket!;
  }

  Future<void> initSocket({String? userIdOverride}) async {
    // 1. Resolve User ID
    if (userIdOverride != null) {
      _currentUserId = userIdOverride;
    } else {
      _currentUserId = await _storage.read(key: "userId");
    }

    if (_currentUserId == null) {
      debugPrint("⚠️ Socket Init Skipped: No User ID found.");
      return;
    }

    // 2. Prepare URL
    String socketUrl = AppConfig.baseUrl;
    if (socketUrl.endsWith('/')) socketUrl = socketUrl.substring(0, socketUrl.length - 1);
    if (socketUrl.endsWith('/api')) socketUrl = socketUrl.replaceAll('/api', '');

    // 3. Create Socket Connection
    // Check if socket exists and if the user ID has changed or it's disconnected
    if (socket == null || socket!.io.options?['query']?['userId'] != _currentUserId) {
      // If recreating, disconnect old one first
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
        // ✅ CRITICAL FIX: Send User ID in the handshake query
        'query': {'userId': _currentUserId},
      });

      _setupListeners();
      socket!.connect();
    } else if (!socket!.connected) {
      socket!.connect();
    }
  }

  void _setupListeners() {
    if (socket == null) return;

    socket!.onConnect((_) {
      debugPrint('✅ Socket Connected');
      // Redundant emit for safety, but handshake handles the primary auth now
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
      if (data != null) {
        _userStatusController.add(Map<String, dynamic>.from(data));
      }
    });

    socket!.on('user_status_result', (data) {
      if (data != null) {
        _userStatusController.add(Map<String, dynamic>.from(data));
      }
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
      // Re-init to update the handshake query
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
    }
  }
}