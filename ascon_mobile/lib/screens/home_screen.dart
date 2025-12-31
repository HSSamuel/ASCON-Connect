import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'directory_screen.dart';
import 'profile_screen.dart';
import 'events_screen.dart';
import 'about_screen.dart'; // ✅ ADDED MISSING IMPORT

class HomeScreen extends StatefulWidget {
  final String userName; 
  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; 
  late List<Widget> _screens; 

  @override
  void initState() {
    super.initState();
    _screens = [
      _DashboardView(userName: widget.userName),
      const EventsScreen(), // Added const for better performance
      const DirectoryScreen(),
      ProfileScreen(userName: widget.userName),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex], 
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; 
          });
        },
        selectedItemColor: const Color(0xFF1B5E3A), // ✅ ASCON Deep Green
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 10,
        type: BottomNavigationBarType.fixed, 
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: "Dashboard",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: "Events",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt),
            label: "Directory",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

// Internal Widget for the Dashboard Content
class _DashboardView extends StatelessWidget {
  final String userName;
  const _DashboardView({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ASCON Dashboard"),
        backgroundColor: const Color(0xFF1B5E3A), // ✅ ASCON Deep Green
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        
        // ✅ CORRECTED POSITION: 'actions' is now INSIDE AppBar
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutScreen()),
              );
            },
          ),
        ],
      ),
      
      backgroundColor: Colors.grey[50],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_user, size: 80, color: Color(0xFFD4AF37)), // Gold Icon
              const SizedBox(height: 20),
              
              Text(
                "Welcome, $userName",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1B5E3A),
                ),
              ),
              const SizedBox(height: 10),
              
              Text(
                "You are successfully logged in.",
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 30),
              
              // Helper text to guide the user
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)
                  ]
                ),
                child: Column(
                  children: [
                    const Text("Use the bottom menu to navigate:", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.list_alt, size: 16, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text("Search Alumni Directory", style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text("Manage your Profile", style: TextStyle(color: Colors.grey[700])),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}