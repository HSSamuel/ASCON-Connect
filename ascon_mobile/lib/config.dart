import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class AppConfig {
  // =========================================================
  // 🌍 BASE URL (Dynamic)
  // =========================================================
  static String get baseUrl {
    String? url = dotenv.env['API_URL'];

    if (url == null || url.isEmpty) {
      // ⛔ FATAL ERROR: Fail loudly if env is missing.
      throw Exception("⛔ FATAL ERROR: API_URL not found in .env file.");
    }

    // ✅ FIX: Automatically swap 'localhost' for '10.0.2.2' on Android Emulator
    // This allows you to use one .env file for both Web and Android.
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
  
  // ✅ ADDED: Specific timeout for the notification heartbeat
  static const Duration connectionTimeout = Duration(seconds: 15);

  // ✅ ADDED: Endpoint Helper for Notification Polling
  static String get unreadCountEndpoint => '$baseUrl/api/notifications/unread-count';
}