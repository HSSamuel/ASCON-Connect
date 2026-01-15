import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter/foundation.dart'; 
import '../main.dart'; 
import '../screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'api_client.dart';
import 'notification_service.dart';

class AuthService {
  final ApiClient _api = ApiClient();
  
  static String? _tokenCache; 
  
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // --- LOGIN ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final result = await _api.post('/api/auth/login', {
        'email': email,
        'password': password,
      });

      if (result['success']) {
        final data = result['data'];
        await _saveUserSession(
          data['token'], 
          data['user'], 
          refreshToken: data['refreshToken']
        );

        if (!kIsWeb) {
          // ✅ FIX: Force sync immediately after saving session
          await NotificationService().init();
          await NotificationService().syncToken(); 
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
      final result = await _api.post('/api/auth/register', {
        'fullName': fullName,
        'email': email,
        'password': password,
        'phoneNumber': phoneNumber,
        'programmeTitle': programmeTitle,
        'yearOfAttendance': yearOfAttendance,
        'googleToken': googleToken,
      });

      if (result['success'] && result['data']['token'] != null) {
        final data = result['data'];
        await _saveUserSession(
          data['token'], 
          data['user'] ?? {}, 
          refreshToken: data['refreshToken']
        );
        
        if (!kIsWeb) {
          // ✅ FIX: Force sync immediately
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
      final result = await _api.post('/api/auth/google', {'token': idToken});

      if (result['success']) {
        final data = result['data'];
        await _saveUserSession(
          data['token'], 
          data['user'], 
          refreshToken: data['refreshToken']
        );
        
        if (!kIsWeb) {
          // ✅ FIX: Force sync immediately
          await NotificationService().init();
          await NotificationService().syncToken();
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
  // 🔐 SESSION MANAGEMENT (FIXED)
  // =================================================
  
  Future<void> _saveUserSession(String token, Map<String, dynamic> user, {String? refreshToken}) async {
    try {
      // 1. In-Memory (Instant)
      _tokenCache = token;
      _api.setAuthToken(token);

      // 2. Secure Storage (Primary)
      await _storage.write(key: 'auth_token', value: token);
      if (refreshToken != null) {
        await _storage.write(key: 'refresh_token', value: refreshToken);
      }

      // 3. Shared Preferences (Backup for NotificationService & User Data)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token); // ✅ Backup Token
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

      String? token = await _storage.read(key: 'auth_token');
      String? refreshToken = await _storage.read(key: 'refresh_token');

      // ✅ Fallback: Try SharedPreferences if SecureStorage fails
      if (token == null) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('auth_token');
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
              await _storage.write(key: 'auth_token', value: newToken);
              
              // Update Backup
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('auth_token', newToken);

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

  Future<void> logout() async {
    try {
      _tokenCache = null; 
      await _storage.deleteAll();
    } catch (e) {
      print("Storage clear error: $e");
    }
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // This now correctly clears the backup 'auth_token' too
    
    _api.clearAuthToken();
    
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false, 
    );
  }

  String _cleanError(Object e) {
    return e.toString().replaceAll("Exception: ", "");
  }
}