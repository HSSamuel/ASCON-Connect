import 'package:flutter/material.dart';

class AppTheme {
  // ✅ Brand Colors
  static const Color primaryGreen = Color(0xFF1B5E3A);
  
  // ✅ ADDED: Alias for 'asconGreen' to fix the error in jobs_screen.dart
  static const Color asconGreen = primaryGreen; 

  static const Color accentGold = Color(0xFFD4AF37);

  // 🌞 LIGHT THEME (The Standard View)
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryGreen,
    scaffoldBackgroundColor: const Color(0xFFF9FAFB), // Soft Light Grey
    cardColor: Colors.white,
    dividerColor: Colors.grey[200],
    
    // AppBar Style
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: Colors.white,
      elevation: 0,
    ),

    // ✅ INPUT FIELDS (Login/Register Boxes)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: TextStyle(color: Colors.grey[500]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryGreen, width: 1.5),
      ),
    ),

    // Text Theme
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.black87), 
      bodyMedium: TextStyle(color: Colors.black54), 
    ),
    
    // Icon Theme
    iconTheme: const IconThemeData(color: primaryGreen),
    colorScheme: ColorScheme.fromSwatch().copyWith(secondary: accentGold),
  );

  // 🌙 DARK THEME (The Night View)
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryGreen,
    scaffoldBackgroundColor: const Color(0xFF121212), // True Black
    cardColor: const Color(0xFF1E1E1E), // Dark Grey Cards
    dividerColor: Colors.grey[800],

    // AppBar Style (Darker Green for eye comfort)
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF14452B), 
      foregroundColor: Colors.white,
      elevation: 0,
    ),

    // ✅ INPUT FIELDS (Dark Mode Version)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2C2C2C), // Dark Grey Box
      hintStyle: TextStyle(color: Colors.grey[500]),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: primaryGreen, width: 1.5),
      ),
    ),

    // Text Theme (White text for dark background)
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: Colors.white), 
      bodyMedium: TextStyle(color: Colors.grey), 
    ),

    // Icon Theme
    iconTheme: const IconThemeData(color: Color(0xFF81C784)), // Lighter Green
    colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark).copyWith(secondary: accentGold),
  );
}