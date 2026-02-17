import 'dart:convert';
import 'dart:typed_data';
import 'dart:math'; // Added for random ID generation fallback
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart'; 
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart'; // ✅ ADDED
import 'package:flutter_callkit_incoming/entities/entities.dart'; // ✅ ADDED

import '../config.dart';
import '../router.dart'; 

import '../screens/event_detail_screen.dart';
import '../screens/programme_detail_screen.dart';
import '../screens/facility_detail_screen.dart';
import '../screens/mentorship_dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../services/socket_service.dart';

// ✅ GLOBAL BACKGROUND HANDLER
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🌙 Background Message: ${message.messageId}");
  
  // ✅ FIX: Handle Call Events in Background
  if (message.data['type'] == 'call_offer') {
    await NotificationService.showIncomingCall(message.data);
  } 
  else if (message.data['type'] == 'end_call') {
    await FlutterCallkitIncoming.endAllCalls();
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  // ❌ REMOVED: AudioPlayer _foregroundRingPlayer (CallKit handles ringing now)

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (!kIsWeb) {
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_notification');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
      const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          if (response.payload != null) {
            try {
              final data = jsonDecode(response.payload!);
              handleNavigation(data);
            } catch (e) {
              debugPrint("Error parsing payload: $e");
            }
          }
        },
      );

      // 1. Standard Channel
      const AndroidNotificationChannel standardChannel = AndroidNotificationChannel(
        AppConfig.notificationChannelId,
        AppConfig.notificationChannelName,
        description: AppConfig.notificationChannelDesc,
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );

      // 2. Call Channel (Backup for missed calls beep)
      const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
        AppConfig.callChannelId,
        AppConfig.callChannelName,
        description: AppConfig.callChannelDesc,
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        // ✅ FIX: Use default notification sound for missed calls (Beep), not ringtone loop
        sound: null, 
        showBadge: true,
      );

      final plugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (plugin != null) {
        await plugin.createNotificationChannel(standardChannel);
        await plugin.createNotificationChannel(callChannel);
      }
    }

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint("🔔 Foreground Message: ${message.data}");

      // ✅ FIX: Intercept Call Events
      if (message.data['type'] == 'call_offer') {
        await showIncomingCall(message.data);
        return; 
      }
      
      if (message.data['type'] == 'end_call') {
        await FlutterCallkitIncoming.endAllCalls();
        return;
      }

      if (message.notification != null || message.data.isNotEmpty) {
        if (!kIsWeb) {
          _showLocalNotification(message);
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleNavigation(message.data);
    });

    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 800), () {
        handleNavigation(initialMessage.data);
      });
    }

    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      syncToken(tokenOverride: newToken, retry: true);
    });

    syncToken(retry: true);
  }

  // ==========================================
  // 📞 CALL HANDLING (Native CallKit)
  // ==========================================
  static Future<void> showIncomingCall(Map<String, dynamic> data) async {
    final uuid = data['uuid'] ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    final params = CallKitParams(
      id: uuid,
      nameCaller: data['callerName'] ?? 'Unknown Alumni',
      appName: 'ASCON Connect',
      avatar: data['callerPic'],
      handle: data['callerId'] ?? '000000',
      type: 0, 
      duration: 30000, 
      textAccept: 'Answer',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: false, 
        isShowCallback: false,
      ),
      extra: data,
      headers: {'apiKey': 'Abc@123!', 'platform': 'flutter'},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'system_ringtone_default', // Uses default phone ringtone
        backgroundColor: '#0F3621',
        actionColor: '#4CAF50',
        incomingCallNotificationChannelName: "Incoming Call",
      ),
      ios: const IOSParams(
        iconName: 'CallKitIcon',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 1,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  /// 🚀 **Improved Navigation Handler**
  Future<void> handleNavigation(Map<String, dynamic> data) async {
    final String? route = data['route'];
    final String? type = data['type'];
    final String? id = data['id'] ?? data['eventId'] ?? data['_id'];

    // 1. Verify Authentication
    String? token = await _storage.read(key: 'auth_token');
    if (token == null) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token');
    }

    // Get reliable context
    final BuildContext? context = rootNavigatorKey.currentContext;

    if (token == null) {
      if (context != null) {
        GoRouter.of(context).go('/login', extra: data); 
      }
      return;
    }

    if (context == null) {
      debugPrint("❌ Navigation Context is null. Cannot navigate.");
      return;
    }

    // ======================================================
    // 📞 CASE 1: INCOMING CALL
    // ======================================================
    if (type == 'call_offer' || type == 'video_call') {
      SocketService().initSocket(); 

      context.push('/call', extra: {
        'remoteName': data['callerName'] ?? "Unknown Caller",
        'remoteId': data['callerId'],
        'remoteAvatar': data['callerPic'], // Changed from callerAvatar to match backend
        'isCaller': false, 
        'offer': data['offer'] is String ? jsonDecode(data['offer']) : data['offer'],
        'callLogId': data['callLogId'],
      });
      return;
    }

    // ======================================================
    // 💬 CASE 2: CHAT MESSAGE
    // ======================================================
    if (type == 'chat_message') {
      final conversationId = data['conversationId'];
      final senderId = data['senderId'];
      final isGroup = data['isGroup'].toString().toLowerCase() == 'true';
      final groupId = data['groupId'];
      
      String displayName = isGroup 
          ? (data['groupName'] ?? "Group Chat") 
          : (data['senderName'] ?? "Alumni Member");
          
      final senderProfilePic = data['senderProfilePic'];

      if (conversationId != null) {
        SocketService().initSocket();
        
        context.push('/chat_detail', extra: {
          'conversationId': conversationId,
          'receiverId': senderId,
          'receiverName': displayName,
          'receiverProfilePic': senderProfilePic,
          'isGroup': isGroup,
          'groupId': groupId,
          'isOnline': false, 
        });
      }
      return;
    }

    // ======================================================
    // 📢 CASE 3: POSTS / UPDATES
    // ======================================================
    if (type == 'new_update' || route == 'updates') {
      context.go('/updates'); 
      return;
    }

    // ======================================================
    // 🚀 CASE 4: WELCOME / PROFILE
    // ======================================================
    if (type == 'welcome' || route == 'profile') {
      context.go('/profile'); 
      return;
    }

    // ======================================================
    // 🎓 CASE 5: DETAILS
    // ======================================================
    if (route == 'mentorship_requests') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MentorshipDashboardScreen()),
      );
      return;
    }

    if (id != null) {
      if (route == 'event_detail') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(
              eventData: {'_id': id.toString(), 'title': 'Loading...'},
            ),
          ),
        );
      } else if (route == 'programme_detail') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProgrammeDetailScreen(
              programme: {'_id': id.toString(), 'title': 'Loading...'},
            ),
          ),
        );
      } else if (route == 'facility_detail') {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FacilityDetailScreen(
              facility: {'_id': id.toString(), 'title': 'Loading...'},
            ),
          ),
        );
      }
    }
  }

  // ==========================================
  // 🔔 STANDARD NOTIFICATIONS (Chat, Missed Call Beep)
  // ==========================================
  Future<void> _showLocalNotification(RemoteMessage message) async {
    String originalTitle = message.notification?.title ?? 'New Message';
    String body = message.notification?.body ?? '';
    
    // ✅ FIX: Standard channel for everything non-call related
    const channelId = AppConfig.notificationChannelId;
    const channelName = AppConfig.notificationChannelName;

    final Int64List vibrationPattern = Int64List.fromList([0, 500]);

    final BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: originalTitle,
      htmlFormatContentTitle: true,
    );

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFF1B5E3A),
      icon: 'ic_notification',
      enableVibration: true,
      vibrationPattern: vibrationPattern,
      styleInformation: bigTextStyleInformation,
      playSound: true, // ✅ This ensures the standard "Beep" for missed calls/chats
    );

    await _localNotifications.show(
      message.hashCode,
      originalTitle,
      body,
      NotificationDetails(android: androidDetails),
      payload: jsonEncode(message.data),
    );
  }

  Future<AuthorizationStatus> getAuthorizationStatus() async {
    return (await _firebaseMessaging.getNotificationSettings()).authorizationStatus;
  }

  Future<void> requestPermission() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      syncToken(retry: false);
    }
  }

  Future<void> syncToken({String? tokenOverride, bool retry = false}) async {
    try {
      String? fcmToken = tokenOverride ?? (kIsWeb 
          ? await _firebaseMessaging.getToken(vapidKey: dotenv.env['FIREBASE_VAPID_KEY']) 
          : await _firebaseMessaging.getToken());

      if (fcmToken == null) return;

      String? authToken = await _storage.read(key: 'auth_token');
      if (authToken == null) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString('auth_token');
      }

      if (authToken != null) {
        await http.post(
          Uri.parse('${AppConfig.baseUrl}/api/notifications/save-token'),
          headers: {'Content-Type': 'application/json', 'auth-token': authToken},
          body: jsonEncode({"fcmToken": fcmToken}),
        ).timeout(const Duration(seconds: 10));
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }
}