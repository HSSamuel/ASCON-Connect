class AppConfig {
  // =========================================================
  // 🚀 PRODUCTION MODE: ON
  // =========================================================
  static const bool isProduction = true; 

  // 🌍 The Online Server (Your active backend)
  static const String onlineUrl = 'https://ascon.onrender.com';

  // 💻 Local Backup (Ignored when isProduction is true)
  static const String localUrl = 'http://10.231.185.203:5000'; 

  static String get baseUrl {
    return isProduction ? onlineUrl : localUrl;
  }
}