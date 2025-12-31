class AppConfig {
  // 🟢 TOGGLE: Set false to use your Local Backend
  static const bool useOnlineServer = false; 

  // 1. Cloud URL (Keep for later)
  static const String onlineUrl = 'https://ascon.onrender.com';

  // 2. Local URL
  // ✅ FIX: For Chrome/Web, always use 'localhost'
  static const String localUrl = 'http://localhost:5000'; 

  // Logic to pick the right one
  static String get baseUrl {
    return useOnlineServer ? onlineUrl : localUrl;
  }
}