import 'dart:convert';
import 'dart:io'; // For SocketException, File
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../main.dart'; // Required for navigatorKey
import '../screens/login_screen.dart'; // Required for redirection

class DataService {
  
  // Helper to get headers with the token
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'auth-token': token, 
      'Authorization': 'Bearer $token', 
    };
  }

  // ✅ Helper: Save Data to Cache
  Future<void> _cacheData(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

  // ✅ Helper: Get Data from Cache
  Future<dynamic> _getCachedData(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedString = prefs.getString(key);
    if (cachedString != null) {
      print("📱 Loaded $key from Cache (Offline Mode)");
      return jsonDecode(cachedString);
    }
    return null;
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode == 401 || response.statusCode == 403) {
      _forceLogout();
      throw Exception('Session expired'); 
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } 
    else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  Future<void> _forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); 
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // --- 1. USER PROFILE ---
  Future<Map<String, dynamic>?> fetchProfile() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/profile/me');
      final response = await http.get(url, headers: headers);
      final data = _handleResponse(response);

      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return data['data'];
      }
      return data;
    } catch (e) {
      print("⚠️ Network Error. Trying Cache...");
      return null; // Profile is harder to cache simply, usually strictly online
    }
  }

  // ✅ 4. UPDATE PROFILE (Supports Image + Text)
  // This was the missing piece!
  Future<bool> updateProfile(Map<String, String> fields, File? imageFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return false;

      final uri = Uri.parse('${AppConfig.baseUrl}/api/profile/update');
      
      // We use MultipartRequest because the backend expects file upload logic
      final request = http.MultipartRequest('PUT', uri);

      // Headers
      request.headers.addAll({
        'auth-token': token,
      });

      // Add Text Fields (Bio, Name, etc.)
      request.fields.addAll(fields);

      // Add Image File (if user selected one)
      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'profilePicture', // Must match backend field name
          imageFile.path,
        ));
      }

      // Send Request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        print("✅ Profile Updated Successfully");
        return true;
      } else {
        print("❌ Update Failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("❌ Update Error: $e");
      return false;
    }
  }

  // --- 2. EVENTS (Offline Ready) ---
  Future<List<dynamic>> fetchEvents() async {
    const String cacheKey = 'cached_events';

    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/events');

      final response = await http.get(url, headers: headers);
      final data = _handleResponse(response);
      
      List<dynamic> events = [];
      if (data is List) {
        events = data;
      } else if (data is Map && data.containsKey('events')) {
        events = data['events'];
      } else if (data is Map && data.containsKey('data')) {
        events = data['data'];
      }

      // ✅ SUCCESS: Save to Cache
      await _cacheData(cacheKey, events);
      return events;

    } catch (e) {
      // ✅ FAILURE: Load from Cache
      print("⚠️ Offline Mode: Loading cached events.");
      final cached = await _getCachedData(cacheKey);
      if (cached != null && cached is List) {
        return cached;
      }
      return []; // No internet AND no cache
    }
  }

  // --- 3. DIRECTORY (Offline Ready) ---
  Future<List<dynamic>> fetchDirectory({String query = ""}) async {
    final bool isDefaultFetch = query.isEmpty;
    const String cacheKey = 'cached_directory';

    try {
      final headers = await _getHeaders();
      String endpoint = '${AppConfig.baseUrl}/api/directory';
      if (query.isNotEmpty) endpoint += '?search=$query';
      
      final url = Uri.parse(endpoint);
      final response = await http.get(url, headers: headers);
      final data = _handleResponse(response);
      
      List<dynamic> alumni = [];
      if (data is List) {
        alumni = data;
      } else if (data is Map && data.containsKey('data')) {
        alumni = data['data']; 
      }
      
      if (isDefaultFetch) {
        await _cacheData(cacheKey, alumni);
      }
      return alumni;

    } catch (e) {
      if (isDefaultFetch) {
        print("⚠️ Offline Mode: Loading cached directory.");
        final cached = await _getCachedData(cacheKey);
        if (cached != null && cached is List) {
          return cached;
        }
      }
      return [];
    }
  }
}