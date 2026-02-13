import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../viewmodels/dashboard_view_model.dart';

// Changed from StatefulWidget to ConsumerWidget
class CelebrationWidget extends ConsumerWidget {
  const CelebrationWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ✅ WATCH THE PROVIDER
    final dashboardState = ref.watch(dashboardProvider);
    final birthdays = dashboardState.birthdays;
    final isLoading = dashboardState.isLoading;

    // If not loading and no birthdays, hide completely
    if (!isLoading && birthdays.isEmpty) return const SizedBox.shrink();

    // If loading effectively (initial load), show nothing or skeleton
    if (isLoading && birthdays.isEmpty) return const SizedBox.shrink();

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
          
          // ✅ Pass the list directly
          _buildBirthdayList(birthdays),
        ],
      ),
    );
  }

  Widget _buildBirthdayList(List<dynamic> birthdays) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: birthdays.length,
        itemBuilder: (context, index) {
            final item = birthdays[index];
            final String name = (item['fullName'] ?? "User").split(" ")[0]; 
            final String? img = item['profilePicture'];

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
                    child: _buildAvatar(img, name),
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
                  const Text(
                    "Birthday",
                    style: TextStyle(fontSize: 10, color: Colors.deepOrange)
                  ),
                ],
              ),
            );
        },
      ),
    );
  }

  Widget _buildAvatar(String? url, String name) {
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: 24,
          backgroundImage: imageProvider,
          backgroundColor: Colors.white,
        ),
        placeholder: (context, url) => const CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white,
          child: Icon(Icons.person, color: Colors.grey),
        ),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white,
          child: Text(
            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?",
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
          ),
        ),
      );
    }
    
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.white,
      child: Text(
        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : "?",
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
      ),
    );
  }
}