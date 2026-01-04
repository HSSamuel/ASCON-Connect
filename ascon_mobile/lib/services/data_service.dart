import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../main.dart'; // ✅ Required for navigatorKey
import '../screens/login_screen.dart'; // ✅ Required for redirection

class DataService {
  
  // Helper to get headers with the token
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'auth-token': token, // Standard header
      'Authorization': 'Bearer $token', // Backup standard
    };
  }

  // ✅ ROBUST ERROR HANDLER
  // Handles 401 (Session Expired) by kicking the user out to Login
  dynamic _handleResponse(http.Response response) {
    // 1. Session Expired / Unauthorized
    if (response.statusCode == 401 || response.statusCode == 403) {
      _forceLogout();
      throw Exception('Session expired'); 
    }

    // 2. Success
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } 
    
    // 3. Other Errors
    else {
      print("⚠️ API Error: ${response.statusCode} - ${response.body}");
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  // ✅ Helper to Force Logout
  Future<void> _forceLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear token

    // Use global key to navigate without context
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

      // Handle wrapper object if exists (e.g. { success: true, data: {...} })
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return data['data'];
      }
      return data; // Return direct map
    } catch (e) {
      print("Error fetching profile: $e");
      return null;
    }
  }

  // --- 2. EVENTS ---
  Future<List<dynamic>> fetchEvents() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/events');

      final response = await http.get(url, headers: headers);
      final data = _handleResponse(response);
      
      // ✅ Handle different backend formats safely
      if (data == null) return [];
      
      if (data is List) {
        return data;
      } else if (data is Map && data.containsKey('events')) {
        return data['events'];
      } else if (data is Map && data.containsKey('data')) {
        return data['data']; // Common standard wrapper
      }
      
      return [];
    } catch (e) {
      print("Error fetching events: $e");
      return []; 
    }
  }

  // --- 3. DIRECTORY ---
  Future<List<dynamic>> fetchDirectory({String query = ""}) async {
    try {
      final headers = await _getHeaders();
      String endpoint = '${AppConfig.baseUrl}/api/directory';
      if (query.isNotEmpty) endpoint += '?search=$query';
      
      final url = Uri.parse(endpoint);
      final response = await http.get(url, headers: headers);

      final data = _handleResponse(response);
      
      // ✅ Handle different backend formats safely
      if (data == null) return [];

      if (data is List) {
        return data;
      } else if (data is Map && data.containsKey('data')) {
        return data['data']; // Handle wrapper { success: true, data: [] }
      }
      
      return [];
    } catch (e) {
      print("Error fetching directory: $e");
      return [];
    }
  }
}