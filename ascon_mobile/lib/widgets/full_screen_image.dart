import 'dart:convert';
import 'package:flutter/material.dart';

class FullScreenImage extends StatelessWidget {
  final String? imageUrl;
  final String heroTag;

  const FullScreenImage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // ✅ AppBar with Close Button (Crucial for user experience)
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(20),
            minScale: 0.5,
            maxScale: 4.0,
            child: _buildSafeImage(),
          ),
        ),
      ),
    );
  }

  Widget _buildSafeImage() {
    // 1. If Image is a URL (Network)
    if (imageUrl != null && imageUrl!.startsWith('http')) {
      return Image.network(
        imageUrl!,
        fit: BoxFit.contain,
        errorBuilder: (c, e, s) => _buildFallbackIcon(),
      );
    }

    // 2. If Image is Base64 (Database string)
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      try {
        // Remove header if present (e.g., "data:image/png;base64,")
        String cleanBase64 = imageUrl!;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }
        return Image.memory(
          base64Decode(cleanBase64),
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => _buildFallbackIcon(),
        );
      } catch (e) {
        return _buildFallbackIcon();
      }
    }

    // 3. Fallback if empty
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.person, size: 100, color: Colors.white54),
        SizedBox(height: 10),
        Text("No Image Available", style: TextStyle(color: Colors.white54)),
      ],
    );
  }
}