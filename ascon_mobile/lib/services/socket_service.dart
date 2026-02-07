import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import '../config/storage_config.dart';

class SocketService with WidgetsBindingObserver {
  IO.Socket? socket;
  final _storage = StorageConfig.storage;
  String? _currentUserId;

  // 1️⃣ Stream Controller to broadcast updates to UI
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
      // Re-check connection when coming back
      if (socket == null || !socket!.connected) {
        initSocket();
      }
    }
  }

  // ✅ NEW: Getter for the Socket instance (Required by PollsScreen)
  IO.Socket getSocket() {
    if (socket == null) {
      // Initialize immediately if accessed before init
      initSocket();
    }
    // We assume initSocket creates the object synchronously (see below)
    return socket!;
  }

  void initSocket({String? userIdOverride}) {
    // 1. Prepare URL
    String socketUrl = AppConfig.baseUrl;
    if (socketUrl.endsWith('/')) socketUrl = socketUrl.substring(0, socketUrl.length - 1);
    if (socketUrl.endsWith('/api')) socketUrl = socketUrl.replaceAll('/api', '');

    // 2. Create Socket Object Synchronously (so getSocket() never fails)
    if (socket == null) {
      debugPrint("🔌 Socket Connecting to: $socketUrl");

      socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'timeout': 20000, 
        'reconnection': true,
        'reconnectionDelay': 1000,
      });

      // 3. Setup Listeners
      socket!.onConnect((_) {
        debugPrint('✅ Socket Connected');
        _emitUserConnected();
      });

      socket!.onReconnect((_) {
        debugPrint('🔄 Socket Reconnected');
        _emitUserConnected();
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
    }

    // 4. Handle Auth & Connection (Async part)
    _finalizeConnection(userIdOverride);
  }

  Future<void> _finalizeConnection(String? userIdOverride) async {
    if (userIdOverride != null) _currentUserId = userIdOverride;
    if (_currentUserId == null) _currentUserId = await _storage.read(key: "userId");

    if (socket != null && !socket!.connected) {
      socket!.connect();
    } else {
      _emitUserConnected();
    }
  }

  void _emitUserConnected() {
    if (_currentUserId != null && socket != null) {
      socket!.emit("user_connected", _currentUserId);
    }
  }

  void checkUserStatus(String targetUserId) {
    if (socket != null && socket!.connected && _currentUserId != null) {
      socket!.emit("check_user_status", {'userId': targetUserId});
    }
  }

  void connectUser(String userId) {
    _currentUserId = userId;
    if (socket != null && socket!.connected) {
      _emitUserConnected();
    } else {
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