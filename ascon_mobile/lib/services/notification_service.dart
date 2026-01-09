import 'dart:convert'; 
import 'dart:io';
import 'dart:typed_data'; // ✅ Required for vibration patterns
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../main.dart'; 

import '../screens/event_detail_screen.dart';
import '../screens/programme_detail_screen.dart';

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

  Future<void> init() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ User declined notifications');
      return;
    }

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

    // ✅ Create the High Importance Channel with Vibration enabled
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

    // ✅ FOREGROUND HANDLER: This is where we format the UI
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // We only show local notification if data is present or notification block exists
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

    await _syncToken();
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
    });
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    // 1. EXTRACT & FORMAT DATA
    // We look for 'type' in data payload, default to 'Update' if missing
    String type = message.data['type'] ?? 'Update';
    String originalTitle = message.notification?.title ?? 'New Message';
    String body = message.notification?.body ?? '';

    // 2. CONSTRUCT BOLD HEADER: "<b>New Type:</b> Title"
    // Note: Android supports simple HTML tags in BigTextStyle
    String formattedTitle = '<b>New $type:</b> $originalTitle';

    // 3. VIBRATION PATTERN
    final Int64List vibrationPattern = Int64List.fromList([0, 500, 200, 500]);

    // 4. STYLE CONFIGURATION
    final BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: formattedTitle,
      htmlFormatContentTitle: true, // ✅ Enables HTML (Bold) in Title
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
      styleInformation: bigTextStyleInformation, // ✅ Apply the Bold Style
    );

    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      formattedTitle, // Fallback title
      body,
      platformDetails,
      payload: jsonEncode(message.data), 
    );
  }

  Future<void> _syncToken() async {
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

      final prefs = await SharedPreferences.getInstance();
      String? authToken = prefs.getString('auth_token');

      if (authToken == null) {
        await Future.delayed(const Duration(milliseconds: 1000));
        authToken = prefs.getString('auth_token');
      }

      if (authToken != null) {
        final url = Uri.parse('${AppConfig.baseUrl}/api/notifications/save-token');
        await http.post(
          url,
          headers: {'Content-Type': 'application/json', 'auth-token': authToken},
          body: jsonEncode({"fcmToken": fcmToken}),
        );
        debugPrint("✅ Token synced");
      }
    } catch (e) {
      debugPrint("❌ Error syncing token: $e");
    }
  }
}