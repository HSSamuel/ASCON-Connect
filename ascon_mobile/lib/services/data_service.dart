import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:http_parser/http_parser.dart'; // ✅ REQUIRED for MediaType
import '../config.dart';
import '../main.dart'; 
import '../screens/login_screen.dart'; 

class DataService {
  
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'auth-token': token, 
      'Authorization': 'Bearer $token', 
    };
  }

  Future<void> _cacheData(String key, dynamic data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(data));
  }

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
      return null; 
    }
  }

  // ✅ 4. UPDATE PROFILE (With Strict Content-Type)
  Future<bool> updateProfile(Map<String, String> fields, XFile? imageFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return false;

      final uri = Uri.parse('${AppConfig.baseUrl}/api/profile/update');
      
      final request = http.MultipartRequest('PUT', uri);

      request.headers.addAll({
        'auth-token': token,
      });

      request.fields.addAll(fields);

      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        
        // ✅ FIX: Explicitly tell Cloudinary this is an Image
        String mimeType = "image/jpeg"; // Default
        if (imageFile.name.toLowerCase().endsWith(".png")) {
          mimeType = "image/png";
        }
        
        var type = MediaType.parse(mimeType);

        request.files.add(http.MultipartFile.fromBytes(
          'profilePicture',
          bytes,
          filename: imageFile.name,
          contentType: type, // ✅ EXPLICIT CONTENT TYPE
        ));
      }

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

  // --- 2. EVENTS ---
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
      await _cacheData(cacheKey, events);
      return events;
    } catch (e) {
      final cached = await _getCachedData(cacheKey);
      if (cached != null && cached is List) return cached;
      return []; 
    }
  }

  // --- 3. DIRECTORY ---
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
      
      if (isDefaultFetch) await _cacheData(cacheKey, alumni);
      return alumni;
    } catch (e) {
      if (isDefaultFetch) {
        final cached = await _getCachedData(cacheKey);
        if (cached != null && cached is List) return cached;
      }
      return [];
    }
  }

  // ✅ Register Programme Interest
  Future<Map<String, dynamic>> registerProgrammeInterest({
    required String programmeId,
    required String fullName,
    required String email,
    required String phone,
    required String sex,
    required String addressStreet,
    String? addressLine2,
    required String city,
    required String state,
    required String country,
    required String sponsoringOrganisation,
    required String department,
    required String jobTitle,
    String? userId,
  }) async {
    final url = Uri.parse('${AppConfig.baseUrl}/api/programme-interest');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'programmeId': programmeId,
          'fullName': fullName,
          'email': email,
          'phone': phone,
          'sex': sex,
          'addressStreet': addressStreet,
          'addressLine2': addressLine2 ?? "",
          'city': city,
          'state': state,
          'country': country,
          'sponsoringOrganisation': sponsoringOrganisation,
          'department': department,
          'jobTitle': jobTitle,
          if (userId != null) 'userId': userId,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'message': data['message']};
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed.'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error.'};
    }
  }

  // ✅ NEW: Register for Events (Reunions, Webinars, etc.)
  Future<Map<String, dynamic>> registerEventInterest({
    required String eventId,
    required String eventTitle,
    required String eventType,
    required String fullName,
    required String email,
    required String phone,
    required String sex,
    required String organization,
    required String jobTitle,
    String? specialRequirements,
    String? userId,
  }) async {
    try {
      // ✅ FIX: Use AppConfig.baseUrl and correct path
      final url = Uri.parse('${AppConfig.baseUrl}/api/event-registration');

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "eventId": eventId,
          "eventTitle": eventTitle,
          "eventType": eventType,
          "fullName": fullName,
          "email": email,
          "phone": phone,
          "sex": sex,
          "organization": organization,
          "jobTitle": jobTitle,
          "specialRequirements": specialRequirements,
          "userId": userId,
        }),
      );

      final data = jsonDecode(response.body);
      return {"success": response.statusCode == 201, "message": data['message'] ?? "Registration submitted"};
    } catch (e) {
      return {"success": false, "message": "Connection error. Please try again."};
    }
  }
}