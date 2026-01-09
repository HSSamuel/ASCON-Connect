import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart'; 
import 'package:http_parser/http_parser.dart'; // ✅ REQUIRED for MediaType
import '../config.dart';
import '../main.dart'; 
import '../screens/login_screen.dart'; 
import 'auth_service.dart'; // ✅ Added to support AuthService calls

class DataService {
  
  // ✅ Update the _getHeaders method to trigger the self-healing refresh
  Future<Map<String, String>> _getHeaders() async {
    // Use AuthService to get the token (it handles the refresh logic automatically)
    // This ensures that if a token is expired, it's fixed BEFORE the request is sent.
    final String? token = await AuthService().getToken(); // ✅ This calls the refresh logic
    
    return {
      'Content-Type': 'application/json',
      'auth-token': token ?? '', 
      'Authorization': 'Bearer ${token ?? ""}', 
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
      _forceLogout(); // ✅ Redirects to LoginScreen if session is invalid
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

  // ✅ UPDATE PROFILE (With Strict Content-Type)
  Future<bool> updateProfile(Map<String, String> fields, XFile? imageFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Ensure we use a fresh token for the multipart request
      final token = await AuthService().getToken();
      if (token == null) return false;

      final uri = Uri.parse('${AppConfig.baseUrl}/api/profile/update');
      
      final request = http.MultipartRequest('PUT', uri);

      request.headers.addAll({
        'auth-token': token,
      });

      request.fields.addAll(fields);

      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        
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

  // ✅ FETCH SINGLE EVENT BY ID (Fixes notification loading stuck)
  Future<Map<String, dynamic>?> fetchEventById(String id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/events/$id');
      final response = await http.get(url, headers: headers);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data.containsKey('data')) {
          return data['data'];
        }
        return data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint("❌ Error fetching single event: $e");
      return null;
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

  // ✅ Register for Events (Reunions, Webinars, etc.)
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

  // ✅ FETCH MY NOTIFICATIONS (Authenticated)
  Future<List<dynamic>> fetchMyNotifications() async {
    try {
      final headers = await _getHeaders(); // ✅ Automatically includes fresh token
      final url = Uri.parse('${AppConfig.baseUrl}/api/notifications/my-notifications');
      
      final response = await http.get(url, headers: headers);
      final data = _handleResponse(response); // ✅ Automatically handles session expiration

      if (data != null && data['success'] == true) {
        return data['data'];
      }
      return [];
    } catch (e) {
      debugPrint("Notification Fetch Error: $e");
      return [];
    }
  }

  // ✅ NEW: FETCH UNREAD COUNT (Specifically for Bell Heartbeat)
  // This allows the app to check for admin posts every 60 seconds without heavy load.
  Future<int> fetchUnreadNotificationCount() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/notifications/unread-count');
      
      final response = await http.get(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['unreadCount'] ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint("Unread Count Fetch Error: $e");
      return 0;
    }
  }
}