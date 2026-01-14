import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_client.dart';
import '../config/theme.dart';
import 'job_detail_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> with SingleTickerProviderStateMixin {
  final ApiClient _api = ApiClient();
  late TabController _tabController;
  
  // Data States
  bool _isJobsLoading = true;
  bool _isFacilitiesLoading = true;
  List<dynamic> _jobs = [];
  List<dynamic> _facilities = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    _fetchJobs();
    _fetchFacilities();
  }

  // 1. FETCH JOBS
  Future<void> _fetchJobs() async {
    try {
      final response = await _api.get('/api/jobs'); 
      if (mounted) {
        setState(() {
          _jobs = response['data'] ?? [];
          _isJobsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isJobsLoading = false);
    }
  }

  // 2. FETCH FACILITIES (✅ NOW DYNAMIC)
  Future<void> _fetchFacilities() async {
    try {
      final response = await _api.get('/api/facilities'); 
      if (mounted) {
        setState(() {
          _facilities = response['data'] ?? [];
          _isFacilitiesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Could not load facilities.";
          _isFacilitiesLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Opportunities & Facilities"),
        backgroundColor: AppTheme.asconGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: "VACANCIES"),
            Tab(text: "FACILITY RENTALS"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJobsTab(),       // Tab 1
          _buildFacilitiesTab(), // Tab 2
        ],
      ),
    );
  }

  // ... (Keep your existing _buildJobsTab logic here) ...
  Widget _buildJobsTab() {
    // ... [PASTE YOUR PREVIOUS JOBS TAB CODE HERE] ...
    // Or ask me if you want me to paste it again fully.
    if (_isJobsLoading) return const Center(child: CircularProgressIndicator());
    if (_jobs.isEmpty) return const Center(child: Text("No vacancies found"));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _jobs.length,
      itemBuilder: (context, index) {
        final job = _jobs[index];
        return Card(
           // ... Same Job Card Code ...
           child: ListTile(
             title: Text(job['title'] ?? 'Job'),
             subtitle: Text(job['company'] ?? 'ASCON'),
             trailing: const Icon(Icons.arrow_forward_ios, size: 16),
             onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(job: job))),
           ),
        );
      },
    );
  }

  // =========================================================
  // 🏨 TAB 2: FACILITIES (Dynamic from Database)
  // =========================================================
  Widget _buildFacilitiesTab() {
    if (_isFacilitiesLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_facilities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.apartment, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text("No facilities listed yet", style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _facilities.length,
      itemBuilder: (context, index) {
        final facility = _facilities[index];
        final List rates = facility['rates'] ?? [];

        return Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 24),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. IMAGE HEADER
              Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: facility['image'] ?? "",
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => Container(
                      height: 180, 
                      color: Colors.grey[300],
                      child: const Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black87, Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        )
                      ),
                      child: Text(
                        facility['name'] ?? "Facility",
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),

              // 2. THE TABLE HEADER
              Container(
                color: Colors.grey[100],
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                child: const Row(
                  children: [
                    Expanded(flex: 3, child: Text("TYPE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                    Expanded(flex: 2, child: Text("AMOUNT (₦)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                    Expanded(flex: 2, child: Text("AMOUNT (\$)", textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey))),
                  ],
                ),
              ),

              // 3. THE TABLE ROWS (Dynamic Mapping)
              ...rates.map<Widget>((rate) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(rate['type'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                      Expanded(flex: 2, child: Text("₦${rate['naira']}", style: const TextStyle(color: AppTheme.asconGreen, fontWeight: FontWeight.bold))),
                      Expanded(flex: 2, child: Text("\$${rate['dollar']}", textAlign: TextAlign.right, style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold))),
                    ],
                  ),
                );
              }).toList(),

              // 4. ACTION BUTTON
               Padding(
                padding: const EdgeInsets.all(12),
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("To book, please contact ASCON Admin via the Help Desk.")));
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text("Check Availability"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}