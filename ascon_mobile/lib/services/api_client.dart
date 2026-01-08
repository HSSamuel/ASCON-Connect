import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  // ✅ OPTIMIZED: Reduced timeout from 45s to 15s for better mobile UX
  static const Duration _timeoutDuration = Duration(seconds: 15);

  void setAuthToken(String token) {
    _headers['auth-token'] = token;
  }

  void clearAuthToken() {
    _headers.remove('auth-token');
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    final response = await _request(() => http.post(
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    ));
    return response as Map<String, dynamic>; 
  }

  // ✅ NEW: Added PUT method support for profile updates and admin actions
  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body) async {
    final response = await _request(() => http.put(
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
      headers: _headers,
      body: jsonEncode(body),
    ));
    return response as Map<String, dynamic>;
  }

  Future<dynamic> get(String endpoint) async {
    return _request(() => http.get(
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
      headers: _headers,
    ));
  }

  Future<dynamic> _request(Future<http.Response> Function() req) async {
    try {
      // ✅ IMPROVED: Implemented standardized timeout
      final response = await req().timeout(_timeoutDuration);
      return _processResponse(response);
    } on TimeoutException {
      // ✅ USER-FRIENDLY ERRORS: More descriptive messages
      throw Exception('Server is taking too long to respond. Please check your connection.');
    } on SocketException {
      throw Exception('No internet connection. Please try again later.');
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  dynamic _processResponse(http.Response response) {
    final body = jsonDecode(response.body);
    
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {'success': true, 'data': body};
    } else {
      throw Exception(body['message'] ?? 'Request failed');
    }
  }
}