import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChapterCard extends StatelessWidget {
  const ChapterCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Ideally fetch this data from Profile or Group API
    const String chapterName = "Lagos Chapter";
    const int members = 142;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.location_city, color: Colors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("MY CHAPTER", style: GoogleFonts.lato(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey[600])),
                Text(chapterName, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text("$members Members • 2 New Posts", style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
               // Navigate to Chapter Chat/Feed
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text("Open", style: TextStyle(fontSize: 12)),
          )
        ],
      ),
    );
  }
}