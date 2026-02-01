import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import '../config/storage_config.dart'; 

class SocketService with WidgetsBindingObserver {
  IO.Socket? socket; 
  final _storage = StorageConfig.storage;
  
  // ✅ Cache User ID in memory to avoid async storage delays during login
  String? _currentUserId;

  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  
  SocketService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Background: Disconnect to save battery (Backend handles grace period)
      disconnect();
    } else if (state == AppLifecycleState.resumed) {
      // Foreground: Reconnect immediately
      initSocket();
    }
  }

  // ✅ Modified: accept optional userId to skip storage read
  void initSocket({String? userIdOverride}) async {
    // 1. Update in-memory ID if provided
    if (userIdOverride != null) {
      _currentUserId = userIdOverride;
    }

    // 2. If still null, try reading from storage (for app restarts)
    if (_currentUserId == null) {
      _currentUserId = await _storage.read(key: "userId");
    }

    // 3. Prepare URL
    String socketUrl = AppConfig.baseUrl;
    if (socketUrl.endsWith('/')) {
      socketUrl = socketUrl.substring(0, socketUrl.length - 1);
    }
    if (socketUrl.endsWith('/api')) {
      socketUrl = socketUrl.replaceAll('/api', '');
    }

    // 4. Create Socket if missing
    if (socket == null) {
      debugPrint("🔌 Socket Connecting to: $socketUrl");
      
      socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'timeout': 30000,
        'reconnection': true,
        'reconnectionDelay': 2000,
        'reconnectionDelayMax': 10000,
        'reconnectionAttempts': 99999,
      });

      // --- EVENT LISTENERS ---
      socket!.onConnect((_) {
        debugPrint('✅ Socket Connected');
        _emitUserConnected();
      });

      socket!.onReconnect((_) {
         debugPrint('🔄 Socket Reconnected');
         _emitUserConnected();
      });

      socket!.onDisconnect((_) => debugPrint('❌ Socket Disconnected'));
      
      socket!.onConnectError((data) {
        if (!data.toString().contains("timeout")) {
          debugPrint('⚠️ Socket Error: $data');
        }
      });
    }

    // 5. Force Connect if disconnected
    if (!socket!.connected) {
      socket!.connect();
    } else {
      // If already connected, ensure we identify ourselves
      _emitUserConnected();
    }
  }

  // ✅ Helper to identify user to server
  void _emitUserConnected() {
    if (_currentUserId != null && socket != null) {
      // debugPrint("📤 Identifying as User: $_currentUserId");
      socket!.emit("user_connected", _currentUserId);
    }
  }

  // ✅ Call this from Login/Register to connect INSTANTLY
  void connectUser(String userId) {
    _currentUserId = userId; // Set memory cache immediately
    if (socket != null && socket!.connected) {
      _emitUserConnected();
    } else {
      initSocket(userIdOverride: userId);
    }
  }

  // ✅ Call this from Logout
  void logoutUser() {
    if (socket != null && _currentUserId != null) {
      // Tell server we are leaving deliberately (no grace period)
      socket!.emit('user_logout', _currentUserId);
      
      // Give a tiny delay for the packet to send before cutting connection
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
    }
  }
}