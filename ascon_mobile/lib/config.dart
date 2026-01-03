import 'package:flutter/foundation.dart'; // ✅ Import this for kIsWeb

class AppConfig {
  // =========================================================
  // 🚀 PRODUCTION MODE: ON
  // =========================================================
  static const bool isProduction = true; 

  // 🌍 The Online Server
  static const String onlineUrl = 'https://ascon.onrender.com';

  // 💻 Local Backup
  static const String localUrl = 'http://10.231.185.203:5000'; 

  static String get baseUrl {
    return isProduction ? onlineUrl : localUrl;
  }

  // =========================================================
  // 🔑 SECRETS (Added for Auth)
  // =========================================================
  static const String googleWebClientId = '641176201184-3q7t2hp3kej2vvei41tpkivn7j206bf7.apps.googleusercontent.com';
  
  static String? get googleClientId {
    return kIsWeb ? googleWebClientId : null; 
  }
}