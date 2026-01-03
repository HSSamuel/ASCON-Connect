import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class DataService {
  
  // Helper to get headers with the token
  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    return {
      'Content-Type': 'application/json',
      'auth-token': token,
      'Authorization': 'Bearer $token', // Some endpoints might use Bearer
    };
  }

  // Helper to handle HTTP errors safely
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // If body is empty, return null or empty list depending on context
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      // If unauthorized, we might want to trigger logout logic later
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw Exception('Unauthorized');
      }
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  // --- 1. USER PROFILE ---
  Future<Map<String, dynamic>?> fetchProfile() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/profile/me');
      
      final response = await http.get(url, headers: headers);
      return _handleResponse(response);
    } catch (e) {
      print("Error fetching profile: $e");
      return null; // Return null safely instead of crashing
    }
  }

  // --- 2. EVENTS ---
  Future<List<dynamic>> fetchEvents() async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AppConfig.baseUrl}/api/events');

      final response = await http.get(url, headers: headers);
      
      final data = _handleResponse(response);
      
      // Handle different formats (List vs Map with 'events' key)
      if (data is Map && data.containsKey('events')) {
        return data['events'];
      } else if (data is List) {
        return data;
      }
      return [];
    } catch (e) {
      print("Error fetching events: $e");
      return []; // Return empty list safely
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
      
      if (data is List) return data;
      return [];
    } catch (e) {
      print("Error fetching directory: $e");
      return [];
    }
  }
}