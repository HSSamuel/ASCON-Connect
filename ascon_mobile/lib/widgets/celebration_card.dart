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
  List<dynamic> _birthdays = [];
  List<dynamic> _anniversaries = []; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCelebrants();
  }

  Future<void> _loadCelebrants() async {
    // Dynamic return type handles both List (old) and Map (new)
    final result = await DataService().fetchCelebrants(); 
    
    if (mounted) {
      setState(() {
        if (result is Map) {
            _birthdays = result['birthdays'] ?? [];
            _anniversaries = result['anniversaries'] ?? [];
        } else if (result is List) {
            // Fallback for older backend versions
            _birthdays = result; 
            _anniversaries = [];
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && _birthdays.isEmpty && _anniversaries.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)], 
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
          // 1. Birthdays Section
          if (_birthdays.isNotEmpty) ...[
              _buildHeader("Celebrating Today! 🎂", Colors.deepOrange[900]!),
              const SizedBox(height: 12),
              _buildHorizontalList(_birthdays, isAnniversary: false),
          ],

          // 2. Anniversaries Section
          if (_anniversaries.isNotEmpty) ...[
              if (_birthdays.isNotEmpty) const Divider(height: 24, color: Colors.orangeAccent),
              _buildHeader("Class Anniversaries 🎓", Colors.blue[800]!),
              const SizedBox(height: 12),
              _buildHorizontalList(_anniversaries, isAnniversary: true),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(String title, Color color) {
     return Row(
       children: [
         if (title.contains("Today")) const Icon(Icons.cake_rounded, color: Colors.deepOrange, size: 20),
         if (title.contains("Class")) const Icon(Icons.school, color: Colors.blue, size: 20),
         const SizedBox(width: 8),
         Text(
           title, 
           style: GoogleFonts.lato(
             fontSize: 16, 
             fontWeight: FontWeight.bold, 
             color: color
           )
         ),
       ],
     );
  }

  Widget _buildHorizontalList(List<dynamic> items, {required bool isAnniversary}) {
    if (_isLoading) {
       return const Padding(
          padding: EdgeInsets.all(8.0),
          child: SizedBox(
            height: 20, width: 20, 
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.deepOrange)
          ),
        );
    }

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        itemBuilder: (context, index) {
            final item = items[index];
            
            final String title = isAnniversary 
                ? "Class of ${item['year']}" 
                : (item['fullName'] ?? "User").split(" ")[0]; 
            
            final String subtitle = isAnniversary 
                ? "${item['yearsAgo']} Years" 
                : "Birthday";

            final String? img = isAnniversary ? null : item['profilePicture'];

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
                      backgroundColor: isAnniversary ? Colors.blue[100] : Colors.white,
                      backgroundImage: (img != null && img.isNotEmpty) 
                          ? CachedNetworkImageProvider(img) 
                          : null,
                      child: (img == null || img.isEmpty) 
                          ? Icon(
                              isAnniversary ? Icons.school : Icons.person, 
                              color: isAnniversary ? Colors.blue : Colors.grey
                            ) 
                          : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title, 
                    style: GoogleFonts.lato(
                      fontSize: 11, 
                      fontWeight: FontWeight.w600, 
                      color: Colors.brown[800]
                    )
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: Colors.grey)
                  ),
                ],
              ),
            );
        },
      ),
    );
  }
}