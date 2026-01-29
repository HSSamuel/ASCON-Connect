import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config.dart';
import '../config/storage_config.dart'; 

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
    // If we go to background, we disconnect to save battery.
    // The backend now has a 1-second "Grace Period". 
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      disconnect();
    } else if (state == AppLifecycleState.resumed) {
      // Force reconnect immediately on resume
      initSocket();
    }
  }

  void initSocket({bool forceNew = false}) async {
    // 1. Check if already connected (Avoid unnecessary reconnection)
    if (socket != null && socket!.connected) {
      debugPrint("🟢 Socket is already connected.");
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

    // Only print this once to reduce noise
    if (socket == null) debugPrint("🔌 Socket Connecting to: $socketUrl");

    try {
      // 2. Create Socket if it doesn't exist
      if (socket == null) {
        socket = IO.io(socketUrl, <String, dynamic>{
          'transports': ['websocket'], // Force WebSocket for better performance
          'autoConnect': false,
          'timeout': 30000,            // ✅ INCREASED: 30s timeout (was default 20s)
          // 'forceNew': true,         // ❌ REMOVED: Caused thrashing/timeouts
          'reconnection': true,
          'reconnectionDelay': 2000,   // ✅ INCREASED: Wait 2s before retrying (was 1s)
          'reconnectionDelayMax': 10000,
          'reconnectionAttempts': 99999,
        });

        // --- EVENT LISTENERS ---
        socket!.onConnect((_) {
          debugPrint('✅ Socket Connected');
          if (userId != null) {
            socket!.emit("user_connected", userId);
          }
        });

        socket!.onReconnect((_) {
           debugPrint('🔄 Socket Reconnected');
           if (userId != null) {
            socket!.emit("user_connected", userId);
          }
        });

        socket!.onDisconnect((_) => debugPrint('❌ Socket Disconnected'));
        
        // ✅ Refined Error Handling: Ignore "timeout" noise
        socket!.onConnectError((data) {
          if (data.toString().contains("timeout")) {
            // calculated silence: do not log standard timeouts
          } else {
            debugPrint('⚠️ Socket Error: $data');
          }
        });
      }

      // 3. Connect!
      if (!socket!.connected) {
        socket!.connect();
      }

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