import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart'; // ✅ Imports AppConfig

class SocketService {
  late IO.Socket socket;
  final _storage = const FlutterSecureStorage();

  // Make this a singleton so we can access it anywhere
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  void initSocket() async {
    String? userId = await _storage.read(key: "userId"); 
    
    // ✅ FIX: Use AppConfig instead of Config
    // We strip '/api' because Socket.io connects to the root server URL
    final String socketUrl = AppConfig.baseUrl.replaceAll('/api', '');

    socket = IO.io(socketUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      print('✅ Socket Connected');
      if (userId != null) {
        socket.emit("user_connected", userId);
      }
    });

    socket.onDisconnect((_) => print('❌ Socket Disconnected'));
  }

  // Call this after Login/Register to connect immediately
  void connectUser(String userId) {
    if (socket.connected) {
      socket.emit("user_connected", userId);
    } else {
      initSocket();
    }
  }

  void disconnect() {
    socket.disconnect();
  }
}