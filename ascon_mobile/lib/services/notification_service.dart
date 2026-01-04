import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart'; // Ensure you have your API URL here

// ✅ BACKGROUND HANDLER (Must be top-level function, outside any class)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you need to access Firebase here, you must call Firebase.initializeApp()
  debugPrint("🌙 Background Message: ${message.messageId}");
}

class NotificationService {
  // Singleton Pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // ✅ INITIALIZE SERVICE
  Future<void> init() async {
    // 1. Request Permission (Critical for iOS/Android 13+)
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ User declined notifications');
      return;
    }

    // 2. Setup Local Notifications (For Foreground Alerts)
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // Handle tapping a foreground notification here
        debugPrint("🔔 Foreground Notification Tapped: ${response.payload}");
      },
    );

    // 3. Setup Firebase Listeners
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // FOREGROUND LISTENER
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("☀️ Foreground Message: ${message.notification?.title}");
      
      // Show the visual alert
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    // OPENED APP FROM BACKGROUND
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("🚀 App Opened from Notification: ${message.data}");
      // TODO: Navigate to specific screen based on message.data['route']
    });

    // 4. Get & Save Token
    await _syncToken();
  }

  // ✅ SHOW LOCAL NOTIFICATION (Heads-up)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel', // Channel ID
      'High Importance Notifications', // Channel Name
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF1B5E3A), // Your Brand Green
    );

    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platformDetails,
      payload: message.data.toString(),
    );
  }

  // ✅ SYNC TOKEN WITH BACKEND
  Future<void> _syncToken() async {
    String? token = await _firebaseMessaging.getToken();
    if (token == null) return;

    debugPrint("🔥 FCM Token: $token");

    // Check if we have a logged-in user before sending to backend
    final prefs = await SharedPreferences.getInstance();
    final String? authToken = prefs.getString('auth_token');

    if (authToken != null) {
      // Send token to your Backend
      try {
        final url = Uri.parse('${AppConfig.baseUrl}/api/notifications/save-token');
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'auth-token': authToken,
          },
          body: '{"fcmToken": "$token"}',
        );
        debugPrint("✅ FCM Token synced with server");
      } catch (e) {
        debugPrint("❌ Failed to sync FCM token: $e");
      }
    }
  }
}