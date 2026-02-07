import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';
import 'alumni_detail_screen.dart'; // ✅ Import Detail Screen

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupInfoScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final DataService _dataService = DataService();
  final ImagePicker _picker = ImagePicker();
  
  Map<String, dynamic>? _groupData;
  List<dynamic> _allMembers = [];
  List<dynamic> _filteredMembers = []; // ✅ For Search
  bool _isLoading = true;
  bool _isCurrentUserAdmin = false;
  String? _myUserId;
  
  // ✅ Search State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
  }

  Future<void> _loadGroupInfo() async {
    _myUserId = await AuthService().currentUserId;
    final result = await _dataService.fetchGroupInfo(widget.groupId);
    if (mounted) {
      setState(() {
        _groupData = result;
        _allMembers = result?['members'] ?? [];
        _filteredMembers = _allMembers; // Init filter
        _isCurrentUserAdmin = result?['isCurrentUserAdmin'] ?? false;
        _isLoading = false;
      });
    }
  }

  // ✅ 4. SEARCH FUNCTIONALITY
  void _filterMembers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = _allMembers;
      } else {
        _filteredMembers = _allMembers.where((m) {
          final name = (m['fullName'] ?? "").toString().toLowerCase();
          final job = (m['jobTitle'] ?? "").toString().toLowerCase();
          return name.contains(query.toLowerCase()) || job.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  // ✅ 5. ADMIN CHANGE ICON
  Future<void> _changeGroupIcon() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _isLoading = true);
      final success = await _dataService.updateGroupIcon(widget.groupId, image);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group Icon Updated!")));
        _loadGroupInfo();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update icon.")));
      }
    }
  }

  Future<void> _toggleAdmin(String userId, String name) async {
    await _dataService.toggleGroupAdmin(widget.groupId, userId);
    _loadGroupInfo(); 
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Role updated for $name")));
  }

  Future<void> _removeMember(String userId) async {
    await _dataService.removeGroupMember(widget.groupId, userId);
    _loadGroupInfo();
  }

  // ✅ 3. ALUMNI PROFILE POPUP
  Future<void> _viewProfile(String userId) async {
    // Show loading indicator
    showDialog(context: context, builder: (c) => const Center(child: CircularProgressIndicator()));
    
    // Fetch full details
    final fullProfile = await _dataService.fetchAlumniById(userId);
    Navigator.pop(context); // Close loader

    if (fullProfile != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniData: fullProfile)));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not load profile.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final String? iconUrl = _groupData?['icon'];

    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Search members, job titles...",
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none
              ),
              onChanged: _filterMembers,
            )
          : const Text("Group Info"),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filteredMembers = _allMembers;
                }
              });
            },
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _groupData == null 
            ? const Center(child: Text("Could not load info"))
            : SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    
                    // 1. Header with Edit Icon
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.teal.shade100,
                          backgroundImage: (iconUrl != null && iconUrl.isNotEmpty) 
                              ? CachedNetworkImageProvider(iconUrl) 
                              : null,
                          child: (iconUrl == null || iconUrl.isEmpty) 
                              ? const Icon(Icons.groups, size: 50, color: Colors.teal) 
                              : null,
                        ),
                        if (_isCurrentUserAdmin)
                          Positioned(
                            bottom: 0, right: 0,
                            child: GestureDetector(
                              onTap: _changeGroupIcon,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                              ),
                            ),
                          )
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(widget.groupName, style: GoogleFonts.lato(fontSize: 22, fontWeight: FontWeight.bold)),
                    Text("${_allMembers.length} Members", style: const TextStyle(color: Colors.grey)),
                    
                    const SizedBox(height: 20),
                    
                    // 2. Actions (Removed Exit Button)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionBtn(Icons.call, "Voice Call", () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Starting Group Call...")));
                        }),
                        _buildActionBtn(Icons.video_call, "Video", () {
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Starting Video Call...")));
                        }),
                        _buildActionBtn(Icons.file_present, "Docs", () {
                           // Future: Open Media Gallery
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Media & Docs (Coming Soon)")));
                        }),
                      ],
                    ),
                    const Divider(height: 40),

                    // 3. Members List with Admin Badge
                    Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text("Participants (${_filteredMembers.length})", style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ),
                    
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final m = _filteredMembers[index];
                        final bool isAdmin = m['isAdmin'] ?? false;
                        final bool isMe = m['_id'] == _myUserId;

                        return ListTile(
                          onTap: () => _viewProfile(m['_id']), // ✅ CLICK TO PROFILE
                          leading: CircleAvatar(
                            backgroundImage: (m['profilePicture'] != null && m['profilePicture'] != "") 
                              ? CachedNetworkImageProvider(m['profilePicture'])
                              : null,
                            child: (m['profilePicture'] == null || m['profilePicture'] == "") 
                              ? const Icon(Icons.person) : null,
                          ),
                          title: Text(isMe ? "You" : m['fullName'], style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(m['jobTitle'] ?? "Member"),
                          
                          // ✅ 2. ADMIN INDICATION
                          trailing: isAdmin 
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1), 
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.green.withOpacity(0.5))
                                ),
                                child: const Text("Group Admin", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                              )
                            : null,
                            
                          onLongPress: (_isCurrentUserAdmin && !isMe) ? () {
                             showModalBottomSheet(context: context, builder: (c) => Wrap(
                               children: [
                                 ListTile(
                                   leading: const Icon(Icons.shield),
                                   title: Text(isAdmin ? "Dismiss as Admin" : "Make Group Admin"),
                                   onTap: () { Navigator.pop(c); _toggleAdmin(m['_id'], m['fullName']); }
                                 ),
                                 ListTile(
                                   leading: const Icon(Icons.person_remove, color: Colors.red),
                                   title: const Text("Remove from Group", style: TextStyle(color: Colors.red)),
                                   onTap: () { Navigator.pop(c); _removeMember(m['_id']); }
                                 ),
                               ],
                             ));
                          } : null,
                        );
                      },
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, VoidCallback onTap, {Color color = Colors.teal}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1))
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))
          ],
        ),
      ),
    );
  }
}