import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui'; // For blur effects
import '../services/notification_service.dart';

class NotificationPermissionScreen extends StatefulWidget {
  final String nextPath;

  const NotificationPermissionScreen({super.key, required this.nextPath});

  @override
  State<NotificationPermissionScreen> createState() => _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState extends State<NotificationPermissionScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Setup a subtle breathing animation for the notification icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _complete(bool granted) async {
    setState(() => _isLoading = true);
    
    // 1. Mark as seen
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_notification_prompt', true);

    if (granted) {
      // 2. Request System Permission
      await NotificationService().requestPermission();
    }

    if (mounted) {
      // 3. Navigate
      context.go(widget.nextPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryGreen = const Color(0xFF1B5E3A);
    final Color accentGold = const Color(0xFFD4AF37);
    final Color bg = isDark ? const Color(0xFF121212) : Colors.white;
    final Color cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    
    // ✅ FIX: Calculate responsive height to prevent overflow on small screens
    final screenHeight = MediaQuery.of(context).size.height;
    // Use 50% of screen height, but cap it at 420px for larger devices
    final double imageHeight = (screenHeight * 0.5 > 420) ? 420 : screenHeight * 0.5;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // 1. BACKGROUND DECORATION (Subtle Blobs)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryGreen.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentGold.withOpacity(0.05),
              ),
            ),
          ),

          // 2. MAIN CONTENT
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: Column(
                children: [
                  const Spacer(),

                  // --- ANIMATED HERO IMAGE SECTION ---
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            // Main Image Card
                            Container(
                              height: imageHeight, // ✅ APPLIED RESPONSIVE HEIGHT
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(30),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Placeholder / Asset Image
                                    Image.asset(
                                      'assets/images/alumni_group.png',
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, o, s) => Container(
                                        color: Colors.grey[200],
                                        child: Icon(Icons.groups_rounded, size: 100, color: Colors.grey[400]),
                                      ),
                                    ),
                                    // Gradient Overlay
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withOpacity(0.3),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Floating Notification Badge (Pulsing)
                            Positioned(
                              top: 15, 
                              right: 15, 
                              child: ScaleTransition(
                                scale: Tween(begin: 1.0, end: 1.1).animate(_pulseController),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      )
                                    ],
                                  ),
                                  child: Icon(Icons.notifications_active_rounded, color: primaryGreen, size: 25),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // --- TEXT SECTION ---
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 20, end: 0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    builder: (context, double value, child) {
                      return Transform.translate(
                        offset: Offset(0, value),
                        child: child,
                      );
                    },
                    child: Column(
                      children: [
                        Text(
                          "Stay in the loop",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF2D3436),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            "Enable notifications to get real-time updates on reunions, opportunities, and the latest news from ASCON.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lato(
                              fontSize: 14,
                              height: 1.5,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // --- ACTION BUTTONS ---
                  TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    builder: (context, double value, child) {
                      return Opacity(
                        opacity: value,
                        child: child,
                      );
                    },
                    child: Column(
                      children: [
                        // Primary Button (Gradient)
                        Container(
                          width: double.infinity,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1B5E3A), Color(0xFF2E7D32)], // Gradient Green
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: primaryGreen.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : () => _complete(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _isLoading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : Text(
                                    "Turn on Notifications",
                                    style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 13),
                        
                        // Secondary Button (Text)
                        TextButton(
                          onPressed: _isLoading ? null : () => _complete(false),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                          child: Text(
                            "Maybe Later",
                            style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}