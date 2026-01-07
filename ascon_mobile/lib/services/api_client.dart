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

  void setAuthToken(String token) {
    _headers['auth-token'] = token;
  }

  void clearAuthToken() {
    _headers.remove('auth-token');
  }

  // ✅ FIX: Explicitly cast return type to Map<String, dynamic>
  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    final response = await _request(() => http.post(
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
      final response = await req().timeout(const Duration(seconds: 45));
      return _processResponse(response);
    } on TimeoutException {
      throw Exception('Connection timed out. Please try again.');
    } on SocketException {
      throw Exception('No internet connection.');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
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