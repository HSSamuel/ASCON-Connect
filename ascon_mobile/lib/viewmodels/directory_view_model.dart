import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';
import '../services/data_service.dart';
import '../services/socket_service.dart';

class DirectoryViewModel extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final DataService _dataService = DataService();
  
  // --- DIRECTORY STATE ---
  List<dynamic> allAlumni = [];
  List<dynamic> searchResults = [];
  Map<String, List<dynamic>> groupedAlumni = {};
  List<dynamic> recommendedAlumni = [];
  
  bool isLoadingDirectory = false;
  bool isSearching = false;
  bool showMentorsOnly = false;
  bool hasRecommendations = false;
  bool shouldShowPopup = false;

  // --- SMART MATCH STATE ---
  List<dynamic> smartMatches = [];
  bool isLoadingMatches = false;

  // --- NEAR ME STATE ---
  List<dynamic> nearbyAlumni = [];
  bool isLoadingNearMe = false;
  String? currentNearMeLocation;
  String nearMeFilter = "";

  StreamSubscription? _statusSubscription;

  void init() {
    loadDirectory();
    loadRecommendations();
    loadSmartMatches();
    loadNearMe();
    _listenToSocket();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  // ==========================
  // 1. DIRECTORY LOGIC
  // ==========================
  Future<void> loadDirectory({String query = ""}) async {
    isLoadingDirectory = true;
    notifyListeners();

    try {
      String endpoint = '/api/directory?search=$query';
      if (showMentorsOnly) endpoint += '&mentorship=true';

      final response = await _api.get(endpoint);

      if (response['success'] == true) {
        final dynamic rawData = response['data'];
        List<dynamic> list = [];

        if (rawData is List) {
          list = rawData;
        } else if (rawData is Map && rawData['data'] is List) {
          list = rawData['data'];
        }

        allAlumni = list;
        searchResults = list;
        groupedAlumni = _groupUsersByYear(list);
      }
    } catch (e) {
      debugPrint("Directory Load Error: $e");
    } finally {
      isLoadingDirectory = false;
      notifyListeners();
    }
  }

  void onSearchChanged(String query) {
    isSearching = query.isNotEmpty;
    
    if (query.isEmpty) {
      searchResults = allAlumni;
    } else {
      final lowerQuery = query.toLowerCase();
      searchResults = allAlumni.where((user) {
        final name = (user['fullName'] ?? '').toString().toLowerCase();
        final org = (user['organization'] ?? '').toString().toLowerCase();
        final year = (user['yearOfAttendance'] ?? '').toString().toLowerCase();
        final job = (user['jobTitle'] ?? '').toString().toLowerCase();
        return name.contains(lowerQuery) || org.contains(lowerQuery) || year.contains(lowerQuery) || job.contains(lowerQuery);
      }).toList();
    }
    notifyListeners();
  }

  void toggleMentorsOnly(bool value, String currentSearch) {
    showMentorsOnly = value;
    loadDirectory(query: currentSearch);
  }

  Future<void> loadRecommendations() async {
    try {
      final result = await _dataService.fetchRecommendations();
      if (result['success'] == true) {
        recommendedAlumni = result['matches'] ?? [];
        hasRecommendations = recommendedAlumni.isNotEmpty;
        
        if (hasRecommendations) {
          final prefs = await SharedPreferences.getInstance();
          final lastShown = prefs.getInt('last_recommendation_popup_time') ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;
          // Check if 24 hours passed
          if (now - lastShown > 86400000) {
            shouldShowPopup = true;
            prefs.setInt('last_recommendation_popup_time', now);
          }
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  // ==========================
  // 2. SMART MATCH LOGIC
  // ==========================
  Future<void> loadSmartMatches() async {
    isLoadingMatches = true;
    notifyListeners();
    try {
      smartMatches = await _dataService.fetchSmartMatches();
    } catch (_) {
    } finally {
      isLoadingMatches = false;
      notifyListeners();
    }
  }

  // ==========================
  // 3. NEAR ME LOGIC
  // ==========================
  Future<void> loadNearMe({String? city}) async {
    isLoadingNearMe = true;
    currentNearMeLocation = city;
    notifyListeners();
    
    try {
      nearbyAlumni = await _dataService.fetchAlumniNearMe(city: city);
    } catch (_) {
    } finally {
      isLoadingNearMe = false;
      notifyListeners();
    }
  }

  void setNearMeFilter(String val) {
    nearMeFilter = val;
    notifyListeners();
  }

  List<dynamic> get filteredNearbyAlumni {
    if (nearMeFilter.isEmpty) return nearbyAlumni;
    return nearbyAlumni.where((user) {
      final name = (user['fullName'] ?? '').toLowerCase();
      final job = (user['jobTitle'] ?? '').toLowerCase();
      return name.contains(nearMeFilter.toLowerCase()) || job.contains(nearMeFilter.toLowerCase());
    }).toList();
  }

  // ==========================
  // HELPER METHODS
  // ==========================
  Map<String, List<dynamic>> _groupUsersByYear(List<dynamic> users) {
    Map<String, List<dynamic>> groups = {};
    for (var user in users) {
      String year = user['yearOfAttendance']?.toString() ?? 'Others';
      if (!groups.containsKey(year)) groups[year] = [];
      groups[year]!.add(user);
    }
    var sortedKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (var key in sortedKeys) key: groups[key]!};
  }

  void _listenToSocket() {
    _statusSubscription = SocketService().userStatusStream.listen((data) {
      final userId = data['userId'];
      final isOnline = data['isOnline'];
      final lastSeen = data['lastSeen'];

      void updateList(List<dynamic> list) {
        for (var user in list) {
          if (user['_id'] == userId || user['userId'] == userId) {
            user['isOnline'] = isOnline;
            user['lastSeen'] = lastSeen;
          }
        }
      }

      updateList(allAlumni);
      updateList(searchResults);
      updateList(recommendedAlumni);
      updateList(smartMatches);
      updateList(nearbyAlumni);
      
      notifyListeners();
    });
  }
}