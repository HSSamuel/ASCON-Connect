import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config.dart';
import '../config/storage_config.dart';

/// ✅ Custom Exception for typed error handling in ViewModels
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  // ✅ ENCRYPTED VAULT FOR TOKENS
  final _secureStorage = StorageConfig.storage;

  // Optimized timeout for mobile networks (30s is standard)
  static const Duration _timeoutDuration = Duration(seconds: 30);

  // Callback to handle token refresh
  Future<String?> Function()? onTokenRefresh;

  // ✅ LOCKING MECHANISM VARIABLES
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;

  // =========================================================
  // 🔐 DYNAMIC SECURE HEADER GENERATOR
  // =========================================================
  Future<Map<String, String>> _getSecureHeaders() async {
    final token = await _secureStorage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'auth-token': token, 
    };
  }

  // ✅ Legacy method kept for backward compatibility with AuthService
  void setAuthToken(String token) {
    // No longer needs to set a static map, as _getSecureHeaders reads dynamically
  }

  void clearAuthToken() {
    // Tokens are now cleared directly in AuthService via secureStorage.delete()
  }

  Future<Map<String, dynamic>> post(String endpoint, Map<String, dynamic> body) async {
    // ✅ FIX: Move header generation INSIDE the closure so retries pick up new tokens
    final response = await _request(() async {
      final headers = await _getSecureHeaders();
      return http.post(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
    });
    return response as Map<String, dynamic>; 
  }

  Future<Map<String, dynamic>> put(String endpoint, Map<String, dynamic> body) async {
    // ✅ FIX: Move header generation INSIDE the closure
    final response = await _request(() async {
      final headers = await _getSecureHeaders();
      return http.put(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
        body: jsonEncode(body),
      );
    });
    return response as Map<String, dynamic>;
  }

  Future<dynamic> get(String endpoint) async {
    // ✅ FIX: Move header generation INSIDE the closure
    return _request(() async {
      final headers = await _getSecureHeaders();
      return http.get(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
      );
    });
  }

  // ✅ DELETE METHOD
  Future<dynamic> delete(String endpoint) async {
    // ✅ FIX: Move header generation INSIDE the closure
    return _request(() async {
      final headers = await _getSecureHeaders();
      return http.delete(
        Uri.parse('${AppConfig.baseUrl}$endpoint'),
        headers: headers,
      );
    });
  }

  Future<dynamic> _request(Future<http.Response> Function() req) async {
    try {
      var response = await req().timeout(_timeoutDuration);

      // ✅ CRITICAL FIX: Handle Race Condition for 401
      if (response.statusCode == 401 && onTokenRefresh != null) {
        print("🔄 401 Detected. Attempting Refresh...");

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
            
            // ✅ FIX: Check if already completed before completing to avoid "Bad state"
            if (!(_refreshCompleter?.isCompleted ?? true)) {
              _refreshCompleter?.complete(newToken);
            }
          } catch (e) {
            if (!(_refreshCompleter?.isCompleted ?? true)) {
              _refreshCompleter?.complete(null);
            }
          } finally {
            _isRefreshing = false;
            _refreshCompleter = null;
          }
        }

        // If we got a valid token (either from our refresh or the waiting one), retry
        if (newToken != null) {
          print("✅ Token Refreshed. Retrying Request...");
          // This call to req() will now re-execute _getSecureHeaders() and use the NEW token
          response = await req().timeout(_timeoutDuration); 
        }
      }

      return _processResponse(response);
    } on TimeoutException {
      throw ApiException('Server is taking too long to respond. Please check your connection.', statusCode: 408);
    } on SocketException {
      throw ApiException('No internet connection. Please try again later.', statusCode: 0);
    } on ApiException {
      rethrow; // Pass through already typed exceptions
    } catch (e) {
      throw ApiException('Connection error: $e');
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (e) {
      body = {}; 
    }
    
    // ✅ FIX: Only treat 200-299 as success. 
    // If you need to handle 404 specifically for login, handle it in the Login ViewModel, not here.
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {
        'success': true,
        'statusCode': response.statusCode,
        'data': body
      };
    } else {
      // ✅ Throw exception for 404 so the UI catches it instead of trying to parse bad data
      final errorMessage = (body is Map && body['message'] != null) 
          ? body['message'] 
          : 'Request failed with status ${response.statusCode}';
      
      throw ApiException(errorMessage, statusCode: response.statusCode);
    }
  }
}