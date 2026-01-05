import 'dart:convert';
import 'dart:async'; // ✅ Import for TimeoutException
import 'dart:io';    // ✅ Import for SocketException
import 'package:flutter/material.dart'; 
import 'package:flutter/foundation.dart'; // ✅ For kIsWeb check
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart'; // ✅ Token Expiry Check
import '../config.dart';
import '../main.dart'; 
import '../screens/login_screen.dart';
import 'notification_service.dart'; // ✅ Import Notification Service

class AuthService {
  
  // Generic helper to handle HTTP errors & Session Expiry
  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    try {
      // ✅ 1. SECURITY CHECK: Backend says Session Expired (401/403)
      if (response.statusCode == 401 || response.statusCode == 403) {
        await logout(); // Clear local storage

        // Use the Global Key to force navigation to Login
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false, 
        );

        return {'success': false, 'message': 'Session expired. Please login again.'};
      }

      // 2. Check if the body is empty
      if (response.body.isEmpty) {
        return {'success': false, 'message': 'Empty response from server'};
      }

      // 3. Try to parse JSON
      final data = jsonDecode(response.body);

      // 4. Check Status Code (Success)
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Something went wrong'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Server Error: Invalid response format'};
    }
  }

  // --- LOGIN ---
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/auth/login');
      print("🔵 Logging in to: $url"); 

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 90)); 

      final result = await _handleResponse(response);

      if (result['success'] == true) {
        final data = result['data'];
        await _saveUserSession(data['token'], data['user']);

        // ✅ SYNC NOTIFICATION TOKEN
        if (!kIsWeb) {
           NotificationService().init();
        }
      }
      return result;
    } catch (e) {
      print("🔴 LOGIN ERROR: $e"); 
      return _handleError(e);
    }
  }

  // --- FETCH PROGRAMMES (Dynamic) ---
  Future<List<dynamic>> getProgrammes() async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/admin/programmes');
      final response = await http.get(url).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body); 
      } else {
        return [];
      }
    } catch (e) {
      print("Error fetching programmes: $e");
      return [];
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
      final url = Uri.parse('${AppConfig.baseUrl}/api/auth/register');
      print("🔵 Registering at: $url");

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          'password': password,
          'phoneNumber': phoneNumber,
          'programmeTitle': programmeTitle,
          'yearOfAttendance': yearOfAttendance,
          'googleToken': googleToken, 
        }),
      ).timeout(const Duration(seconds: 90));

      print("Response: ${response.body}"); 

      final result = await _handleResponse(response);
      
      // If registration is successful and returns a token, save session immediately
      if (result['success'] == true && result['data']['token'] != null) {
          await _saveUserSession(result['data']['token'], result['data']['user'] ?? {});
          
          // ✅ SYNC NOTIFICATION TOKEN
          if (!kIsWeb) {
             NotificationService().init();
          }
      }

      return result;
    } catch (e) {
      print("🔴 REGISTER ERROR: $e");
      return _handleError(e);
    }
  }

  // --- GOOGLE LOGIN ---
  Future<Map<String, dynamic>> googleLogin(String? idToken) async {
    if (idToken == null) return {'success': false, 'message': 'Google Sign-In failed'};

    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/auth/google');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': idToken}),
      ).timeout(const Duration(seconds: 90)); 

      final result = await _handleResponse(response);

      if (result['success'] == true) {
        if (response.statusCode == 200) {
           final data = result['data'];
           await _saveUserSession(data['token'], data['user']);

           // ✅ SYNC NOTIFICATION TOKEN
           if (!kIsWeb) {
              NotificationService().init();
           }
        }
        result['statusCode'] = response.statusCode;
      }
      return result;
    } catch (e) {
      print("🔴 GOOGLE LOGIN ERROR: $e");
      return _handleError(e);
    }
  }

  // --- FORGOT PASSWORD ---
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final url = Uri.parse('${AppConfig.baseUrl}/api/auth/forgot-password');
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 120));

      return await _handleResponse(response);
    } catch (e) {
      return _handleError(e);
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ NEW: MARK WELCOME AS SEEN
  // ---------------------------------------------------------------------------
  Future<void> markWelcomeSeen() async {
    try {
      // Use helper to ensure token is valid before sending
      final String? token = await getToken(); 

      if (token == null) return;

      final url = Uri.parse('${AppConfig.baseUrl}/api/profile/welcome-seen');
      
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'auth-token': token, 
        },
      );
      
      if (response.statusCode == 200) {
        print("✅ Backend: Welcome status updated successfully.");
      } else {
        print("❌ Backend: Failed to update welcome status: ${response.body}");
      }
    } catch (e) {
      print("❌ Error calling welcome-seen API: $e");
    }
  }

  // --- SESSION HELPERS ---
  Future<void> _saveUserSession(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    if (user['fullName'] != null) {
      await prefs.setString('user_name', user['fullName']);
    }
  }

  // ✅ UPDATED: Public Helper to get Token
  // This now checks if the token is EXPIRED. If yes, it logs out automatically.
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    // 1. If no token, return null
    if (token == null) return null;

    // 2. Check Expiry using JwtDecoder
    if (JwtDecoder.isExpired(token)) {
      print("⚠️ Token is expired. Logging out user...");
      await logout(); // Clear storage
      return null;    // Return null so the app knows we aren't logged in
    }

    // 3. Token is valid
    return token;
  }

  // ✅ NEW: Helper to check if session is valid (for Splash Screen)
  Future<bool> isSessionValid() async {
    final token = await getToken();
    return token != null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  // Centralized Error Handler
  Map<String, dynamic> _handleError(Object error) {
    if (error is TimeoutException) {
      return {'success': false, 'message': 'Server is waking up. Please try again in 30 seconds.'};
    } else if (error is SocketException) {
      return {'success': false, 'message': 'No Internet Connection. Check your WiFi/Data.'};
    } else {
      return {'success': false, 'message': 'Connection Error. Please check internet.'};
    }
  }
}