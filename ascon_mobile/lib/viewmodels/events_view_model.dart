import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';

// ✅ 1. IMMUTABLE STATE
class EventsState {
  final List<dynamic> events;
  final bool isLoading;
  final bool isPosting;
  final bool isAdmin;
  final String? errorMessage;

  const EventsState({
    this.events = const [],
    this.isLoading = true,
    this.isPosting = false,
    this.isAdmin = false,
    this.errorMessage,
  });

  EventsState copyWith({
    List<dynamic>? events,
    bool? isLoading,
    bool? isPosting,
    bool? isAdmin,
    String? errorMessage,
  }) {
    return EventsState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isPosting: isPosting ?? this.isPosting,
      isAdmin: isAdmin ?? this.isAdmin,
      errorMessage: errorMessage,
    );
  }
}

// ✅ 2. STATE NOTIFIER
class EventsNotifier extends StateNotifier<EventsState> {
  final DataService _dataService = DataService();
  final ApiClient _api = ApiClient();
  final AuthService _authService = AuthService();

  EventsNotifier() : super(const EventsState()) {
    init();
  }

  void init() {
    checkAdmin();
    loadEvents();
  }

  Future<void> checkAdmin() async {
    final bool adminStatus = await _authService.isAdmin;
    state = state.copyWith(isAdmin: adminStatus);
  }

  Future<void> loadEvents({bool silent = false}) async {
    if (!silent) state = state.copyWith(isLoading: true, errorMessage: null);
    
    try {
      final fetchedEvents = await _dataService.fetchEvents();
      // Reverse chronological sort if API doesn't guarantee it
      fetchedEvents.sort((a, b) {
        final da = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

      if (mounted) {
        state = state.copyWith(isLoading: false, events: fetchedEvents);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, errorMessage: "Could not load events.");
      }
    }
  }

  Future<bool> deleteEvent(String eventId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _api.delete('/api/events/$eventId');
      await loadEvents(silent: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: "Failed to delete event.");
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
    state = state.copyWith(isPosting: true);

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

      state = state.copyWith(isPosting: false);

      if (response.statusCode == 201) {
        await loadEvents(silent: true);
        return null; // Success
      } else {
        final errorJson = jsonDecode(respStr);
        return errorJson['message'] ?? "Upload failed";
      }
    } catch (e) {
      state = state.copyWith(isPosting: false);
      return "Connection Error: ${e.toString()}";
    }
  }
}

// ✅ 3. PROVIDER
final eventsProvider = StateNotifierProvider.autoDispose<EventsNotifier, EventsState>((ref) {
  return EventsNotifier();
});