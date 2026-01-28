import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class AppConfig {
  // =========================================================
  // 🌍 BASE URL (Dynamic)
  // =========================================================
  static String get baseUrl {
    final String? url = dotenv.env['API_URL'];

    if (url == null || url.isEmpty) {
      // ⛔ FATAL ERROR: Fail loudly if env is missing.
      // This prevents the app from silently connecting to production
      // when you intend to be on localhost.
      throw Exception("⛔ FATAL ERROR: API_URL not found in .env file.");
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