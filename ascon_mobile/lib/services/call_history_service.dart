import 'api_client.dart';

class CallHistoryService {
  // Singleton Pattern
  static final CallHistoryService _instance = CallHistoryService._internal();
  factory CallHistoryService() => _instance;
  CallHistoryService._internal();

  final ApiClient _api = ApiClient();

  /// Fetch synchronized call logs from the Server
  /// Returns a list of maps containing call details.
  Future<List<dynamic>> getLogs() async {
    try {
      final res = await _api.get('/api/calls');
      
      if (res['success'] == true && res['data'] is List) {
        return res['data'];
      }
      return [];
    } catch (e) {
      // Return empty list on failure to prevent UI crash
      return [];
    }
  }

  /// Delete a specific call log by ID from the Server
  Future<void> deleteLog(String id) async {
    try {
      await _api.delete('/api/calls/$id');
    } catch (e) {
      // Fail silently or handle error as needed
      print("Error deleting log: $e");
    }
  }
}