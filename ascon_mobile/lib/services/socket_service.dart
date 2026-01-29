import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import '../config/storage_config.dart'; // ✅ Uses Central Config

class SocketService with WidgetsBindingObserver {
  IO.Socket? socket; 
  final _storage = StorageConfig.storage;

  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  
  SocketService._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("🔄 App Lifecycle Changed: $state");
    
    // ✅ Logic Updated:
    // If we go to background, we disconnect to save battery.
    // The backend now has a 5-second "Grace Period". 
    // If the user quickly switches back (within 5s), the 'Offline' status will NEVER fire.
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      disconnect();
    } else if (state == AppLifecycleState.resumed) {
      // Force reconnect immediately on resume
      initSocket(forceNew: true);
    }
  }

  void initSocket({bool forceNew = false}) async {
    if (!forceNew && socket != null && socket!.connected) {
      return; 
    }

    String? userId = await _storage.read(key: "userId");
    
    // Safety check for URL
    String socketUrl = AppConfig.baseUrl;
    if (socketUrl.endsWith('/')) {
      socketUrl = socketUrl.substring(0, socketUrl.length - 1);
    }
    if (socketUrl.endsWith('/api')) {
      socketUrl = socketUrl.replaceAll('/api', '');
    }

    debugPrint("🔌 Socket Connecting to: $socketUrl");

    try {
      socket = IO.io(socketUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': false,
        'forceNew': true, // ✅ Ensure fresh connection logic
        'reconnection': true,
        'reconnectionDelay': 1000,
        'reconnectionDelayMax': 5000,
        'reconnectionAttempts': 99999,
      });

      socket!.connect();

      socket!.onConnect((_) {
        debugPrint('✅ Socket Connected');
        if (userId != null) {
          // Re-announce presence immediately
          socket!.emit("user_connected", userId);
        }
      });

      // Handle Reconnect explicitly
      socket!.onReconnect((_) {
         debugPrint('🔄 Socket Reconnected');
         if (userId != null) {
          socket!.emit("user_connected", userId);
        }
      });

      socket!.onDisconnect((_) => debugPrint('❌ Socket Disconnected'));
      socket!.onConnectError((data) => debugPrint('⚠️ Socket Error: $data'));

    } catch (e) {
      debugPrint("❌ CRITICAL SOCKET EXCEPTION: $e");
    }
  }

  void connectUser(String userId) {
    if (socket != null && socket!.connected) {
      socket!.emit("user_connected", userId);
    } else {
      initSocket();
    }
  }

  void disconnect() {
    if (socket != null) {
      socket!.disconnect();
    }
  }
}