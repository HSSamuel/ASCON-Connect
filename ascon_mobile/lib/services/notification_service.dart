import 'dart:convert'; 
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ Required for kIsWeb check
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../config.dart'; 

// ✅ BACKGROUND HANDLER
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

  // ✅ INITIALIZE SERVICE
  Future<void> init() async {
    // 1. Request Permission
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('❌ User declined notifications');
      return;
    }

    // 2. Setup Local Notifications
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@drawable/ic_notification');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint("🔔 Foreground Notification Tapped: ${response.payload}");
      },
    );

    // 3. Setup Firebase Listeners
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("☀️ Foreground Message: ${message.notification?.title}");
      if (message.notification != null) {
        _showLocalNotification(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("🚀 App Opened from Notification: ${message.data}");
    });

    // 4. Get & Save Token
    await _syncToken();
  }

  // ✅ SHOW LOCAL NOTIFICATION
  Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF1B5E3A),
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

  // ✅ SYNC TOKEN WITH BACKEND (Now supports Web & Mobile)
  Future<void> _syncToken() async {
    try {
      String? fcmToken;

      // 🔹 WEB SUPPORT: Use VAPID Key
      if (kIsWeb) {
        // ⚠️ REPLACE THIS STRING with your real Key from Firebase Console
        fcmToken = await _firebaseMessaging.getToken(
          vapidKey: "BG-mAsjcWNqfS9Brgh0alj3Cf7Q7FFgkl8kvu5zktPvt4Dt-Yu138tPE_z-INAganzw6BVb6Vjc9Nf37KzN0Rm8" 
        );
      } else {
        // 🔹 MOBILE: Standard Token Request
        fcmToken = await _firebaseMessaging.getToken();
      }

      if (fcmToken == null) {
        debugPrint("⚠️ FCM Token is null");
        return;
      }

      debugPrint("🔥 FCM Token found: $fcmToken");

      final prefs = await SharedPreferences.getInstance();
      String? authToken = prefs.getString('auth_token');

      // 🔄 RETRY LOGIC: If called too fast after login, wait 500ms and try once more
      if (authToken == null) {
        debugPrint("⏳ Auth Token not found yet... Retrying in 500ms");
        await Future.delayed(const Duration(milliseconds: 500));
        authToken = prefs.getString('auth_token');
      }

      if (authToken != null) {
        debugPrint("🚀 Sending token to server...");
        
        final url = Uri.parse('${AppConfig.baseUrl}/api/notifications/save-token');
        
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'auth-token': authToken,
          },
          // ✅ FIX: Send BOTH keys to cover backend mismatch
          body: jsonEncode({
            "token": fcmToken,     // Backend expectation A
            "fcmToken": fcmToken   // Backend expectation B
          }),
        );

        if (response.statusCode == 200) {
          debugPrint("✅ Token synced successfully!");
        } else {
          debugPrint("❌ Server rejected token: ${response.statusCode} - ${response.body}");
        }
      } else {
        debugPrint("⚠️ Cannot sync token: User not logged in (Auth Token missing).");
      }
    } catch (e) {
      debugPrint("❌ CRITICAL ERROR syncing token: $e");
    }
  }
}