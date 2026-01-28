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

  // Increased timeout for slower networks
  static const Duration _timeoutDuration = Duration(seconds: 90);

  // Callback to handle token refresh
  Future<String?> Function()? onTokenRefresh;

  // ✅ LOCKING MECHANISM VARIABLES
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

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

  // ✅ NEW: DELETE METHOD (Added for Chat Deletion)
  Future<dynamic> delete(String endpoint) async {
    return _request(() => http.delete(
      Uri.parse('${AppConfig.baseUrl}$endpoint'),
      headers: _headers,
    ));
  }

  Future<dynamic> _request(Future<http.Response> Function() req) async {
    try {
      var response = await req().timeout(_timeoutDuration);

      // ✅ CRITICAL FIX: Handle Race Condition for 401
      if (response.statusCode == 401 && onTokenRefresh != null) {
        print("🔄 401 Detected.");

        String? newToken;

        if (_isRefreshing) {
          // If already refreshing, wait for the pending refresh to complete
          print("⏳ Waiting for pending refresh...");
          newToken = await _refreshCompleter?.future;
        } else {
          // Start a new refresh process
          _isRefreshing = true;
          _refreshCompleter = Completer<String?>();
          print("🔄 Initiating Silent Refresh...");

          try {
            newToken = await onTokenRefresh!();
            _refreshCompleter?.complete(newToken);
          } catch (e) {
            _refreshCompleter?.complete(null);
          } finally {
            _isRefreshing = false;
            _refreshCompleter = null;
          }
        }

        // If we got a valid token (either from our refresh or the waiting one), retry
        if (newToken != null) {
          print("✅ Token Refreshed. Retrying Request...");
          setAuthToken(newToken); 
          response = await req().timeout(_timeoutDuration); 
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