import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter/foundation.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart'; 
import 'package:http/http.dart' as http; 
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config.dart'; 
import '../config/storage_config.dart';
import '../main.dart'; 
import '../screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'notification_service.dart';
import 'socket_service.dart'; // ✅ NEW: Import Socket Service

class AuthService {
  final ApiClient _api = ApiClient();
  
  static String? _tokenCache; 
  
  // ✅ ENCRYPTED VAULT FOR TOKENS
  final _secureStorage = StorageConfig.storage;

  AuthService() {
    _api.onTokenRefresh = _performSilentRefresh;
  }

  // ✅ HELPER: Fetch FCM Token safely with Environment Variable
  Future<String?> _getFcmToken() async {
    try {
      if (kIsWeb) {
        // ✅ FIX: Load key from .env
        String? vapidKey = dotenv.env['FIREBASE_VAPID_KEY'];
        if (vapidKey == null || vapidKey.isEmpty) {
          debugPrint("⚠️ Warning: FIREBASE_VAPID_KEY not found in .env");
          return null;
        }

        return await FirebaseMessaging.instance.getToken(
          vapidKey: vapidKey
        );
      } else {
        return await FirebaseMessaging.instance.getToken();
      }
    } catch (e) {
      debugPrint("⚠️ Failed to get FCM token during auth: $e");
      return null;
    }
  }

  // --- LOGIN ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final String? fcmToken = await _getFcmToken();

      final result = await _api.post('/api/auth/login', {
        'email': email,
        'password': password,
        'fcmToken': fcmToken, 
      });

