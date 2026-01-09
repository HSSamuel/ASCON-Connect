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
      final response = await req().timeout(_timeoutDuration);
      return _processResponse(response);
    } on TimeoutException {
      throw Exception('Server is taking too long to respond. Please check your connection.');
    } on SocketException {
      throw Exception('No internet connection. Please try again later.');
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }

  dynamic _processResponse(http.Response response) {
    // 1. Decode body safely (Handle empty or non-JSON responses)
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (e) {
      body = {}; 
    }
    
    // 2. ✅ CRITICAL FIX: Allow 404 to pass through as "Success"
    // This allows the Login Screen to detect "User Not Found" and redirect to Register
    if ((response.statusCode >= 200 && response.statusCode < 300) || response.statusCode == 404) {
      return {
        'success': true,
        'statusCode': response.statusCode, // ✅ We now return the code explicitly
        'data': body
      };
    } else {
      // For actual errors (500, 401, 403), we still throw
      throw Exception(body['message'] ?? 'Request failed with status ${response.statusCode}');
    }
  }
}