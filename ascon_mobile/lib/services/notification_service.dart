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
import '../config.dart';
import '../main.dart'; 

import '../screens/event_detail_screen.dart';
import '../screens/programme_detail_screen.dart';
import '../screens/facility_detail_screen.dart'; 
import '../screens/mentorship_dashboard_screen.dart'; 
import '../screens/chat_screen.dart'; 
import '../screens/login_screen.dart'; 
import '../services/socket_service.dart';

// Background handler must be a top-level function
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
  
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return; 
    _isInitialized = true;

    // 1. Setup Local Notifications (Android/iOS)
    if (!kIsWeb) {
      await _firebaseMessaging.setForegroundNotificationPresentationOptions(
        alert: false, // We manually show local notifications for better control
        badge: true,
        sound: true,
      );

      const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('ic_notification');
      const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
      const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          if (response.payload != null) {
            handleNavigation(jsonDecode(response.payload!));
          }
        },
      );

      // Create Android Channel
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        AppConfig.notificationChannelId, 
        AppConfig.notificationChannelName,
        description: AppConfig.notificationChannelDesc,
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // 2. Setup Listeners
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    }

    // Foreground Message Listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("🔔 Foreground Message: ${message.notification?.title}");
      if (message.notification != null) {
        if (!kIsWeb) {
          _showLocalNotification(message);
        }
      }
    });

    // App Opened from Background Listener
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("🚀 App Opened from Notification: ${message.data}");
      handleNavigation(message.data);
    });

    // App Opened from Terminated State Listener
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleNavigation(initialMessage.data);
      });
    }

    // Token Rotation Listener
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      debugPrint("🔄 Token Rotated: $newToken");
      syncToken(tokenOverride: newToken, retry: true); 
    });

    // Initial Token Sync: We retry here assuming this might be a fresh app launch with a session
    await syncToken(retry: true);
  }

  // ✅ NEW: Helper to check current permission status without prompting
  Future<AuthorizationStatus> getAuthorizationStatus() async {
    final settings = await _firebaseMessaging.getNotificationSettings();
    return settings.authorizationStatus;
  }

  // Request Permission (Standard Dialog)
  Future<void> requestPermission() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ User granted notifications');
      // ✅ FIX: Don't retry/wait here. We are likely on the Permission Screen (No Session yet).
      await syncToken(retry: false); 
    } else {
      debugPrint('❌ User declined notifications');
    }
  }

  // Global Navigation Handler
  Future<void> handleNavigation(Map<String, dynamic> data) async {
    final route = data['route'];
    final type = data['type']; 
    final id = data['id'] ?? data['eventId']; 

    if (route == null && type != 'chat_message') return; 

    String? token = await _storage.read(key: 'auth_token');
    if (token == null) {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('auth_token');
    }

    // If not logged in, redirect to login
    if (token == null) {
      debugPrint("🔒 User logged out. Redirecting to Login with pending navigation.");
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => LoginScreen(pendingNavigation: data), 
        ),
        (route) => false,
      );
      return;
    }

    debugPrint("🔔 Navigating to Route: $route, Type: $type, ID: $id");

    // Slight delay to ensure context is ready if app just woke up
    Future.delayed(const Duration(milliseconds: 500), () {
      if (navigatorKey.currentState == null) return;

      // Handle Chat Messages
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

      // Handle Mentorship
      if (route == 'mentorship_requests') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const MentorshipDashboardScreen()),
        );
        return;
      }

      // Handle Content Details
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

  // Display Local Notification
  Future<void> _showLocalNotification(RemoteMessage message) async {
    String originalTitle = message.notification?.title ?? 'New Message';
    String body = message.notification?.body ?? '';
    
    String formattedTitle = originalTitle;

    final Int64List vibrationPattern = Int64List.fromList([0, 500, 200, 500]);

    final BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: formattedTitle,
      htmlFormatContentTitle: true,
    );

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      AppConfig.notificationChannelId, 
      AppConfig.notificationChannelName, 
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
    );

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      formattedTitle,
      body,
      platformDetails,
      payload: jsonEncode(message.data), 
    );
  }

  // ✅ UPDATED: Added [retry] parameter to control the 1.5s wait
  Future<void> syncToken({String? tokenOverride, bool retry = false}) async {
    try {
      debugPrint("🔄 NotificationService: Starting Token Sync...");

      String? fcmToken;
      
      // 1. Use Override if provided (Rotation)
      if (tokenOverride != null) {
        fcmToken = tokenOverride;
      } 
      // 2. Fetch for Web
      else if (kIsWeb) {
        String? vapidKey = dotenv.env['FIREBASE_VAPID_KEY'];
        if (vapidKey != null && vapidKey.isNotEmpty) {
          fcmToken = await _firebaseMessaging.getToken(vapidKey: vapidKey);
        } else {
          return;
        }
      } 
      // 3. Fetch for Mobile
      else {
        fcmToken = await _firebaseMessaging.getToken();
      }

      if (fcmToken == null) return;

      String? authToken = await _storage.read(key: 'auth_token');

      // Fallback to SharedPreferences if secure storage is empty
      if (authToken == null) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString('auth_token');
      }

      // ✅ FIX: Only wait if retry is TRUE (Login Flow). 
      // If retry is FALSE (Permission Flow), return immediately to avoid UI delay.
      if (authToken == null && retry) {
        debugPrint("⏳ Auth Token not found yet. Retrying in 1.5s...");
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
        } else {
           debugPrint("⚠️ Backend rejected token: ${response.statusCode} - ${response.body}");
        }
      } else {
        debugPrint("ℹ️ Skipped Token Sync (No Session).");
      }
    } catch (e) {
      debugPrint("❌ Error syncing token: $e");
    }
  }
}