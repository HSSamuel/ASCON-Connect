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
import '../config.dart';
import '../main.dart'; 

import '../screens/event_detail_screen.dart';
import '../screens/programme_detail_screen.dart';
import '../screens/facility_detail_screen.dart'; // ✅ ADDED THIS IMPORT

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
  
  // Secure Storage
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return; 
    _isInitialized = true;

    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ User declined notifications');
      return;
    }

    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: false, 
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
          _handleNavigation(jsonDecode(response.payload!));
        }
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'ascon_high_importance', 
      'ASCON Notifications',
      description: 'This channel is used for important ASCON updates.',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null || message.data.isNotEmpty) {
        _showLocalNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("🚀 App Opened from Notification: ${message.data}");
      _handleNavigation(message.data);
    });

    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleNavigation(initialMessage.data);
      });
    }

    // Token Rotation Listener
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      debugPrint("🔄 Token Rotated: $newToken");
      syncToken(); 
    });

    await syncToken();
  }

  void _handleNavigation(Map<String, dynamic> data) {
    final route = data['route'];
    final id = data['id'] ?? data['eventId']; 

    if (route == null || id == null) return;

    debugPrint("🔔 Navigating to $route with ID: $id");

    Future.delayed(const Duration(milliseconds: 500), () {
      if (navigatorKey.currentState == null) return;

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
      } 
      // ✅ ADDED FACILITY NAVIGATION
      else if (route == 'facility_detail') {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => FacilityDetailScreen(
              facility: {'_id': id.toString(), 'title': 'Loading details...'},
            ),
          ),
        );
      }
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    String type = message.data['type'] ?? 'Update';
    String originalTitle = message.notification?.title ?? 'New Message';
    String body = message.notification?.body ?? '';
    String formattedTitle = '<b>New $type:</b> $originalTitle';

    final Int64List vibrationPattern = Int64List.fromList([0, 500, 200, 500]);

    final BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: formattedTitle,
      htmlFormatContentTitle: true,
    );

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'ascon_high_importance',
      'ASCON Notifications',
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

  Future<void> syncToken() async {
    try {
      String? fcmToken;
      if (kIsWeb) {
        fcmToken = await _firebaseMessaging.getToken(
          vapidKey: "BG-mAsjcWNqfS9Brgh0alj3Cf7Q7FFgkl8kvu5zktPvt4Dt-Yu138tPE_z-INAganzw6BVb6Vjc9Nf37KzN0Rm8" 
        );
      } else {
        fcmToken = await _firebaseMessaging.getToken();
      }

      if (fcmToken == null) return;

      // ✅ FIX: "Two-Box" Strategy
      String? authToken = await _storage.read(key: 'auth_token');

      if (authToken == null) {
        final prefs = await SharedPreferences.getInstance();
        authToken = prefs.getString('auth_token');
      }

      // Retry logic
      if (authToken == null) {
        await Future.delayed(const Duration(milliseconds: 1500));
        authToken = await _storage.read(key: 'auth_token');
        if (authToken == null) {
           final prefs = await SharedPreferences.getInstance();
           authToken = prefs.getString('auth_token');
        }
      }

      if (authToken != null) {
        final url = Uri.parse('${AppConfig.baseUrl}/api/notifications/save-token');
        await http.post(
          url,
          headers: {'Content-Type': 'application/json', 'auth-token': authToken},
          body: jsonEncode({"fcmToken": fcmToken}),
        );
        debugPrint("✅ Token synced successfully");
      } else {
        debugPrint("⚠️ Token sync skipped: No Auth Token found.");
      }
    } catch (e) {
      debugPrint("❌ Error syncing token: $e");
    }
  }
}