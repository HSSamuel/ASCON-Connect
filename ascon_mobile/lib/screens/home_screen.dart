import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Make sure to add this for styling
import 'directory_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName; 
  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Tracks which tab is active (0, 1, or 2)
  late List<Widget> _screens; // We use 'late' because we initialize it in initState

  @override
  void initState() {
    super.initState();
    // We initialize the screens here so we can access 'widget.userName'
    _screens = [
      // Tab 0: Dashboard (We pass the name here too so it looks nice)
      _DashboardView(userName: widget.userName),
      
      // Tab 1: Directory
      const DirectoryScreen(),
      
      // Tab 2: Profile (We MUST pass the name here)
      ProfileScreen(userName: widget.userName),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The body changes based on the selected tab
      body: _screens[_currentIndex], 
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Switch the tab
          });
        },
        selectedItemColor: const Color(0xFF006400), // ASCON Green
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 10,
        type: BottomNavigationBarType.fixed, // Keeps buttons stable
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: "Dashboard",
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
        backgroundColor: const Color(0xFF006400),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, 
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
                  color: const Color(0xFF006400),
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