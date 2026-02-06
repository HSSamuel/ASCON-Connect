import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/data_service.dart';

class CelebrationWidget extends StatefulWidget {
  const CelebrationWidget({super.key});

  @override
  State<CelebrationWidget> createState() => _CelebrationWidgetState();
}

class _CelebrationWidgetState extends State<CelebrationWidget> {
  List<dynamic> _celebrants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCelebrants();
  }

  Future<void> _loadCelebrants() async {
    // Note: Ensure fetchCelebrants() is added to DataService as per previous plan
    final data = await DataService().fetchCelebrants();
    if (mounted) {
      setState(() {
        _celebrants = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Hide widget completely if no one is celebrating
    if (!_isLoading && _celebrants.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)], // Warm Celebration Colors
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cake_rounded, color: Colors.deepOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                "Celebrating Today! 🎂", 
                style: GoogleFonts.lato(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.deepOrange[900]
                )
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                height: 20, width: 20, 
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange)
              ),
            )
          else
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _celebrants.length,
                itemBuilder: (context, index) {
                  final user = _celebrants[index];
                  final name = (user['fullName'] ?? "User").split(" ")[0]; // First Name
                  final img = user['profilePicture'];

                  return Padding(
                    padding: const EdgeInsets.only(right: 20.0),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white,
                            backgroundImage: (img != null && img.isNotEmpty) 
                                ? CachedNetworkImageProvider(img) 
                                : null,
                            child: (img == null || img.isEmpty) 
                                ? const Icon(Icons.person, color: Colors.grey) 
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name, 
                          style: GoogleFonts.lato(
                            fontSize: 11, 
                            fontWeight: FontWeight.w600, 
                            color: Colors.brown[800]
                          )
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}