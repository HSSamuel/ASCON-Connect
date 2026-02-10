import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart'; // Import to check ApiException

// ✅ 1. IMMUTABLE STATE CLASS
class DashboardState {
  final bool isLoading;
  final String? errorMessage;
  final List<dynamic> events;
  final List<dynamic> programmes;
  final List<dynamic> topAlumni;
  final String profileImage;
  final String programme;
  final String year;
  final String alumniID;
  final String firstName;
  final double profileCompletionPercent;
  final bool isProfileComplete;

  const DashboardState({
    this.isLoading = true,
    this.errorMessage,
    this.events = const [],
    this.programmes = const [],
    this.topAlumni = const [],
    this.profileImage = "",
    this.programme = "Member",
    this.year = "....",
    this.alumniID = "PENDING",
    this.firstName = "Alumni",
    this.profileCompletionPercent = 0.0,
    this.isProfileComplete = false,
  });

  DashboardState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<dynamic>? events,
    List<dynamic>? programmes,
    List<dynamic>? topAlumni,
    String? profileImage,
    String? programme,
    String? year,
    String? alumniID,
    String? firstName,
    double? profileCompletionPercent,
    bool? isProfileComplete,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage, // Note: Passing null here WILL clear the error if you pass it explicitly
      events: events ?? this.events,
      programmes: programmes ?? this.programmes,
      topAlumni: topAlumni ?? this.topAlumni,
      profileImage: profileImage ?? this.profileImage,
      programme: programme ?? this.programme,
      year: year ?? this.year,
      alumniID: alumniID ?? this.alumniID,
      firstName: firstName ?? this.firstName,
      profileCompletionPercent: profileCompletionPercent ?? this.profileCompletionPercent,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
    );
  }
}

// ✅ 2. STATE NOTIFIER (Logic Layer)
class DashboardNotifier extends StateNotifier<DashboardState> {
  final DataService _dataService = DataService();
  final AuthService _authService = AuthService();

  DashboardNotifier() : super(const DashboardState());

  /// Loads all necessary data for the dashboard
  Future<void> loadData({bool isRefresh = false}) async {
    // If it's a pull-to-refresh, don't show full loading screen, just update state quietly
    if (!isRefresh) state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // 1. Load Local Data First
      final prefs = await SharedPreferences.getInstance();
      String localAlumniID = prefs.getString('alumni_id') ?? "PENDING";

      // Get Current User ID to filter self out
      final String? myId = await _authService.currentUserId;

      // 2. Fetch API Data in Parallel
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

      // 4. Process Programmes (Sort Newest First)
      var fetchedProgrammes = List.from(results[1] as List);
      fetchedProgrammes.sort((a, b) {
        final idA = a['_id'] ?? a['id'] ?? '';
        final idB = b['_id'] ?? b['id'] ?? '';
        return idB.toString().compareTo(idA.toString());
      });

      // 5. Process Profile Data
      String profileImage = "";
      String programme = "Member";
      String year = "....";
      String firstName = "Alumni";
      String alumniID = localAlumniID;
      double profileCompletionPercent = 0.0;
      bool isProfileComplete = false;

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

        if (profile.containsKey('profileCompletionPercent')) {
          profileCompletionPercent = (profile['profileCompletionPercent'] as num).toDouble();
          isProfileComplete = profile['isProfileComplete'] ?? false;
        }
      }

      // 6. Process Alumni Network (Randomized)
      var fetchedAlumni = List.from(results[3] as List);

      if (myId != null) {
        fetchedAlumni.removeWhere((user) {
          final id = user['_id'] ?? user['userId'];
          return id.toString() == myId;
        });
      }
      
      fetchedAlumni.shuffle(); 
      final topAlumni = fetchedAlumni.take(8).toList(); 

      // ✅ UPDATE STATE SUCCESS
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: null, // Clear any previous error
          events: fetchedEvents,
          programmes: fetchedProgrammes,
          topAlumni: topAlumni,
          profileImage: profileImage,
          programme: programme,
          year: year,
          alumniID: alumniID,
          firstName: firstName,
          profileCompletionPercent: profileCompletionPercent,
          isProfileComplete: isProfileComplete,
        );
      }

    } catch (e) {
      debugPrint("⚠️ Error loading dashboard data: $e");
      
      // ✅ IMPROVED ERROR MESSAGES
      String readableError = "Something went wrong. Please try again.";
      
      if (e is ApiException) {
        if (e.statusCode == 0) {
          readableError = "No internet connection. Please check your network.";
        } else if (e.statusCode == 500) {
          readableError = "Server error. We're working on it.";
        } else {
          readableError = e.message;
        }
      } else if (e.toString().contains("SocketException")) {
        readableError = "Network error. Please check your connection.";
      }

      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: readableError,
        );
      }
    }
  }
}

// ✅ 3. PROVIDER DEFINITION
final dashboardProvider = StateNotifierProvider.autoDispose<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});