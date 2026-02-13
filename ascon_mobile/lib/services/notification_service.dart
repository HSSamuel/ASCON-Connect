import 'dart:convert'; 
import 'dart:io';
import 'dart:typed_data'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart'; 
import 'package:audioplayers/audioplayers.dart'; // ✅ Added for foreground ringing
import '../config.dart';
import '../main.dart'; 

import '../screens/event_detail_screen.dart';
import '../screens/programme_detail_screen.dart';
import '../screens/facility_detail_screen.dart'; 
import '../screens/mentorship_dashboard_screen.dart'; 
import '../screens/chat_screen.dart'; 
import '../screens/login_screen.dart'; 
import '../screens/call_screen.dart'; // ✅ Added for call navigation
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
  final AudioPlayer _foregroundRingPlayer = AudioPlayer(); // ✅ Player for foreground calls
  
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return; 
    _isInitialized = true;

    if (!kIsWeb) {
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: true, // ✅ Changed to true so heads-up displays show
        badge: true,
        sound: true,
      );

      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_notification');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
      const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _stopRingtone(); // ✅ Stop ringing if user taps notification
          if (response.payload != null) {
            handleNavigation(jsonDecode(response.payload!));
          }
        },
      );

      // 1. Standard Channel (Beep)
      const AndroidNotificationChannel standardChannel = AndroidNotificationChannel(
        AppConfig.notificationChannelId, 
        AppConfig.notificationChannelName,
        description: AppConfig.notificationChannelDesc,
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );

      // 2. ✅ Call Channel (Ringtone)
      // NOTE: 'ringtone' must exist in android/app/src/main/res/raw/ringtone.mp3
      const AndroidNotificationChannel callChannel = AndroidNotificationChannel(
        'ascon_call_channel', 
        'Incoming Calls',
        description: 'Ringtone for incoming calls',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('ringtone'), // ✅ Uses custom sound
        showBadge: true,
      );

      final plugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (plugin != null) {
        await plugin.createNotificationChannel(standardChannel);
        await plugin.createNotificationChannel(callChannel); // ✅ Register call channel
      }
    }

    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("🔔 Foreground Message: ${message.notification?.title}");
      if (message.notification != null || message.data.isNotEmpty) {
        if (!kIsWeb) {
          _showLocalNotification(message);
        }
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _stopRingtone(); // ✅ Stop ringing
      debugPrint("🚀 App Opened from Notification: ${message.data}");
      handleNavigation(message.data);
    });

    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _stopRingtone(); // ✅ Stop ringing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleNavigation(initialMessage.data);
      });
    }

    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      debugPrint("🔄 Token Rotated: $newToken");
      syncToken(tokenOverride: newToken, retry: true); 
    });

    await syncToken(retry: true);
  }

  // ✅ Helper to stop ringing (called on tap or answer)
  void _stopRingtone() {
    _foregroundRingPlayer.stop();
  }

  Future<void> handleNavigation(Map<String, dynamic> data) async {
    final route = data['route'];
    final type = data['type']; 
    final id = data['id'] ?? data['eventId']; 

    _stopRingtone(); // Ensure sound stops on navigation

    if (route == null && type != 'chat_message' && type != 'call_offer') return; 

    String? token = await _storage.read(key: 'auth_token');
    if (token == null) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token');
    }

    if (token == null) {
      debugPrint("🔒 User logged out. Redirecting to Login.");
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginScreen(pendingNavigation: data), 
        ),
        (route) => false,
      );
      return;
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (navigatorKey.currentState == null) return;

      // ✅ Handle Incoming Call Navigation
      if (type == 'call_offer' || type == 'video_call') {
        // Here we assume the socket will handle the actual connection, 
        // but we navigate to CallScreen or show incoming call dialog
        // For simplicity, we just bring the app to foreground. 
        // Real connection is handled by CallService & SocketService.
        return;
      }

      if (type == 'chat_message') {
        final conversationId = data['conversationId'];
        final senderId = data['senderId']; 
        
        final isGroup = data['isGroup'].toString().toLowerCase() == 'true';
        final groupId = data['groupId']; 
        
        String displayName;
        if (isGroup) {
          displayName = data['groupName'] ?? "Group Chat";
        } else {
          displayName = data['senderName'] ?? "Alumni Member";
        }
        
        final senderProfilePic = data['senderProfilePic'];

        if (conversationId != null && senderId != null) {
          SocketService().initSocket(); 

          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                conversationId: conversationId,
                receiverId: senderId, 
                receiverName: displayName, 
                receiverProfilePic: senderProfilePic,
                isOnline: false, 
                isGroup: isGroup, 
                groupId: groupId, 
              ),
            ),
          );
        }
        return;
      }

      if (route == 'mentorship_requests') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const MentorshipDashboardScreen()),
        );
        return;
      }

      if (id != null) {
        if (route == 'event_detail') {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => EventDetailScreen(
                eventData: {'_id': id.toString(), 'title': 'Loading details...'}, 
              ),
            ),
          );
        } else if (route == 'programme_detail') {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => ProgrammeDetailScreen(
                programme: {'_id': id.toString(), 'title': 'Loading details...'},
              ),
            ),
          );
        } else if (route == 'facility_detail') {
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) => FacilityDetailScreen(
                facility: {'_id': id.toString(), 'title': 'Loading details...'},
              ),
            ),
          );
        }
      }
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    String originalTitle = message.notification?.title ?? 'New Message';
    String body = message.notification?.body ?? '';
    
    // ✅ Check if this is a Call
    final type = message.data['type'];
    final isCall = type == 'call_offer' || type == 'video_call' || (type?.toString().contains('call') ?? false);

    // ✅ Select Channel based on type
    final channelId = isCall ? 'ascon_call_channel' : AppConfig.notificationChannelId;
    final channelName = isCall ? 'Incoming Calls' : AppConfig.notificationChannelName;
    final sound = isCall 
        ? const RawResourceAndroidNotificationSound('ringtone') 
        : null; // Null means default

    // ✅ Foreground Ringing Logic
    // If the app is open, system notifications often just "peek" without long sound.
    // We force loop the ringtone here for calls.
    if (isCall) {
      try {
        await _foregroundRingPlayer.setSource(AssetSource('sounds/ringtone.mp3'));
        await _foregroundRingPlayer.setReleaseMode(ReleaseMode.loop); // Loop it
        await _foregroundRingPlayer.resume();
        
        // Auto-stop after 30 seconds if not answered
        Future.delayed(const Duration(seconds: 30), () {
          _stopRingtone();
        });
      } catch (e) {
        debugPrint("Error playing foreground ringtone: $e");
      }
    }

    final Int64List vibrationPattern = Int64List.fromList([0, 500, 200, 500, 200, 500]); // Aggressive vibration for calls

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
      enableLights: true,
      ledColor: const Color(0xFF1B5E3A),
      ledOnMs: 1000,
      ledOffMs: 500,
      styleInformation: bigTextStyleInformation,
      sound: sound, // ✅ Use custom sound
      fullScreenIntent: isCall, // ✅ Try to wake screen for calls
      category: isCall ? AndroidNotificationCategory.call : AndroidNotificationCategory.message,
    );

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode, 
      originalTitle,   
      body,             
      platformDetails,  
      payload: jsonEncode(message.data), 
    );
  }

  // ... (Permission & Token Sync code remains unchanged)
  Future<AuthorizationStatus> getAuthorizationStatus() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  Future<void> requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ User granted notifications');
      await syncToken(retry: false); 
    } else {
      debugPrint('❌ User declined notifications');
    }
  }

  Future<void> syncToken({String? tokenOverride, bool retry = false}) async {
    try {
      debugPrint("🔄 NotificationService: Starting Token Sync...");

      String? fcmToken;
      
      if (tokenOverride != null) {
        fcmToken = tokenOverride;
      } else if (kIsWeb) {
        String? vapidKey = dotenv.env['FIREBASE_VAPID_KEY'];
        if (vapidKey != null && vapidKey.isNotEmpty) {
          fcmToken = await _firebaseMessaging.getToken(vapidKey: vapidKey);
        } else {
          return;
        }
      } else {
        fcmToken = await _firebaseMessaging.getToken();
      }

      if (fcmToken == null) return;

      String? authToken = await _storage.read(key: 'auth_token');

      if (authToken == null) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString('auth_token');
      }

      if (authToken == null && retry) {
        await Future.delayed(const Duration(milliseconds: 1500));
        authToken = await _storage.read(key: 'auth_token');
        
        if (authToken == null) {
           final prefs = await SharedPreferences.getInstance();
           authToken = prefs.getString('auth_token');
        }
      }

      if (authToken != null) {
        final url = Uri.parse('${AppConfig.baseUrl}/api/notifications/save-token');
        
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json', 'auth-token': authToken},
          body: jsonEncode({"fcmToken": fcmToken}),
        );

        if (response.statusCode == 200) {
           debugPrint("✅ Token synced successfully to Backend!");
        }
      }
    } catch (e) {
      debugPrint("❌ Error syncing token: $e");
    }
  }
}