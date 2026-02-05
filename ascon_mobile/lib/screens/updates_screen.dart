import 'dart:io';
import 'dart:async';
import 'dart:convert'; // ✅ FIXED: Added this import for jsonDecode
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';
import '../config.dart';
import 'programme_detail_screen.dart';

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  final ApiClient _api = ApiClient();
  final DataService _dataService = DataService();
  final AuthService _authService = AuthService();
  
  List<dynamic> _posts = [];
  List<dynamic> _filteredPosts = [];
  List<dynamic> _highlights = [];
  bool _isLoading = true;

  // Permissions
  bool _isAdmin = false;
  String? _currentUserId;

  // Search & Filter State
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  bool _showMediaOnly = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadData();
  }

  Future<void> _checkPermissions() async {
    final adminStatus = await _authService.isAdmin;
    final userId = await _authService.currentUserId;
    if (mounted) {
      setState(() {
        _isAdmin = adminStatus;
        _currentUserId = userId;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final feed = await _dataService.fetchUpdates();
      final programmes = await AuthService().getProgrammes();

      if (mounted) {
        setState(() {
          _posts = feed;
          _filteredPosts = feed;
          _highlights = programmes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // =========================================================
  // ✏️ EDIT POST
  // =========================================================
  Future<void> _editPost(String postId, String currentText) async {
    final editCtrl = TextEditingController(text: currentText);
    
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Update"),
        content: TextField(
          controller: editCtrl,
          maxLines: 5,
          minLines: 1,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, editCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white),
            child: const Text("Save"),
          ),
        ],
      ),
    );

    if (newText != null && newText.isNotEmpty && newText != currentText) {
      setState(() => _isLoading = true);
      try {
        final res = await _api.put('/api/updates/$postId', {'text': newText});
        if (res['success'] == true) {
          await _loadData(); // Reload to show changes
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post updated.")));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update post.")));
        }
      }
    }
  }

  // =========================================================
  // 🗑️ DELETE LOGIC (Posts & Programmes)
  // =========================================================
  Future<void> _deletePost(String postId) async {
    final confirm = await _showConfirmDialog("Delete Update", "Are you sure you want to delete this post?");
    if (confirm) {
      setState(() => _isLoading = true);
      try {
        final res = await _api.delete('/api/updates/$postId');
        if (res['success'] == true) {
          await _loadData();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Post deleted.")));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete post.")));
        }
      }
    }
  }

  Future<void> _deleteProgramme(String progId) async {
    final confirm = await _showConfirmDialog("Delete Programme", "Remove this programme from highlights?");
    if (confirm) {
      setState(() => _isLoading = true);
      try {
        final res = await _api.delete('/api/admin/programmes/$progId');
        if (res['success'] == true || res['message'] == 'Programme deleted.') {
          await _loadData();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Programme deleted.")));
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete programme.")));
        }
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String body) async {
    return await showDialog<bool>(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete")
          ),
        ],
      )
    ) ?? false;
  }

  // =========================================================
  // ➕ ADD PROGRAMME SHEET (With Image Upload)
  // =========================================================
  void _showAddProgrammeSheet() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final locationController = TextEditingController();
    final durationController = TextEditingController();
    final feeController = TextEditingController();
    XFile? selectedImage; 
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            
            // Image Picker Logic
            Future<void> pickImage() async {
              final picker = ImagePicker();
              final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
              if (picked != null) {
                setSheetState(() => selectedImage = picked);
              }
            }

            Future<void> submit() async {
              if (titleController.text.isEmpty || 
                  descController.text.isEmpty || 
                  locationController.text.isEmpty || 
                  durationController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields.")));
                return;
              }
              
              setSheetState(() => isSubmitting = true);
              try {
                final token = await AuthService().getToken();
                
                // ✅ Use MultipartRequest for File Upload
                var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/api/admin/programmes'));
                request.headers['auth-token'] = token ?? '';
                
                // Add Text Fields
                request.fields['title'] = titleController.text.trim();
                request.fields['description'] = descController.text.trim();
                request.fields['location'] = locationController.text.trim();
                request.fields['duration'] = durationController.text.trim();
                if (feeController.text.isNotEmpty) {
                  request.fields['fee'] = feeController.text.trim();
                }

                // Add File if selected
                if (selectedImage != null) {
                  if (kIsWeb) {
                    var bytes = await selectedImage!.readAsBytes();
                    request.files.add(http.MultipartFile.fromBytes('image', bytes, filename: selectedImage!.name));
                  } else {
                    request.files.add(await http.MultipartFile.fromPath('image', selectedImage!.path));
                  }
                }

                // Send
                var response = await request.send();
                
                if (response.statusCode == 201) {
                  Navigator.pop(sheetCtx);
                  _loadData();
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Programme Added!"), backgroundColor: Colors.green));
                } else {
                   // Read response string from stream
                   final respStr = await response.stream.bytesToString();
                   // Try parse message
                   String err = "Failed to add";
                   try { err = jsonDecode(respStr)['message']; } catch (_) {}
                   
                   ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
              } finally {
                if (mounted) setSheetState(() => isSubmitting = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
              child: SingleChildScrollView( 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Add Programme", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                        if (isSubmitting) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title (Required)", border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    TextField(controller: descController, maxLines: 2, decoration: const InputDecoration(labelText: "Description (Required)", border: OutlineInputBorder())),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: locationController, decoration: const InputDecoration(labelText: "Location", border: OutlineInputBorder()))),
                        const SizedBox(width: 10),
                        Expanded(child: TextField(controller: durationController, decoration: const InputDecoration(labelText: "Duration", border: OutlineInputBorder()))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: feeController, decoration: const InputDecoration(labelText: "Fee (Optional)", border: OutlineInputBorder())),
                    
                    const SizedBox(height: 16),
                    
                    // ✅ Image Picker UI
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[400]!),
                          image: selectedImage != null 
                            ? DecorationImage(
                                image: kIsWeb ? NetworkImage(selectedImage!.path) : FileImage(File(selectedImage!.path)) as ImageProvider,
                                fit: BoxFit.cover
                              )
                            : null
                        ),
                        child: selectedImage == null 
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_photo_alternate, size: 40, color: Colors.grey),
                                const SizedBox(height: 8),
                                Text("Tap to add Cover Image", style: GoogleFonts.lato(color: Colors.grey[600]))
                              ],
                            )
                          : Stack(
                              children: [
                                Positioned(
                                  right: 5, top: 5,
                                  child: GestureDetector(
                                    onTap: () => setSheetState(() => selectedImage = null),
                                    child: const CircleAvatar(backgroundColor: Colors.red, radius: 12, child: Icon(Icons.close, size: 16, color: Colors.white)),
                                  ),
                                )
                              ],
                            ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor, 
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14)
                        ),
                        child: const Text("Create Programme", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  // =========================================================
  // 🔎 FILTER & SEARCH LOGIC
  // =========================================================
  void _onSearchChanged(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredPosts = _posts;
      } else {
        _filteredPosts = _posts.where((post) {
          final text = (post['text'] ?? "").toString().toLowerCase();
          final author = (post['author']['fullName'] ?? "").toString().toLowerCase();
          return text.contains(query.toLowerCase()) || author.contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _toggleFilterMedia() {
    setState(() {
      _showMediaOnly = !_showMediaOnly;
      if (_showMediaOnly) {
        _filteredPosts = _posts.where((p) => p['mediaType'] == 'image').toList();
      } else {
        _filteredPosts = _posts;
      }
    });
  }

  // =========================================================
  // ❤️ INTERACTIONS
  // =========================================================
  Future<void> _toggleLike(int index, String postId) async {
    setState(() {
      _filteredPosts[index]['isLikedByMe'] = !_filteredPosts[index]['isLikedByMe'];
      if (_filteredPosts[index]['isLikedByMe']) {
        _filteredPosts[index]['likes'].add('dummy_id');
      } else {
        _filteredPosts[index]['likes'].removeLast();
      }
    });

    try {
      await _api.put('/api/updates/$postId/like', {});
    } catch (e) {
      // Revert if failed
    }
  }

  Future<void> _sharePost(Map<String, dynamic> post) async {
    final text = post['text'] ?? "Check out this update on ASCON Alumni!";
    final author = post['author']['fullName'] ?? "Alumni";
    await Share.share("$author posted:\n\n$text\n\n#ASCONAlumni");
  }

  // =========================================================
  // 💬 COMMENTS SHEET
  // =========================================================
  void _showCommentsSheet(String postId, int postIndex, Function(int) onCountUpdate) {
    final commentController = TextEditingController();
    
    // State lives here for the modal
    List<dynamic> comments = [];
    bool isLoading = true; // Initial load
    bool isPosting = false; // Sending status

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final textColor = isDark ? Colors.white : Colors.black87;
            final bubbleColor = isDark ? Colors.grey[800] : Colors.grey[100];

            // Helper to fetch fresh comments from server
            Future<void> loadComments() async {
              try {
                final res = await _api.get('/api/updates/$postId');
                if (context.mounted && res['success'] == true) {
                  // Ensure correct path to comments array
                  final postData = res['data']['data'];
                  final fetchedList = postData != null ? postData['comments'] : [];

                  setSheetState(() {
                    comments = List.from(fetchedList ?? []);
                    isLoading = false;
                  });
                }
              } catch (e) {
                if (context.mounted) setSheetState(() => isLoading = false);
              }
            }

            // Trigger load on first render
            if (isLoading && comments.isEmpty) {
              loadComments();
            }

            Future<void> postComment() async {
              if (commentController.text.trim().isEmpty) return;
              setSheetState(() => isPosting = true); 
              
              final text = commentController.text.trim();
              try {
                final res = await _api.post('/api/updates/$postId/comment', {'text': text});
                
                if (context.mounted && res['success'] == true) {
                  commentController.clear();
                  FocusScope.of(context).unfocus();
                  
                  // Reload list & update parent
                  await loadComments();
                  onCountUpdate(comments.length);
                }
              } catch (e) {
                // handle error
              } finally {
                if (context.mounted) setSheetState(() => isPosting = false);
              }
            }

            // DELETE COMMENT
            Future<void> deleteComment(String commentId) async {
              final confirm = await showDialog<bool>(
                context: context, 
                builder: (ctx) => AlertDialog(
                  title: const Text("Delete Comment"),
                  content: const Text("Are you sure?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                  ],
                )
              );

              if (confirm == true) {
                setSheetState(() => isLoading = true);
                try {
                  await _api.delete('/api/updates/$postId/comments/$commentId');
                  await loadComments();
                  onCountUpdate(comments.length);
                } catch (e) {
                  setSheetState(() => isLoading = false);
                }
              }
            }

            // EDIT COMMENT
            Future<void> editComment(String commentId, String oldText) async {
              final editCtrl = TextEditingController(text: oldText);
              final result = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Edit Comment"),
                  content: TextField(
                    controller: editCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, editCtrl.text.trim()),
                      child: const Text("Save"),
                    ),
                  ],
                ),
              );

              if (result != null && result.isNotEmpty && result != oldText) {
                setSheetState(() => isLoading = true);
                try {
                  await _api.put('/api/updates/$postId/comments/$commentId', {'text': result});
                  await loadComments();
                } catch (e) {
                  setSheetState(() => isLoading = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  children: [
                    Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    Text("Comments", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                    const Divider(),
                    
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : comments.isEmpty 
                              ? Center(child: Text("No comments yet.", style: GoogleFonts.lato(color: Colors.grey)))
                              : ListView.builder(
                                  itemCount: comments.length,
                                  padding: const EdgeInsets.all(16),
                                  itemBuilder: (context, index) {
                                    final c = comments[index];
                                    if (c == null) return const SizedBox.shrink();

                                    final authorName = c['author']?['fullName'] ?? "User";
                                    final authorImg = c['author']?['profilePicture'];
                                    final time = timeago.format(DateTime.tryParse(c['createdAt'] ?? "") ?? DateTime.now());
                                    
                                    // ✅ PERMISSION CHECK FOR COMMENTS
                                    final String commentUserId = (c['userId'] ?? '').toString();
                                    final String myId = (_currentUserId ?? '').toString();
                                    final bool isMyComment = (commentUserId.isNotEmpty && commentUserId == myId);
                                    final bool canDelete = isMyComment || _isAdmin;

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Colors.grey[200],
                                            backgroundImage: authorImg != null && authorImg.toString().startsWith('http') ? CachedNetworkImageProvider(authorImg) : null,
                                            child: authorImg == null ? const Icon(Icons.person, size: 16, color: Colors.grey) : null,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.circular(12)),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Text(authorName, style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                                                      Text(time, style: GoogleFonts.lato(fontSize: 10, color: Colors.grey)),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(c['text'] ?? "", style: GoogleFonts.lato(fontSize: 14, color: textColor)),
                                                ],
                                              ),
                                            ),
                                          ),
                                          // ✅ COMMENT MENU
                                          if (canDelete)
                                            PopupMenuButton<String>(
                                              icon: Icon(Icons.more_vert, size: 18, color: Colors.grey),
                                              onSelected: (val) {
                                                if (val == 'edit') editComment(c['_id'], c['text']);
                                                if (val == 'delete') deleteComment(c['_id']);
                                              },
                                              itemBuilder: (context) => [
                                                if (isMyComment)
                                                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit")])),
                                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
                                              ],
                                            )
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.2)))),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: commentController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                hintText: "Add a comment...",
                                hintStyle: GoogleFonts.lato(fontSize: 14, color: Colors.grey),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                filled: true,
                                fillColor: bubbleColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleAvatar(
                            backgroundColor: const Color(0xFFD4AF37),
                            radius: 22,
                            child: isPosting
                                ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : IconButton(icon: const Icon(Icons.send_rounded, size: 20, color: Colors.white), onPressed: postComment),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================
  // 📝 CREATE POST SHEET (User)
  // =========================================================
  void _showCreatePostSheet() {
    final TextEditingController textController = TextEditingController();
    XFile? selectedImage; 
    bool isPosting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> pickImage() async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
              if (pickedFile != null) {
                setSheetState(() => selectedImage = pickedFile);
              }
            }

            Future<void> submitPost() async {
              if (textController.text.trim().isEmpty && selectedImage == null) return;
              setSheetState(() => isPosting = true);

              try {
                final token = await AuthService().getToken();
                var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/api/updates'));
                request.headers['auth-token'] = token ?? '';
                request.fields['text'] = textController.text.trim();

                if (selectedImage != null) {
                  if (kIsWeb) {
                    var bytes = await selectedImage!.readAsBytes();
                    request.files.add(http.MultipartFile.fromBytes('media', bytes, filename: selectedImage!.name));
                  } else {
                    request.files.add(await http.MultipartFile.fromPath('media', selectedImage!.path));
                  }
                }

                var response = await request.send();
                if (response.statusCode == 201) {
                  Navigator.pop(sheetContext);
                  _loadData(); 
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Update posted! 🚀"), backgroundColor: Colors.green));
                  }
                }
              } catch (e) {
                // error
              } finally {
                if (mounted) setSheetState(() => isPosting = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("New Update", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                      isPosting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : TextButton(
                            onPressed: submitPost,
                            style: TextButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                            child: const Text("Post", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    maxLines: 5,
                    minLines: 2,
                    autofocus: true,
                    decoration: const InputDecoration(hintText: "Share news, achievements...", border: InputBorder.none),
                  ),
                  if (selectedImage != null)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb 
                              ? Image.network(selectedImage!.path, height: 150, width: double.infinity, fit: BoxFit.cover)
                              : Image.file(File(selectedImage!.path), height: 150, width: double.infinity, fit: BoxFit.cover),
                        ),
                        IconButton(
                          icon: const CircleAvatar(backgroundColor: Colors.black54, radius: 14, child: Icon(Icons.close, size: 16, color: Colors.white)),
                          onPressed: () => setSheetState(() => selectedImage = null),
                        ),
                      ],
                    ),
                  const Divider(height: 30),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.image_rounded, color: Colors.green)),
                    title: const Text("Add Photo"),
                    onTap: pickImage,
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================
  // 📱 MAIN BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go('/home');
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                backgroundColor: scaffoldBg,
                foregroundColor: isDark ? Colors.white : Colors.black,
                elevation: 0,
                centerTitle: false,
                floating: true,
                snap: true,
                title: _isSearching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: "Search updates...",
                          border: InputBorder.none,
                          hintStyle: GoogleFonts.lato(fontSize: 18),
                        ),
                        style: GoogleFonts.lato(fontSize: 18, color: isDark ? Colors.white : Colors.black),
                        onChanged: _onSearchChanged,
                      )
                    : Text("Updates", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 22, color: isDark ? Colors.white : Colors.black)),
                actions: [
                  IconButton(
                    icon: Icon(_isSearching ? Icons.close : Icons.search),
                    onPressed: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) {
                          _searchController.clear();
                          _filteredPosts = _posts;
                        }
                      });
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'refresh') _loadData();
                      if (val == 'filter') _toggleFilterMedia();
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'refresh', child: Row(children: [Icon(Icons.refresh, size: 20), SizedBox(width: 10), Text("Refresh")])),
                      PopupMenuItem(value: 'filter', child: Row(children: [Icon(_showMediaOnly ? Icons.check_box : Icons.check_box_outline_blank, size: 20), const SizedBox(width: 10), const Text("Media Only")])),
                    ],
                  ),
                ],
              ),
            ];
          },
          body: RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFFD4AF37),
            child: CustomScrollView(
              slivers: [
                if (_highlights.isNotEmpty && !_isSearching) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Highlights", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16)),
                          if (_isAdmin)
                            IconButton(
                              icon: const Icon(Icons.add_circle, color: Color(0xFFD4AF37)),
                              onPressed: _showAddProgrammeSheet,
                              tooltip: "Add Programme",
                            )
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 160,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _highlights.length,
                        itemBuilder: (context, index) => _buildStatusCard(_highlights[index]),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: Divider(height: 30, thickness: 0.5)),
                ],

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_isSearching ? "Search Results" : "Recent Updates", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16)),
                        if (_showMediaOnly)
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text("Media Only", style: TextStyle(fontSize: 12, color: primaryColor))),
                      ],
                    ),
                  ),
                ),

                if (_isLoading)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
                else if (_filteredPosts.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState())
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildPostCard(_filteredPosts[index], index),
                      childCount: _filteredPosts.length,
                    ),
                  ),
                  
                const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
              ],
            ),
          ),
        ),

        floatingActionButton: FloatingActionButton(
          onPressed: _showCreatePostSheet,
          backgroundColor: const Color(0xFFD4AF37),
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> item) {
    final title = item['title'] ?? "News";
    final image = item['image'] ?? item['imageUrl'];
    final id = item['_id'] ?? item['id'];
    
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProgrammeDetailScreen(programme: item)));
      },
      onLongPress: _isAdmin ? () => _deleteProgramme(id) : null,
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: image != null 
                      ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, width: double.infinity)
                      : Container(color: Colors.grey[300], child: const Icon(Icons.article, color: Colors.grey)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    title, 
                    maxLines: 2, 
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.lato(fontSize: 11, fontWeight: FontWeight.bold)
                  ),
                )
              ],
            ),
            if (_isAdmin)
              const Positioned(
                right: 4, top: 4,
                child: CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, color: Colors.white, size: 12))
              )
          ],
        ),
      ),
    );
  }

  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    final author = post['author'] ?? {};
    final String timeAgo = timeago.format(DateTime.tryParse(post['createdAt'] ?? "") ?? DateTime.now());
    
    // ✅ CRITICAL FIX: Safe ID Comparison using toString()
    final String postAuthorId = (post['authorId'] ?? '').toString();
    final String myId = (_currentUserId ?? '').toString();
    
    final bool isMyPost = (myId.isNotEmpty && postAuthorId == myId);
    final bool canDelete = _isAdmin || isMyPost;
    final bool canEdit = isMyPost;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        boxShadow: [
          if (!isDark) BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: author['profilePicture'] != null && author['profilePicture'].toString().startsWith('http')
                      ? CachedNetworkImageProvider(author['profilePicture'])
                      : null,
                  child: author['profilePicture'] == null ? const Icon(Icons.person, size: 20, color: Colors.grey) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author['fullName'] ?? 'Alumni User', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                      Text(author['jobTitle'] ?? 'Member', style: GoogleFonts.lato(color: subTextColor, fontSize: 11)),
                    ],
                  ),
                ),
                Text(timeAgo, style: GoogleFonts.lato(fontSize: 10, color: subTextColor)),
                
                // ✅ UPDATE POST MENU (Visible if author)
                if (canDelete || canEdit)
                  PopupMenuButton<String>(
                    onSelected: (val) {
                      if (val == 'edit') _editPost(post['_id'], post['text']);
                      if (val == 'delete') _deletePost(post['_id']);
                    },
                    itemBuilder: (c) => [
                      if (canEdit)
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text("Edit")])),
                      if (canDelete)
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))]))
                    ],
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.more_vert, size: 20, color: subTextColor),
                    ),
                  )
              ],
            ),
          ),

          if (post['text'] != null && post['text'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(post['text'], style: GoogleFonts.lato(fontSize: 14, color: textColor, height: 1.4)),
            ),

          if (post['mediaType'] == 'image' && post['mediaUrl'] != null && post['mediaUrl'].toString().startsWith('http'))
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: ClipRRect(
                child: CachedNetworkImage(
                  imageUrl: post['mediaUrl'],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(height: 200, color: Colors.grey[100]),
                  errorWidget: (context, url, error) => const SizedBox.shrink(),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                _buildReactionButton(
                  icon: post['isLikedByMe'] == true ? Icons.thumb_up : Icons.thumb_up_outlined,
                  count: "${post['likes']?.length ?? 0}",
                  isActive: post['isLikedByMe'] == true,
                  onTap: () => _toggleLike(index, post['_id']),
                ),
                const SizedBox(width: 16),
                _buildReactionButton(
                  icon: Icons.comment_outlined,
                  count: "${post['comments']?.length ?? 0}",
                  isActive: false,
                  // ✅ FIX: Pass update callback
                  onTap: () => _showCommentsSheet(post['_id'], index, (newCount) {
                    setState(() {
                      if (_filteredPosts.length > index) {
                        _filteredPosts[index]['comments'] = List.filled(newCount, "placeholder");
                      }
                    });
                  }),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.share_outlined, size: 20, color: subTextColor),
                  onPressed: () => _sharePost(post),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionButton({required IconData icon, required String count, required bool isActive, required VoidCallback onTap}) {
    final color = isActive ? const Color(0xFFD4AF37) : Colors.grey[600];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(count, style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mark_chat_unread_rounded, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(_isSearching ? "No matching updates." : "No updates yet.", style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[500])),
        ],
      ),
    );
  }
}