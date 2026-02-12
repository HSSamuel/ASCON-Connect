import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CallHistoryService {
  static const String _storageKey = 'local_call_logs_v2'; // Version bumped

  // Singleton
  static final CallHistoryService _instance = CallHistoryService._internal();
  factory CallHistoryService() => _instance;
  CallHistoryService._internal();

  /// Save a call log locally
  Future<void> logCall({
    required String userId,
    required String userName,
    String? callerPic,
    required String type, // 'dialed', 'received', 'missed'
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> logs = prefs.getStringList(_storageKey) ?? [];

      final newLog = {
        'id': DateTime.now().microsecondsSinceEpoch.toString(), // Unique ID
        'callerId': userId,
        'callerName': userName,
        'callerPic': callerPic ?? "",
        'type': type,
        'createdAt': DateTime.now().toIso8601String(),
        'isLocal': true, 
      };

      // Insert at the beginning (Newest first)
      logs.insert(0, jsonEncode(newLog));

      // Keep only last 100 logs
      if (logs.length > 100) {
        logs = logs.sublist(0, 100);
      }

      await prefs.setStringList(_storageKey, logs);
    } catch (e) {
      print("Error logging call locally: $e");
    }
  }

  /// Retrieve local logs
  Future<List<Map<String, dynamic>>> getLocalLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> rawLogs = prefs.getStringList(_storageKey) ?? [];
      
      return rawLogs.map((log) {
        return Map<String, dynamic>.from(jsonDecode(log));
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Delete specific logs by ID
  Future<void> deleteLogs(List<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> rawLogs = prefs.getStringList(_storageKey) ?? [];
      
      rawLogs.removeWhere((logString) {
        final log = jsonDecode(logString);
        return ids.contains(log['id']);
      });

      await prefs.setStringList(_storageKey, rawLogs);
    } catch (e) {
      print("Error deleting local logs: $e");
    }
  }

  /// Clear all local history
  Future<void> clearLocalLogs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}