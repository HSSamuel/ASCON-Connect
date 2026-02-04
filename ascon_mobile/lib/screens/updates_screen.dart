import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../config.dart';

// ✅ RENAMED CLASS: This replaces the old JobsScreen
class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  final ApiClient _api = ApiClient();
  List<dynamic> _posts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() => _isLoading = true);
    try {
      final response = await _api.get('/api/updates');
      if (mounted && response['success'] == true) {
        setState(() {
          _posts = response['data'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading feed: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLike(int index, String postId) async {
    // 1. Optimistic UI Update (Instant visual feedback)
    setState(() {
      _posts[index]['isLikedByMe'] = !_posts[index]['isLikedByMe'];
      if (_posts[index]['isLikedByMe']) {
        _posts[index]['likes'].add('dummy_id');
      } else {
        _posts[index]['likes'].removeLast();
      }
    });

    // 2. Send to backend
    try {
      await _api.put('/api/updates/$postId/like', {});
    } catch (e) {
      _loadFeed(); // Revert if failed
    }
  }

  // =========================================================
  // 📝 CREATE POST BOTTOM SHEET
  // =========================================================
  void _showCreatePostSheet() {
    final TextEditingController textController = TextEditingController();
    File? selectedImage;
    bool isPosting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            
            // Function to pick image
            Future<void> pickImage() async {
              final picker = ImagePicker();
              final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
              if (pickedFile != null) {
                setSheetState(() => selectedImage = File(pickedFile.path));
              }
            }

            // Function to post data
            Future<void> submitPost() async {
              if (textController.text.trim().isEmpty && selectedImage == null) return;

              setSheetState(() => isPosting = true);

              try {
                final token = await AuthService().getToken();
                var request = http.MultipartRequest('POST', Uri.parse('${AppConfig.baseUrl}/api/updates'));
                request.headers['auth-token'] = token ?? '';

                request.fields['text'] = textController.text.trim();

                if (selectedImage != null) {
                  request.files.add(await http.MultipartFile.fromPath('media', selectedImage!.path));
                }

                var response = await request.send();

                if (response.statusCode == 201) {
                  Navigator.pop(sheetContext); // Close sheet
                  _loadFeed(); // Refresh feed
                  ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Posted successfully!")));
                }
              } catch (e) {
                debugPrint("Post error: $e");
              } finally {
                setSheetState(() => isPosting = false);
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
                      Text("Create Update", style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
                      isPosting 
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: submitPost,
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37), foregroundColor: Colors.white),
                            child: const Text("POST"),
                          ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: textController,
                    maxLines: 4,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: "What's happening in your network?",
                      border: InputBorder.none,
                    ),
                  ),
                  if (selectedImage != null)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(selectedImage!, height: 150, width: double.infinity, fit: BoxFit.cover),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.black54),
                          onPressed: () => setSheetState(() => selectedImage = null),
                        ),
                      ],
                    ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: Colors.green),
                    title: const Text("Add a photo"),
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

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go('/home'); // Go to Home Tab
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          title: Text("Alumni Feed", style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          elevation: 0,
        ),
        
        body: RefreshIndicator(
          onRefresh: _loadFeed,
          color: primaryColor,
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : _posts.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _posts.length,
                      itemBuilder: (context, index) => _buildPostCard(_posts[index], index),
                    ),
        ),

        // ✅ FAB to trigger the bottom sheet
        floatingActionButton: FloatingActionButton(
          onPressed: _showCreatePostSheet,
          backgroundColor: const Color(0xFFD4AF37), // Gold
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ),
    );
  }

  // =========================================================
  // 🖼️ POST CARD WIDGET
  // =========================================================
  Widget _buildPostCard(Map<String, dynamic> post, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodyMedium?.color;

    final author = post['author'] ?? {};
    final String timeAgo = timeago.format(DateTime.parse(post['createdAt']));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: author['profilePicture'] != null && author['profilePicture'].toString().startsWith('http')
                      ? CachedNetworkImageProvider(author['profilePicture'])
                      : null,
                  child: author['profilePicture'] == null ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(author['fullName'] ?? 'Alumni', style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                      Text("${author['jobTitle'] ?? 'Member'} • $timeAgo", style: GoogleFonts.lato(color: subTextColor, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (post['text'] != null && post['text'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(post['text'], style: GoogleFonts.lato(fontSize: 14, color: textColor, height: 1.4)),
            ),

          if (post['mediaType'] == 'image' && post['mediaUrl'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: CachedNetworkImage(
                imageUrl: post['mediaUrl'],
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Container(height: 200, color: Colors.grey[200]),
              ),
            ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.thumb_up, size: 12, color: Theme.of(context).primaryColor),
                const SizedBox(width: 4),
                Text("${post['likes']?.length ?? 0}", style: TextStyle(fontSize: 12, color: subTextColor)),
                const Spacer(),
                Text("${post['comments']?.length ?? 0} comments", style: TextStyle(fontSize: 12, color: subTextColor)),
              ],
            ),
          ),

          Divider(height: 1, color: isDark ? Colors.grey[800] : Colors.grey[200]),

          Row(
            children: [
              _buildActionButton(
                icon: post['isLikedByMe'] ? Icons.thumb_up : Icons.thumb_up_outlined,
                label: "Like",
                color: post['isLikedByMe'] ? Theme.of(context).primaryColor : subTextColor!,
                onTap: () => _toggleLike(index, post['_id']),
              ),
              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                label: "Comment",
                color: subTextColor!,
                onTap: () {
                  // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Comments coming soon!")));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(label, style: GoogleFonts.lato(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dynamic_feed_rounded, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text("No updates yet. Be the first to post!", style: GoogleFonts.lato(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}