import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';

class EventsViewModel extends ChangeNotifier {
  final DataService _dataService = DataService();
  final ApiClient _api = ApiClient();
  final AuthService _authService = AuthService();

  List<dynamic> events = [];
  bool isLoading = true;
  bool isAdmin = false;
  
  // State for Create Event Sheet
  bool isPosting = false;

  void init() {
    checkAdmin();
    loadEvents();
  }

  Future<void> checkAdmin() async {
    isAdmin = await _authService.isAdmin;
    notifyListeners();
  }

  Future<void> loadEvents() async {
    isLoading = true;
    notifyListeners();
    try {
      events = await _dataService.fetchEvents();
    } catch (_) {
      // Handle error silently or expose error string
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    isLoading = true;
    notifyListeners();
    try {
      await _api.delete('/api/events/$eventId');
      await loadEvents(); // Reload list
      return true;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> createEvent({
    required String title,
    required String description,
    required String location,
    required String time,
    required String type,
    required DateTime date,
    XFile? image,
  }) async {
    isPosting = true;
    notifyListeners();

    try {
      final token = await _authService.getToken();
      var request = http.MultipartRequest(
          'POST', Uri.parse('${AppConfig.baseUrl}/api/events'));
      request.headers['auth-token'] = token ?? '';

      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['location'] = location;
      request.fields['time'] = time;
      request.fields['type'] = type;
      request.fields['date'] = date.toIso8601String();

      if (image != null) {
        if (kIsWeb) {
          var bytes = await image.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
              'image', bytes,
              filename: image.name));
        } else {
          request.files.add(await http.MultipartFile.fromPath(
              'image', image.path));
        }
      }

      var response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        await loadEvents(); // Refresh list on success
        return null; // Success (no error message)
      } else {
        final errorJson = jsonDecode(respStr);
        return errorJson['message'] ?? "Upload failed";
      }
    } catch (e) {
      return "Connection Error";
    } finally {
      isPosting = false;
      notifyListeners();
    }
  }
}