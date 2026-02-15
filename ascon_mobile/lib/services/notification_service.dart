import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:go_router/go_router.dart'; 

import '../config.dart';
import '../router.dart'; 

import '../screens/event_detail_screen.dart';
import '../screens/programme_detail_screen.dart';
import '../screens/facility_detail_screen.dart';
import '../screens/mentorship_dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../services/socket_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🌙 Background Message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  final AudioPlayer _foregroundRingPlayer = AudioPlayer();

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
          _stopRingtone();
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

      // 2. Call Channel (High Priority & Sound)
      const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
        'ascon_call_channel',
        'Incoming Calls',
        description: 'Ringtone for incoming calls',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('ringtone'),
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

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null || message.data.isNotEmpty) {
        if (!kIsWeb) {
          _showLocalNotification(message);
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _stopRingtone();
      handleNavigation(message.data);
    });

    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _stopRingtone();
      // Allow router to mount before navigating
      Future.delayed(const Duration(milliseconds: 800), () {
        handleNavigation(initialMessage.data);
      });
    }

    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      syncToken(tokenOverride: newToken, retry: true);
    });

    // Fire and forget sync to prevent UI blocking
    syncToken(retry: true);
  }

  void _stopRingtone() {
    try {
      _foregroundRingPlayer.stop();
    } catch (_) {}
  }

  /// 🚀 **Improved Navigation Handler**
  Future<void> handleNavigation(Map<String, dynamic> data) async {
    _stopRingtone();

    final String? route = data['route'];
    final String? type = data['type'];
    final String? id = data['id'] ?? data['eventId'] ?? data['_id'];

    // 1. Verify Authentication
    String? token = await _storage.read(key: 'auth_token');
    if (token == null) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token');
    }

    // Get reliable context from Root Navigator
    final BuildContext? context = rootNavigatorKey.currentContext;

    if (token == null) {
      if (context != null) {
        GoRouter.of(context).go('/login', extra: data); // Pass payload to handle after login
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
      debugPrint("📞 Navigating to Answer Call Screen...");
      
      SocketService().initSocket(); // Ensure socket is ready

      context.push('/call', extra: {
        'remoteName': data['callerName'] ?? "Unknown Caller",
        'remoteId': data['callerId'],
        'remoteAvatar': data['callerAvatar'],
        'isCaller': false, // We are answering
        'offer': data['offer'] is String ? jsonDecode(data['offer']) : data['offer'],
        'callLogId': data['callLogId'],
      });
      return;
    }

    // ======================================================
    // 💬 CASE 2: CHAT MESSAGE (Group or 1-on-1)
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
          'isOnline': false, // Assume offline until socket updates
        });
      }
      return;
    }

    // ======================================================
    // 📢 CASE 3: POSTS / UPDATES
    // ======================================================
    if (type == 'new_update' || route == 'updates') {
      // Switch to "Updates" Tab
      context.go('/updates'); 
      return;
    }

    // ======================================================
    // 🚀 CASE 4: WELCOME / PROFILE (New User)
    // ======================================================
    if (type == 'welcome' || route == 'profile') {
      // Switch to "Profile" Tab
      context.go('/profile'); 
      return;
    }

    // ======================================================
    // 🎓 CASE 5: PROGRAMME & EVENT DETAILS
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

  Future<void> _showLocalNotification(RemoteMessage message) async {
    String originalTitle = message.notification?.title ?? 'New Message';
    String body = message.notification?.body ?? '';
    
    final type = message.data['type'];
    final isCall = type == 'call_offer' || type == 'video_call';

    final channelId = isCall ? 'ascon_call_channel' : AppConfig.notificationChannelId;
    final channelName = isCall ? 'Incoming Calls' : AppConfig.notificationChannelName;
    
    // Explicitly set sound only for calls to ensure ringtone plays
    final sound = isCall ? const RawResourceAndroidNotificationSound('ringtone') : null;

    // ✅ Ring in foreground for calls
    if (isCall) {
      try {
        await _foregroundRingPlayer.setSource(AssetSource('sounds/ringtone.mp3'));
        await _foregroundRingPlayer.setReleaseMode(ReleaseMode.loop);
        await _foregroundRingPlayer.resume();
        Future.delayed(const Duration(seconds: 30), () => _stopRingtone());
      } catch (e) {
        debugPrint("Error playing ringtone: $e");
      }
    }

    final Int64List vibrationPattern = Int64List.fromList([0, 500, 200, 500, 200, 500]);

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
      sound: sound,
      fullScreenIntent: isCall, // Wakes up screen for calls
      category: isCall ? AndroidNotificationCategory.call : AndroidNotificationCategory.message,
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
      // ✅ FIX: Don't await this! Fire and forget so UI doesn't lag.
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
        // ✅ FIX: Added timeout so it doesn't hang indefinitely on bad network
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