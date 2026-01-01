import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(20), 
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- 1. TOP LOGO ---
              Container(
                padding: const EdgeInsets.all(4), 
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1B5E3A), width: 2),
                ),
                child: const CircleAvatar(
                  radius: 25,
                  backgroundImage: AssetImage('assets/logo.png'), 
                  backgroundColor: Colors.transparent,
                ),
              ),
              const SizedBox(height: 15),

              // --- 2. TITLE ---
              Text(
                "Welcome to the ASCON Alumni Association!",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              // --- 3. MESSAGE BODY (Grey Box) ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F6), 
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"Dear Esteemed Alumnus,',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 10),
                    
                    // ✅ UPDATED: Added TextAlign.justify
                    Text(
                      "On behalf of the Administrative Staff College of Nigeria (ASCON), I warmly welcome you to our Alumni Association platform.\n\n"
                      "This platform has been designed to strengthen the bonds we share as members of the ASCON family and to provide opportunities for continued professional development, networking, and collaboration.\n\n"
                      "Together, we will continue to uphold the values of excellence, integrity, and innovation that define ASCON.\n\n"
                      'Welcome aboard!"',
                      
                      textAlign: TextAlign.justify, // <--- THIS JUSTIFIES THE TEXT
                      
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5, 
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- 4. SIGNATURE BLOCK ---
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 25,
                     backgroundImage: AssetImage('assets/ascondg.jpg'), 
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Mrs. Funke Femi Adepoju Ph.D",
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            "Director General, ASCON",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 25),

              // --- 5. GET STARTED BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); 
                    Navigator.of(context).pop(); 
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E3A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Get Started",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}