      if (result['success']) {
        final data = result['data'];
        await _saveUserSession(
          data['token'], 
          data['user'], 
          refreshToken: data['refreshToken']
        );

        if (!kIsWeb) {
           await NotificationService().init();
        }
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': _cleanError(e)};
    }
  }

  // --- REGISTER ---
  Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String phoneNumber,
    required String programmeTitle,
    required String yearOfAttendance,
    String? googleToken,
  }) async {
    try {
      final String? fcmToken = await _getFcmToken();

      final result = await _api.post('/api/auth/register', {
        'fullName': fullName,
        'email': email,
        'password': password,
        'phoneNumber': phoneNumber,
        'programmeTitle': programmeTitle,
        'yearOfAttendance': yearOfAttendance,
        'googleToken': googleToken,
        'fcmToken': fcmToken, 
      });

      if (result['success'] && result['data']['token'] != null) {
        final data = result['data'];
        await _saveUserSession(
          data['token'], 
          data['user'] ?? {}, 
          refreshToken: data['refreshToken']
        );
        
        if (!kIsWeb) {
          await NotificationService().init();
          await NotificationService().syncToken();
        }
      }

      return result;
    } catch (e) {
      return {'success': false, 'message': _cleanError(e)};
    }
  }

  // --- GOOGLE LOGIN ---
  Future<Map<String, dynamic>> googleLogin(String? idToken) async {
    if (idToken == null) return {'success': false, 'message': 'Google Sign-In failed'};

    try {
      final String? fcmToken = await _getFcmToken();

      final result = await _api.post('/api/auth/google', {
        'token': idToken,
        'fcmToken': fcmToken, 
      });

      if (result['success']) {
        final data = result['data'];
        await _saveUserSession(
          data['token'], 
          data['user'], 
          refreshToken: data['refreshToken']
        );
        
        if (!kIsWeb) {
          await NotificationService().init();
        }
      }
      return result;
    } catch (e) {
      return {'success': false, 'message': _cleanError(e)};
    }
  }

  // --- FORGOT PASSWORD ---
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      return await _api.post('/api/auth/forgot-password', {'email': email});
    } catch (e) {
      return {'success': false, 'message': _cleanError(e)};
    }
  }

  Future<List<dynamic>> getProgrammes() async {
    try {
      final result = await _api.get('/api/admin/programmes');
      if (result['success']) {
        final data = result['data'];
        if (data is Map && data.containsKey('programmes')) {
          return data['programmes']; 
        } else if (data is List) {
          return data;
        }
      }
      return [];
    } catch (e) {
      print("Error fetching programmes: $e");
      return [];
    }
  }

  Future<void> markWelcomeSeen() async {
    try {
      await _api.put('/api/profile/welcome-seen', {});
    } catch (e) {
      print("Error marking welcome seen: $e");
    }
  }

  // =================================================
  // 🔄 SILENT REFRESH LOGIC
  // =================================================
  Future<String?> _performSilentRefresh() async {
    try {
      print("🔄 Attempting Silent Refresh...");
      // ✅ Read securely
      String? refreshToken = await _secureStorage.read(key: 'refresh_token');
      if (refreshToken == null) {
        print("❌ No refresh token found.");
        return null;
      }

      final result = await http.post(
        Uri.parse('${AppConfig.baseUrl}/api/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );

      if (result.statusCode == 200) {
        final body = jsonDecode(result.body);
        final newToken = body['token']; 
        
        if (newToken != null) {
          _tokenCache = newToken;
          // ✅ Save securely
          await _secureStorage.write(key: 'auth_token', value: newToken);

          _api.setAuthToken(newToken);
          print("✅ Silent Refresh Successful!");
          return newToken;
        }
      } else {
        print("❌ Refresh Failed (Status: ${result.statusCode}). Logging out.");
        await logout(); 
        return null;
      }
    } catch (e) {
      print("❌ Silent Refresh Error: $e");
      return null;
    }
    return null;
  }

  // =================================================
  // 🔐 SESSION MANAGEMENT (Upgraded Security)
  // =================================================
  
  Future<void> _saveUserSession(String token, Map<String, dynamic> user, {String? refreshToken}) async {
  try {
    _tokenCache = token;
    _api.setAuthToken(token);

    // ✅ 1. STORE TOKENS STRICTLY IN ENCRYPTED STORAGE
    await _secureStorage.write(key: 'auth_token', value: token);
    if (refreshToken != null) {
      await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    }

    final userId = user['id'] ?? user['_id']; 
    if (userId != null) {
      await _secureStorage.write(key: 'userId', value: userId);

      // ========================================================
      // ✅ NEW: DOUBLE-TAP PRESENCE FIX (Background Connection)
      // Instant socket connection before UI starts rendering.
      // ========================================================
      SocketService().connectUser(userId);

    } else {
      debugPrint("⚠️ Warning: User ID not found in session data");
    }

    // ✅ 2. STORE UI CACHE IN STANDARD SHARED PREFS (No security risk here)
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', jsonEncode(user));
      
    if (user['fullName'] != null) {
      await prefs.setString('user_name', user['fullName']);
    }
    if (user['alumniId'] != null) {
      await prefs.setString('alumni_id', user['alumniId']);
    }
      
    } catch (e) {
      print("⚠️ Session Save Error: $e");
    }
  }

  Future<String?> getToken() async {
    try {
      if (_tokenCache != null && _tokenCache!.isNotEmpty) {
        return _tokenCache;
      }

      // ✅ Read securely from encrypted vault
      String? token = await _secureStorage.read(key: 'auth_token');
      String? refreshToken = await _secureStorage.read(key: 'refresh_token');

      // (Legacy Check: If user is updating from an old app version, migrate token)
      if (token == null) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('auth_token');
        if (token != null) {
          // Move to secure storage and delete from shared prefs
          await _secureStorage.write(key: 'auth_token', value: token);
          await prefs.remove('auth_token');
        }
      }

      if (token == null) return null;

      bool isExpired = JwtDecoder.isExpired(token) || 
                       JwtDecoder.getRemainingTime(token).inSeconds < 60;

      if (isExpired) {
        print("⚠️ Token Expired. Attempting Refresh...");
        
        if (refreshToken != null) {
          try {
            final result = await _api.post('/api/auth/refresh', {'refreshToken': refreshToken});
            if (result['success']) {
              final newToken = result['data']['token'];
              
              _tokenCache = newToken;
              // ✅ Save securely
              await _secureStorage.write(key: 'auth_token', value: newToken);
              
              _api.setAuthToken(newToken);
              return newToken;
            }
          } catch (e) {
            print("❌ Refresh Failed: $e");
          }
        }
        return null;
      }
      
      _tokenCache = token; 
      _api.setAuthToken(token);
      return token;
    } catch (e) {
      print("⚠️ Critical Storage Error (getToken): $e");
      return null;
    }
  }

  Future<bool> isSessionValid() async {
    final token = await getToken();
    return token != null;
  }

  Future<Map<String, dynamic>?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('cached_user');
    if (userData != null) {
      return jsonDecode(userData);
    }
    return null;
  }

  // =================================================
  // 🚪 LOGOUT (FIXED FOR WEB RACE CONDITION)
  // =================================================
  Future<void> logout() async {
    // ✅ NEW: Disconnect Socket on Logout
    try {
      SocketService().disconnect();
    } catch (e) {
      debugPrint("⚠️ Socket disconnect error: $e");
    }

    // 1. Google Sign Out (Safely)
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? AppConfig.googleWebClientId : null,
        serverClientId: kIsWeb ? null : AppConfig.googleWebClientId,
      );
      
      if (await googleSignIn.isSignedIn()) {
        // Force disconnect first to clear internal state
        try {
          await googleSignIn.disconnect(); 
        } catch (_) {} 
        
        await googleSignIn.signOut();
        debugPrint("✅ Google Sign Out Successful");
      }
    } catch (e) {
      // ✅ FIX: Ignore "Future already completed" error on Web
      if (!e.toString().contains("Bad state")) {
         debugPrint("⚠️ Google Sign Out Warning: $e");
      }
    }

    // 2. Clear Encrypted Tokens First
    try {
      _tokenCache = null; 
      await _secureStorage.delete(key: 'auth_token');
      await _secureStorage.delete(key: 'refresh_token');
      await _secureStorage.delete(key: 'userId');
    } catch (e) {
      debugPrint("Storage clear error: $e");
    }
    
    // 3. Clear UI Cache
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    
    _api.clearAuthToken();
    
    // ✅ 4. Small Delay for Web Stability
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // 5. Navigate to Login
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false, 
    );
  }

  String _cleanError(Object e) {
    return e.toString().replaceAll("Exception: ", "");
  }
}