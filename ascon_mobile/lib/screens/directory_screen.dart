import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/directory_view_model.dart';
import '../widgets/directory_tabs/directory_tab.dart';
import '../widgets/directory_tabs/smart_match_tab.dart';
import '../widgets/directory_tabs/near_me_tab.dart';

class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});

  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> with SingleTickerProviderStateMixin {
  final DirectoryViewModel _viewModel = DirectoryViewModel();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Initialize the ViewModel logic (API calls, Sockets)
    _viewModel.init();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    // Use ListenableBuilder to rebuild the UI when ViewModel notifies listeners
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              "Alumni Directory",
              style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            automaticallyImplyLeading: false,
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFFD4AF37), // Gold
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: GoogleFonts.lato(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: "All"),
                Tab(text: "Smart Match"),
                Tab(text: "Near Me"),
              ],
            ),
          ),
          backgroundColor: bgColor,
          body: TabBarView(
            controller: _tabController,
            children: [
              DirectoryTab(viewModel: _viewModel),
              SmartMatchTab(viewModel: _viewModel),
              NearMeTab(viewModel: _viewModel),
            ],
          ),
        );
      },
    );
  }
}