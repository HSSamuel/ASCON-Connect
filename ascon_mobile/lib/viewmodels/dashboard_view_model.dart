import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final DataService _dataService = DataService();
  final AuthService _authService = AuthService();

  // State Variables
  List<dynamic> events = [];
  List<dynamic> programmes = [];
  
  String profileImage = "";
  String programme = "Member";
  String year = "....";
  String alumniID = "PENDING";
  
  bool isLoading = true;

  /// Loads all necessary data for the dashboard (Profile, Events, Programmes)
  Future<void> loadData() async {
    isLoading = true;
    // We don't notifyListeners here to avoid unnecessary rebuilds if the UI 
    // is already showing a loading state, but you can add it if needed.
    notifyListeners(); 

    try {
      // 1. Load Local Data First (for immediate feedback)
      final prefs = await SharedPreferences.getInstance();
      alumniID = prefs.getString('alumni_id') ?? "PENDING";

      // 2. Fetch API Data in Parallel for performance
      final results = await Future.wait([
        _dataService.fetchEvents(),
        _authService.getProgrammes(),
        _dataService.fetchProfile(),
      ]);

      // 3. Process Events (Sort Newest First)
      var fetchedEvents = List.from(results[0] as List);
      fetchedEvents.sort((a, b) {
        // Compare IDs to guess creation time (Higher ID = Newer)
        final idA = a['_id'] ?? a['id'] ?? '';
        final idB = b['_id'] ?? b['id'] ?? '';
        return idB.toString().compareTo(idA.toString());
      });
      events = fetchedEvents;

      // 4. Process Programmes (Sort Newest First)
      var fetchedProgrammes = List.from(results[1] as List);
      fetchedProgrammes.sort((a, b) {
        final idA = a['_id'] ?? a['id'] ?? '';
        final idB = b['_id'] ?? b['id'] ?? '';
        return idB.toString().compareTo(idA.toString());
      });
      programmes = fetchedProgrammes;

      // 5. Process Profile Data
      final profile = results[2] as Map<String, dynamic>?;
      if (profile != null) {
        profileImage = profile['profilePicture'] ?? "";
        programme = profile['programmeTitle'] ?? "Member";
        if (programme.isEmpty) programme = "Member";
        year = profile['yearOfAttendance']?.toString() ?? "....";
        
        // Update Alumni ID if available
        String? apiId = profile['alumniId'];
        if (apiId != null && apiId.isNotEmpty && apiId != "PENDING") {
          alumniID = apiId;
          await prefs.setString('alumni_id', apiId);
        }
      }

    } catch (e) {
      debugPrint("⚠️ Error loading dashboard data: $e");
    } finally {
      isLoading = false;
      notifyListeners(); // Update UI
    }
  }
}