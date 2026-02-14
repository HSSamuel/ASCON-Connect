import 'dart:async';
import 'package:flutter/foundation.dart'; // ✅ Import for kIsWeb
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
    
    // ✅ CRITICAL FIX: Only setup CallKit listener on Mobile (Android/iOS)
    if (!kIsWeb) {
      _setupCallKitListener();
    }
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

  void _setupCallKitListener() {
    // This will only run on mobile now
    try {
      FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
        if (event == null) return;
        
        switch (event.event) {
          case Event.actionCallAccept:
             // ✅ FIX: Navigate to Call Screen when answered from Lock Screen
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
             // ✅ FIX: Emit end_call when declined from Native UI
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

    // ============================================
    // 📞 CALL SIGNALING EVENTS
    // ============================================

    socket!.on('call_made', (data) async {
      debugPrint("📞 INCOMING CALL RECEIVED! Payload: $data");
      
      final appState = WidgetsBinding.instance.lifecycleState;
      
      // ✅ CRITICAL FIX: Only attempt native CallKit UI if NOT on Web AND App is in background
      if (!kIsWeb && (appState == AppLifecycleState.paused || appState == AppLifecycleState.detached || appState == AppLifecycleState.inactive)) {
         
         CallKitParams params = CallKitParams(
            id: data['callLogId'],
            nameCaller: data['callerName'] ?? 'Unknown',
            appName: 'ASCON Connect',
            avatar: data['callerPic'],
            handle: data['callerId'],
            type: 0, // Audio
            duration: 30000,
            textAccept: 'Answer',
            textDecline: 'Decline',
            extra: data, 
            android: const AndroidParams(
              isCustomNotification: true,
              isShowLogo: false,
              backgroundColor: '#0F3621',
              ringtonePath: 'system_ringtone_default',
              actionColor: '#4CAF50',
              incomingCallNotificationChannelName: "Incoming Call",
            ),
            ios: const IOSParams(
              iconName: 'CallKitIcon',
              handleType: 'generic',
              supportsVideo: false,
              maximumCallGroups: 1,
              maximumCallsPerCallGroup: 1,
            ),
         );
         await FlutterCallkitIncoming.showCallkitIncoming(params);
      } else {
        // App is Foreground (or Web): Show In-App UI
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
              debugPrint("❌ Navigation Failed: $e");
            }
          }
        });
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