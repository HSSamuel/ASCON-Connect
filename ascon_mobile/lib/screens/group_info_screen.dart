import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; 
import '../services/data_service.dart';
import '../services/auth_service.dart';
import '../services/api_client.dart'; 
import 'alumni_detail_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupInfoScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final DataService _dataService = DataService();
  final ApiClient _api = ApiClient();
  final ImagePicker _picker = ImagePicker();
  
  Map<String, dynamic>? _groupData;
  List<dynamic> _allMembers = [];
  List<dynamic> _filteredMembers = [];
  List<dynamic> _admins = [];
  
  bool _isLoading = true;
  bool _isCurrentUserAdmin = false;
  String? _myUserId;
  
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadGroupInfo();
  }

 Future<void> _loadGroupInfo() async {
    _myUserId = await AuthService().currentUserId;
    final result = await _dataService.fetchGroupInfo(widget.groupId);
    
    if (mounted) {
      // 1. Get the raw list
      List<dynamic> members = List.from(result?['members'] ?? []);

      // 2. ✅ SORT: Admins first, then Alphabetical by Name
      members.sort((a, b) {
        final bool isAdminA = a['isAdmin'] ?? false;
        final bool isAdminB = b['isAdmin'] ?? false;

        // If A is admin and B is not, A comes first
        if (isAdminA && !isAdminB) return -1;
        
        // If B is admin and A is not, B comes first
        if (!isAdminA && isAdminB) return 1;

        // If both have same status, sort alphabetically
        return (a['fullName'] ?? "").toString().compareTo(b['fullName'] ?? "");
      });

      setState(() {
        _groupData = result;
        _allMembers = members;
        _filteredMembers = members; // Filtered list inherits the sort order
        _admins = result?['admins'] ?? [];
        _isCurrentUserAdmin = result?['isCurrentUserAdmin'] ?? false;
        _isLoading = false;
      });
    }
  }

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

  Future<void> _handleGroupIconOptions() async {
    showModalBottomSheet(
      context: context, 
      builder: (ctx) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text("Choose from Gallery"),
            onTap: () { Navigator.pop(ctx); _pickAndUploadIcon(); }
          ),
          if (_groupData?['icon'] != null && _groupData!['icon'] != "")
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Remove Icon (Revert to Default)", style: TextStyle(color: Colors.red)),
              onTap: () { Navigator.pop(ctx); _revertIcon(); }
            ),
        ],
      )
    );
  }

  Future<void> _pickAndUploadIcon() async {
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

  Future<void> _revertIcon() async {
    setState(() => _isLoading = true);
    final success = await _dataService.removeGroupIcon(widget.groupId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Icon removed.")));
      _loadGroupInfo();
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to remove icon.")));
    }
  }

  // --- NOTICE BOARD LOGIC ---
  void _openNoticeBoard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("📢 Notice Board", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    if (_isCurrentUserAdmin)
                      TextButton.icon(onPressed: () => _postOrEditNotice(context, null), icon: const Icon(Icons.add, size: 18), label: const Text("Post"))
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder(
                  future: _api.get('/api/groups/${widget.groupId}/notices'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text("Failed to load notices"));
                    }
                    
                    // ✅ FIXED: Safe parsing that handles Map vs List
                    List<dynamic> notices = [];
                    try {
                      final wrapper = snapshot.data;
                      if (wrapper is Map) {
                        final body = wrapper['data']; // The server response body
                        
                        if (body is Map && body.containsKey('data') && body['data'] is List) {
                          // Standard format: {success: true, data: [...]}
                          notices = body['data'];
                        } else if (body is List) {
                          // Direct list format: [...]
                          notices = body;
                        }
                      }
                    } catch (e) {
                      debugPrint("Parsing Error: $e");
                    }

                    if (notices.isEmpty) return const Center(child: Text("No notices yet."));

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: notices.length,
                      itemBuilder: (context, index) {
                        final notice = notices[index];
                        // ✅ Permissions Check
                        final bool isPoster = notice['postedBy'] != null && 
                            (notice['postedBy']['_id'] == _myUserId || notice['postedBy'] == _myUserId);
                        final bool canManage = _isCurrentUserAdmin || isPoster;

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          elevation: 0,
                          color: Colors.amber.withOpacity(0.05),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.amber.withOpacity(0.2))),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.push_pin, size: 16, color: Colors.amber),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(notice['title'] ?? "Notice", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                    
                                    // ✅ MENU: Edit/Delete
                                    if (canManage)
                                      PopupMenuButton<String>(
                                        onSelected: (val) {
                                          if (val == 'edit') _postOrEditNotice(context, notice);
                                          if (val == 'delete') _deleteNotice(notice['_id']);
                                        },
                                        itemBuilder: (c) => [
                                          const PopupMenuItem(value: 'edit', child: Text("Edit")),
                                          const PopupMenuItem(value: 'delete', child: Text("Delete", style: TextStyle(color: Colors.red))),
                                        ],
                                        child: const Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                      )
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(notice['content'] ?? "", style: TextStyle(color: Colors.grey[800])),
                                const SizedBox(height: 12),
                                Text("Posted on ${DateFormat('MMM d, y').format(DateTime.parse(notice['createdAt']))}", style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _postOrEditNotice(BuildContext parentContext, Map<String, dynamic>? existingNotice) {
    final isEditing = existingNotice != null;
    final titleCtrl = TextEditingController(text: isEditing ? existingNotice['title'] : "");
    final bodyCtrl = TextEditingController(text: isEditing ? existingNotice['content'] : "");
    
    showDialog(
      context: parentContext, 
      builder: (c) => AlertDialog(
        title: Text(isEditing ? "Edit Notice" : "Post Announcement"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Title", border: OutlineInputBorder())), const SizedBox(height: 10), TextField(controller: bodyCtrl, maxLines: 3, decoration: const InputDecoration(labelText: "Content", border: OutlineInputBorder()))]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
          ElevatedButton(onPressed: () async {
              if(titleCtrl.text.isEmpty || bodyCtrl.text.isEmpty) return;
              Navigator.pop(c);
              
              if (isEditing) {
                await _dataService.editGroupNotice(widget.groupId, existingNotice['_id'], titleCtrl.text, bodyCtrl.text);
              } else {
                await _api.post('/api/groups/${widget.groupId}/notices', {'title': titleCtrl.text, 'content': bodyCtrl.text});
              }
              
              if (mounted) {
                Navigator.pop(parentContext); // Close list to refresh
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? "Notice Updated" : "Notice Posted")));
                _openNoticeBoard(); // Reopen
              }
            }, child: Text(isEditing ? "Save" : "Post")),
        ],
      )
    );
  }

  Future<void> _deleteNotice(String noticeId) async {
    Navigator.pop(context); // Close list
    final success = await _dataService.deleteGroupNotice(widget.groupId, noticeId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notice deleted.")));
      _openNoticeBoard(); 
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

  Future<void> _viewProfile(String userId) async {
    showDialog(context: context, builder: (c) => const Center(child: CircularProgressIndicator()));
    final fullProfile = await _dataService.fetchAlumniById(userId);
    Navigator.pop(context);
    if (fullProfile != null && mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AlumniDetailScreen(alumniData: fullProfile)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? iconUrl = _groupData?['icon'];
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 320,
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (iconUrl != null && iconUrl.isNotEmpty)
                            CachedNetworkImage(imageUrl: iconUrl, fit: BoxFit.cover)
                          else
                            Container(color: Colors.teal.shade100, child: const Icon(Icons.groups, size: 80, color: Colors.teal)),
                          
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.8)],
                              ),
                            ),
                          ),
                          
                          Positioned(
                            bottom: 20, left: 20, right: 80,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.groupName, style: GoogleFonts.lato(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text("${_allMembers.length} Members • Group", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                              ],
                            ),
                          ),

                          if (_isCurrentUserAdmin)
                            Positioned(
                              bottom: 20, right: 20,
                              child: GestureDetector(
                                onTap: _handleGroupIconOptions,
                                child: CircleAvatar(backgroundColor: Colors.white, radius: 24, child: Icon(Icons.camera_alt, color: primaryColor)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionBtn(Icons.call, "Voice", () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Voice Call..."))), Colors.green),
                          _buildActionBtn(Icons.campaign, "Notices", _openNoticeBoard, Colors.orange),
                          _buildActionBtn(Icons.description, "Docs", () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Docs (Coming Soon)"))), Colors.blue),
                        ],
                      ),
                    ),
                  ),

                  // 3. CLAIM ADMIN RIGHTS
                  if (_admins.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber)),
                        child: Column(
                          children: [
                            const Text("This group has no admin.", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => _toggleAdmin(_myUserId!, "Yourself"), 
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800], foregroundColor: Colors.white),
                              child: const Text("Claim Admin Rights"),
                            ),
                          ],
                        ),
                      ),
                    ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterMembers,
                        decoration: InputDecoration(
                          hintText: "Search members...",
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Text("Participants (${_filteredMembers.length})", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                    ),
                  ),

                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final m = _filteredMembers[index];
                        final bool isAdmin = m['isAdmin'] ?? false;
                        final bool isMe = m['_id'] == _myUserId;

                        return ListTile(
                          onTap: () => _viewProfile(m['_id']),
                          leading: CircleAvatar(
                            backgroundImage: (m['profilePicture'] != null && m['profilePicture'] != "") ? CachedNetworkImageProvider(m['profilePicture']) : null,
                            child: (m['profilePicture'] == null || m['profilePicture'] == "") ? const Icon(Icons.person) : null,
                          ),
                          title: Text(isMe ? "You" : m['fullName'], style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(m['jobTitle'] ?? "Member"),
                          trailing: isAdmin 
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.green)),
                                child: const Text("Admin", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                              )
                            : null,
                          onLongPress: (_isCurrentUserAdmin && !isMe) ? () {
                             showModalBottomSheet(context: context, builder: (c) => Wrap(children: [
                               ListTile(leading: const Icon(Icons.shield), title: Text(isAdmin ? "Dismiss as Admin" : "Make Group Admin"), onTap: () { Navigator.pop(c); _toggleAdmin(m['_id'], m['fullName']); }),
                               ListTile(leading: const Icon(Icons.person_remove, color: Colors.red), title: const Text("Remove from Group", style: TextStyle(color: Colors.red)), onTap: () { Navigator.pop(c); _removeMember(m['_id']); }),
                             ]));
                          } : null,
                        );
                      },
                      childCount: _filteredMembers.length,
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),

              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildActionBtn(IconData icon, String label, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
        child: Column(children: [Icon(icon, color: color, size: 28), const SizedBox(height: 8), Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600))]),
      ),
    );
  }
}