class AppConfig {
  // =========================================================
  // 🎚️ MODE SWITCH
  // Set this to 'true' when releasing to others.
  // Set this to 'false' while testing on your laptop/phone.
  // =========================================================
  static const bool isProduction = false; 

  // 🌍 The Online Server (For the final app)
  static const String onlineUrl = 'https://ascon.onrender.com';

  // 💻 Your Local Computer IP (For testing now)
  // ✅ Kept your specific IP here
  static const String localUrl = 'http://10.231.185.203:5000'; 

  // 🧠 Automatic Logic (Don't touch this)
  static String get baseUrl {
    return isProduction ? onlineUrl : localUrl;
  }
}