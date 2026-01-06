import 'package:flutter_dotenv/flutter_dotenv.dart'; // ✅ Import dotenv
import 'package:flutter/foundation.dart';

class AppConfig {
  // =========================================================
  // 🌍 BASE URL (Dynamic)
  // =========================================================
  // This now pulls directly from your .env file.
  // To switch between Local and Online, just edit the .env file!
  static String get baseUrl {
    final String? url = dotenv.env['API_URL'];

    if (url == null || url.isEmpty) {
      // ⚠️ Safety Fallback if .env fails to load
      // You can keep this as your production URL just in case
      return 'https://ascon.onrender.com';
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
}