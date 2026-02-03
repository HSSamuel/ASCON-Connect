import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class AppConfig {
  // =========================================================
  // 🌍 BASE URL (Dynamic)
  // =========================================================
  static String get baseUrl {
    String? url = dotenv.env['API_URL'];

    if (url == null || url.isEmpty) {
      throw Exception("⛔ FATAL ERROR: API_URL not found in .env file.");
    }

    // ✅ FIX: Automatically swap 'localhost' for '10.0.2.2' on Android Emulator
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.android) {
      if (url.contains('localhost')) {
        url = url.replaceAll('localhost', '10.0.2.2');
        debugPrint("🤖 Android Emulator Detected: Switched API URL to $url");
      }
    }

    return url;
  }

  // =========================================================
  // 🔑 SECRETS
  // =========================================================
  static String get googleWebClientId {
    return dotenv.env['GOOGLE_WEB_CLIENT_ID'] ?? '';
  }
  
  static String? get googleClientId {
    return kIsWeb ? googleWebClientId : null; 
  }

  // =========================================================
  // 🛡️ NOTIFICATION & NETWORK SETTINGS
  // =========================================================
  
  static const Duration connectionTimeout = Duration(seconds: 15);
  static String get unreadCountEndpoint => '$baseUrl/api/notifications/unread-count';

  // ✅ IMPROVEMENT: Centralized Notification Config
  static const String notificationChannelId = 'ascon_high_importance'; 
  static const String notificationChannelName = 'ASCON Notifications';
  static const String notificationChannelDesc = 'This channel is used for important ASCON updates.';
}