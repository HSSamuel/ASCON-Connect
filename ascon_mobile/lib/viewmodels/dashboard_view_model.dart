// File: ascon_mobile/lib/viewmodels/dashboard_view_model.dart
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
  List<dynamic> topAlumni = []; // ✅ NEW: For the "First Widget"

  String profileImage = "";
  String programme = "Member";
  String year = "....";
  String alumniID = "PENDING";
  
  bool isLoading = true;

  /// Loads all necessary data for the dashboard
  Future<void> loadData() async {
    isLoading = true;
    notifyListeners(); 

    try {
      // 1. Load Local Data First
      final prefs = await SharedPreferences.getInstance();
      alumniID = prefs.getString('alumni_id') ?? "PENDING";

      // 2. Fetch API Data in Parallel (Events, Programmes, Profile, Directory)
      final results = await Future.wait([
        _dataService.fetchEvents(),                  // Index 0
        _authService.getProgrammes(),                // Index 1
        _dataService.fetchProfile(),                 // Index 2
        _dataService.fetchDirectory(query: ""),      // Index 3 ✅ Fetch Directory
      ]);

      // 3. Process Events (Sort Newest First)
      var fetchedEvents = List.from(results[0] as List);
      fetchedEvents.sort((a, b) {
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
        
        String? apiId = profile['alumniId'];
        if (apiId != null && apiId.isNotEmpty && apiId != "PENDING") {
          alumniID = apiId;
          await prefs.setString('alumni_id', apiId);
        }
      }

      // 6. Process Top 5 Alumni ✅
      var fetchedAlumni = List.from(results[3] as List);
      // Optional: Shuffle or sort by relevance if needed
      topAlumni = fetchedAlumni.take(5).toList(); 

    } catch (e) {
      debugPrint("⚠️ Error loading dashboard data: $e");
    } finally {
      isLoading = false;
      notifyListeners(); 
    }
  }
}