class AppConfig {
  // 🟢 TOGGLE: Set false to force Local Connection (for testing on Phone)
  static const bool useOnlineServer = false; 

  // 1. Cloud URL (Keep this for later)
  static const String onlineUrl = 'https://ascon.onrender.com';

  // 2. Local URL (Your Laptop's Wi-Fi IP)
  // We updated this to match your "Wireless LAN adapter Wi-Fi" address
  static const String localUrl = 'http://10.59.145.203:5000'; 

  // Logic to pick the right one
  static String get baseUrl {
    return useOnlineServer ? onlineUrl : localUrl;
  }
}