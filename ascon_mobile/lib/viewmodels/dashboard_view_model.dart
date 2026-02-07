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
  List<dynamic> topAlumni = []; 

  String profileImage = "";
  String programme = "Member";
  String year = "....";
  String alumniID = "PENDING";
  String firstName = "Alumni"; // For personalized greeting
  
  // ✅ NEW: Error State for UI Feedback
  String? errorMessage;

  // ✅ UPDATED: Now populated directly from API
  double profileCompletionPercent = 0.0;
  bool isProfileComplete = false;
  
  bool isLoading = true;

  /// Loads all necessary data for the dashboard
  Future<void> loadData() async {
    isLoading = true;
    errorMessage = null; // ✅ Reset error state
    notifyListeners(); 

    try {
      // 1. Load Local Data First
      final prefs = await SharedPreferences.getInstance();
      alumniID = prefs.getString('alumni_id') ?? "PENDING";

      // ✅ FIX: Get Current User ID to filter self out
      final String? myId = await _authService.currentUserId;

      // 2. Fetch API Data in Parallel (Events, Programmes, Profile, Directory)
      final results = await Future.wait([
        _dataService.fetchEvents(),                  // Index 0
        _authService.getProgrammes(),                // Index 1
        _dataService.fetchProfile(),                 // Index 2
        _dataService.fetchDirectory(query: ""),      // Index 3
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
        
        String fullName = profile['fullName'] ?? "Alumni";
        firstName = fullName.split(" ")[0];

        String? apiId = profile['alumniId'];
        if (apiId != null && apiId.isNotEmpty && apiId != "PENDING") {
          alumniID = apiId;
          await prefs.setString('alumni_id', apiId);
        }

        // ✅ IMPROVEMENT: Use Backend calculation
        if (profile.containsKey('profileCompletionPercent')) {
          profileCompletionPercent = (profile['profileCompletionPercent'] as num).toDouble();
          isProfileComplete = profile['isProfileComplete'] ?? false;
        } else {
          // Fallback if backend isn't updated yet (Graceful degradation)
          profileCompletionPercent = 0.0; 
          isProfileComplete = false;
        }
      }

      // 6. Process Alumni Network (Randomized) ✅
      var fetchedAlumni = List.from(results[3] as List);

      // ✅ FIX: Remove Self from Home Screen Suggestions
      if (myId != null) {
        fetchedAlumni.removeWhere((user) {
          final id = user['_id'] ?? user['userId'];
          return id.toString() == myId;
        });
      }
      
      // ✅ RANDOMIZE SUGGESTIONS AT EVERY LOGIN
      fetchedAlumni.shuffle(); 
      
      // Take top 8 for a fuller horizontal list
      topAlumni = fetchedAlumni.take(8).toList(); 

    } catch (e) {
      debugPrint("⚠️ Error loading dashboard data: $e");
      // ✅ NEW: Store readable error message for the UI
      errorMessage = "Could not load data. Please check your connection.";
    } finally {
      isLoading = false;
      notifyListeners(); 
    }
  }
}