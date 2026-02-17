import 'dart:async';
import 'package:flutter/foundation.dart'; // ✅ Required for kIsWeb & defaultTargetPlatform
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; 
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
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

  final _messageStatusController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStatusStream => _messageStatusController.stream;

  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  SocketService._internal() {
    WidgetsBinding.instance.addObserver(this);
    
    // ✅ FIXED: Check Platform safely for Web compatibility
    bool isMobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
    if (!kIsWeb && isMobile) {
      _setupCallKitListener();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _storage.read(key: "auth_token").then((token) {
        if (token != null && (socket == null || !socket!.connected)) {
          initSocket();
        }
      });
    }
  }

  IO.Socket? getSocket() {
    return socket;
  }

  void _setupCallKitListener() {
    try {
      FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
        if (event == null) return;
        
        switch (event.event) {
          case Event.actionCallAccept:
            final data = event.body['extra'];
            if (data != null) {
               SchedulerBinding.instance.addPostFrameCallback((_) {
                  if (rootNavigatorKey.currentState != null) {
                    try {
                      appRouter.push('/call', extra: {
                        'remoteName': data['callerName'] ?? "Unknown Caller",
                        'remoteId': data['callerId'] ?? "Unknown",
                        'remoteAvatar': data['callerPic'],
                        'isCaller': false,
                        'offer': data['offer'],
                        'callLogId': data['callLogId'], 
                      });
                    } catch (e) {
                      debugPrint("❌ Navigation Failed (CallKit): $e");
                    }
                  }
               });
            }
            break;
            
          case Event.actionCallDecline:
             if (event.body['extra'] != null && event.body['extra']['callLogId'] != null) {
               socket?.emit('end_call', {'callLogId': event.body['extra']['callLogId']});
             }
             break;
          default:
            break;
        }
      });
    } catch (e) {
      debugPrint("⚠️ CallKit Listener Error: $e");
    }
  }

  Future<void> initSocket({String? userIdOverride}) async {
    String? token = await _storage.read(key: "auth_token");
    if (userIdOverride != null) {
      _currentUserId = userIdOverride;
    } else {
      _currentUserId = await _storage.read(key: "userId");
    }

    if (token == null || _currentUserId == null) {
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
        'timeout': AppConfig.socketTimeoutMs,
        'reconnection': true,
        'reconnectionDelay': AppConfig.socketReconnectionDelayMs,
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

    socket!.on('new_message', (data) {
      if (data != null && data['message'] != null && data['conversationId'] != null) {
        final msgId = data['message']['_id'] ?? data['message']['id'];
        final senderId = data['message']['sender'] is Map 
            ? data['message']['sender']['_id'] 
            : data['message']['sender'];

        if (senderId != _currentUserId) {
          markMessageAsDelivered(msgId, data['conversationId']);
        }
      }
    });

    socket!.on('messages_read_update', (data) {
       _messageStatusController.add({'type': 'read', 'data': data});
    });

    socket!.on('message_status_update', (data) {
       _messageStatusController.add({'type': 'status_update', 'data': data});
    });

    socket!.on('call_made', (data) async {
      debugPrint("📞 INCOMING CALL EVENT (Socket): $data");
      
      bool isBackground = WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
      
      // ✅ FIXED: Using defaultTargetPlatform for Desktop check
      bool isDesktop = !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS);

      if (!isBackground || isDesktop) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (rootNavigatorKey.currentState != null) {
            try {
              appRouter.push('/call', extra: {
                'remoteName': data['callerName'] ?? "Unknown",
                'remoteId': data['callerId'] ?? "Unknown",
                'remoteAvatar': data['callerPic'],
                'isCaller': false,
                'offer': data['offer'],
                'callLogId': data['callLogId'], 
              });
            } catch (e) {
              debugPrint("❌ Navigation Failed: $e");
            }
          }
        });
      } else {
        debugPrint("💤 App in background (Mobile). Waiting for FCM.");
      }
    });

    socket!.on('answer_made', (data) {
      debugPrint("✅ Call Answered by Peer");
      _callEventsController.add({'type': 'answer_made', 'data': data});
    });
    
    socket!.on('call_ended_remote', (data) {
      _callEventsController.add({'type': 'call_ended_remote', 'data': data});
    });

    socket!.on('ice_candidate_received', (data) {
      _callEventsController.add({'type': 'ice_candidate', 'data': data});
    });
    
    socket!.on('call_failed', (data) {
      _callEventsController.add({'type': 'call_failed', 'data': data});
    });

    socket!.onDisconnect((_) => debugPrint('❌ Socket Disconnected'));
    socket!.onError((data) => debugPrint('⚠️ Socket Error: $data'));
  }

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