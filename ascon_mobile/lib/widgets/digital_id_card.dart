import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart'; // ✅ PERFORMANCE UPGRADE
import 'dart:convert';

class DigitalIDCard extends StatelessWidget {
  final String userName;
  final String programme;
  final String year;
  final String alumniID; // ✅ Shows the official ID
  final String imageUrl;

  const DigitalIDCard({
    super.key,
    required this.userName,
    required this.programme,
    required this.year,
    required this.alumniID,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    const Color cardGreen = Color(0xFF1B5E3A);

    // Generate Verification Link for QR
    // Replaces slashes (/) with dashes (-) for URL safety if needed
    final String verificationLink = "https://asconadmin.netlify.app/verify/${alumniID.replaceAll('/', '-')}";

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isDesktop = width > 600; 

        return Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1400),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              color: cardGreen,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Watermark Background
                Positioned(
                  bottom: -20,
                  right: -20,
                  child: Icon(
                    Icons.school, 
                    size: width * 0.25, 
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),

                // MAIN CONTENT
                Padding(
                  padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      
                      // --- HEADER ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center, 
                              child: Text(
                                "ADMINISTRATIVE STAFF COLLEGE OF NIGERIA",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: isDesktop ? 45 : 30,
                            width: isDesktop ? 45 : 30,
                            child: Image.asset(
                              'assets/logo.png',
                              errorBuilder: (c, e, s) => const Icon(Icons.verified, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      
                      Divider(color: Colors.white24, height: isDesktop ? 30 : 20),
                      
                      // --- BODY ---
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // LEFT COLUMN: Avatar + QR
                          Column(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: isDesktop ? 50 : 30,
                                  backgroundColor: Colors.grey[200],
                                  
                                  // ✅ 1. Try Loading Cached Image (if URL is valid)
                                  backgroundImage: (imageUrl.isNotEmpty && !imageUrl.startsWith('data:'))
                                      ? CachedNetworkImageProvider(imageUrl)
                                      : null,

                                  // ✅ 2. Fallback for Empty or Base64 Images
                                  child: (imageUrl.isEmpty || imageUrl.startsWith('data:'))
                                      ? _buildFallbackImage(imageUrl, isDesktop) 
                                      : null,
                                ),
                              ),
                              SizedBox(height: isDesktop ? 16 : 10),
                              
                              // QR Code Container
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: QrImageView(
                                  data: verificationLink,
                                  version: QrVersions.auto,
                                  size: isDesktop ? 80.0 : 45.0,
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(width: isDesktop ? 24 : 16),
                          
                          // RIGHT COLUMN: User Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "ASCON ALUMNI",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: isDesktop ? 6 : 4),
                                
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    userName.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isDesktop ? 32 : 20, 
                                      fontWeight: FontWeight.bold,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                                
                                SizedBox(height: isDesktop ? 8 : 6),
                                
                                Text(
                                  programme,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: isDesktop ? 16 : 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                SizedBox(height: isDesktop ? 12 : 8),

                                // ✅ VISIBLE ALUMNI ID TEXT
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4)
                                  ),
                                  child: Text(
                                    "ID: $alumniID", // e.g., "ID: ASC/2025/0002"
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isDesktop ? 14 : 11,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1.0,
                                      fontFamily: "monospace"
                                    ),
                                  ),
                                ),
                                
                                SizedBox(height: isDesktop ? 16 : 10),
                                
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isDesktop ? 16 : 10, 
                                    vertical: isDesktop ? 6 : 4
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "CLASS OF $year",
                                    style: TextStyle(
                                      color: cardGreen,
                                      fontSize: isDesktop ? 12 : 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ✅ HELPER: Handles Base64 Images & Missing Photos
  Widget _buildFallbackImage(String imagePath, bool isDesktop) {
    if (imagePath.startsWith('data:')) {
      try {
        return ClipOval(
          child: Image.memory(
            base64Decode(imagePath.split(',').last),
            fit: BoxFit.cover,
            width: isDesktop ? 100 : 60,
            height: isDesktop ? 100 : 60,
          ),
        );
      } catch (e) {
        // Fallback if Base64 is corrupt
        return Icon(Icons.person, color: Colors.grey, size: isDesktop ? 50 : 30);
      }
    }
    // Default Icon if completely empty
    return Icon(Icons.person, color: Colors.grey, size: isDesktop ? 50 : 30);
  }
}