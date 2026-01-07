import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import '../main.dart'; // For navigatorKey
import '../screens/login_screen.dart';
import 'package:flutter/material.dart';

// ✅ IMPORT THE NEW API CLIENT
import 'api_client.dart';
import 'notification_service.dart';

class AuthService {
  // Use the singleton ApiClient instance
  final ApiClient _api = ApiClient();

  // --- LOGIN ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final result = await _api.post('/api/auth/login', {
        'email': email,
        'password': password,
        // (Optional) Send FCM token if you implemented that logic
      });

      if (result['success']) {
        final data = result['data'];
        await _saveUserSession(data['token'], data['user']);

        // ✅ Initialize notifications after successful login
        if (!kIsWeb) {
           NotificationService().init();
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
        await _saveUserSession(result['data']['token'], result['data']['user'] ?? {});
        if (!kIsWeb) NotificationService().init();
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
        await _saveUserSession(data['token'], data['user']);
        if (!kIsWeb) NotificationService().init();
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

  // --- FETCH PROGRAMMES (Public/Admin route) ---
  Future<List<dynamic>> getProgrammes() async {
    try {
      final result = await _api.get('/api/admin/programmes');
      if (result['success']) {
        // Handle paginated response structure if needed, or simple array
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

  // --- MARK WELCOME SEEN ---
  Future<void> markWelcomeSeen() async {
    try {
      // Direct HTTP put using ApiClient logic (assuming put method exists or we add it)
      // If ApiClient doesn't have PUT, we can add it, or use post if backend allows.
      // Assuming we extended ApiClient to have .put or we use .post for now.
      // For this example, let's assume we added a .put method to ApiClient similar to .post
      // If not, simply skip or use raw http here for this one-off.
    } catch (e) {
      print("Error marking welcome seen: $e");
    }
  }

  // --- SESSION HELPERS ---
  
  Future<void> _saveUserSession(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    
    // Configure API Client with new token
    _api.setAuthToken(token);

    if (user['fullName'] != null) {
      await prefs.setString('user_name', user['fullName']);
    }
    if (user['alumniId'] != null) {
      await prefs.setString('alumni_id', user['alumniId']);
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) return null;

    if (JwtDecoder.isExpired(token)) {
      print("⚠️ Token Expired. Logging out.");
      await logout();
      return null;
    }
    
    // Ensure API client has the token loaded
    _api.setAuthToken(token);
    return token;
  }

  Future<bool> isSessionValid() async {
    final token = await getToken();
    return token != null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _api.clearAuthToken();
    
    // Navigate to Login
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false, 
    );
  }

  // Helper to remove "Exception: " prefix from error messages
  String _cleanError(Object e) {
    return e.toString().replaceAll("Exception: ", "");
  }
}