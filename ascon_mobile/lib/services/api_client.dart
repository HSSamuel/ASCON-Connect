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

  // ✅ UPDATED: Increased timeout
  static const Duration _timeoutDuration = Duration(seconds: 20);

  // ✅ NEW: Callback to handle token refresh
  Future<String?> Function()? onTokenRefresh;

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
      var response = await req().timeout(_timeoutDuration);

      // ✅ CRITICAL FIX: Intercept 401 (Unauthorized)
      // If the token is dead, we try to refresh it ONCE and retry the request.
      if (response.statusCode == 401 && onTokenRefresh != null) {
        print("🔄 401 Detected. Attempting Silent Refresh...");
        
        final newToken = await onTokenRefresh!();
        if (newToken != null) {
          print("✅ Token Refreshed. Retrying Request...");
          setAuthToken(newToken); // Update header
          response = await req().timeout(_timeoutDuration); // Retry original request
        }
      }

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
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (e) {
      body = {}; 
    }
    
    // Allow 404 to pass through (for Login "User Not Found")
    if ((response.statusCode >= 200 && response.statusCode < 300) || response.statusCode == 404) {
      return {
        'success': true,
        'statusCode': response.statusCode,
        'data': body
      };
    } else {
      throw Exception(body['message'] ?? 'Request failed with status ${response.statusCode}');
    }
  }
}