import 'package:flutter/material.dart'; // ✅ Required for AppLifecycleState
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';

class SocketService with WidgetsBindingObserver {
  // ✅ Changed from 'late' to nullable to safely check connection status
  IO.Socket? socket; 
  
  final _storage = const FlutterSecureStorage();

  // Singleton Instance
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  
  SocketService._internal() {
    // ✅ Register observer to listen to App Background/Foreground changes
    WidgetsBinding.instance.addObserver(this);
  }

  // ✅ LIFECYCLE MANAGER: Solves the "Pocket Problem"
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint("🔄 App Lifecycle Changed: $state");
    
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // App is in background or closed -> Disconnect to show "Offline"
      disconnect();
    } else if (state == AppLifecycleState.resumed) {
      // App is in foreground -> Reconnect to show "Online"
      initSocket();
    }
  }

  void initSocket() async {
    // 1. Safety Check: Don't reconnect if already connected
    if (socket != null && socket!.connected) {
      debugPrint("⚠️ Socket already connected. Skipping init.");
      return;
    }

    String? userId = await _storage.read(key: "userId"); 
    
    // 2. Setup URL (Strip '/api' because Socket.io connects to root)
    final String socketUrl = AppConfig.baseUrl.replaceAll('/api', '');

    // ✅ DEBUG: Print the exact URL we are trying to connect to
    debugPrint("🔌 Socket Connecting to: $socketUrl");

    // 3. Initialize Socket
    socket = IO.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    // 4. Connect
    socket!.connect();

    // 5. Event Listeners
    socket!.onConnect((_) {
      debugPrint('✅ Socket Connected');
      if (userId != null) {
        socket!.emit("user_connected", userId);
      }
    });

    socket!.onDisconnect((_) => debugPrint('❌ Socket Disconnected'));
    
    socket!.onConnectError((data) => debugPrint('⚠️ Socket Error: $data'));
  }

  // Call this after Login/Register to connect immediately
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