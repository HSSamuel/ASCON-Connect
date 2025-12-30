import 'package:flutter/material.dart';
import 'directory_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userName; // We keep this to pass it if needed, or ignore it
  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0; // Tracks which tab is active (0, 1, or 2)

  // The list of screens to show
  final List<Widget> _screens = [
    // Tab 0: The Dashboard View
    _DashboardView(),
    // Tab 1: The Directory View
    const DirectoryScreen(), // We embed the screen directly here!
    // Tab 2: The Profile View
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // We remove the AppBar here because each screen has its own
      body: _screens[_currentIndex], 
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index; // Switch the tab
          });
        },
        selectedItemColor: Color(0xFF006400), // ASCON Green for active tab
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list_alt), // Directory Icon
            label: "Directory",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

// Simple Widget for the Dashboard Content
class _DashboardView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ASCON Dashboard"),
        backgroundColor: Color(0xFF006400),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false, // Hides the back button
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user, size: 80, color: Color(0xFFD4AF37)),
            SizedBox(height: 20),
            Text("Welcome to ASCON Connect", style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text("Select a tab below to navigate.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}