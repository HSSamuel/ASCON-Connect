import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/data_service.dart';
import 'job_detail_screen.dart'; // ✅ Make sure to import the detail screen

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final DataService _dataService = DataService();
  late Future<List<dynamic>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _jobsFuture = _dataService.fetchJobs();
  }

  Future<void> _refreshJobs() async {
    setState(() {
      _jobsFuture = _dataService.fetchJobs();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Theme Awareness
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(
          "Career Opportunities",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, 
      ),
      body: RefreshIndicator(
        onRefresh: _refreshJobs,
        color: primaryColor,
        child: FutureBuilder<List<dynamic>>(
          future: _jobsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: primaryColor));
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 40, color: Colors.grey),
                    SizedBox(height: 10),
                    Text("Could not load jobs", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            
            final jobs = snapshot.data ?? [];

            if (jobs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.work_off_outlined, size: 60, color: Colors.grey[300]),
                    const SizedBox(height: 10),
                    Text(
                      "No active job listings", 
                      style: GoogleFonts.inter(color: Colors.grey)
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              separatorBuilder: (c, i) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                return _buildJobCard(jobs[index], isDark);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job, bool isDark) {
    return Card(
      color: Theme.of(context).cardColor,
      elevation: isDark ? 0 : 2, // Remove shadow in dark mode for cleaner look
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDark ? BorderSide(color: Colors.grey[800]!) : BorderSide.none, // Subtle border in dark mode
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // ✅ Navigate to the new Detail Screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => JobDetailScreen(job: job)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      job['title'] ?? "Untitled Role",
                      style: GoogleFonts.inter(
                        fontSize: 16, 
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildTag(job['type'] ?? 'Full-time', Colors.blue, isDark),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                job['company'] ?? "Unknown Company",
                style: GoogleFonts.inter(
                  fontSize: 14, 
                  color: isDark ? Colors.grey[400] : Colors.grey[600], 
                  fontWeight: FontWeight.w500
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    job['location'] ?? "Remote", 
                    style: TextStyle(fontSize: 12, color: Colors.grey)
                  ),
                  const Spacer(),
                  if (job['salary'] != null && job['salary'].toString().isNotEmpty)
                    Text(
                      job['salary'],
                      style: GoogleFonts.inter(
                        fontSize: 12, 
                        color: Colors.green[600], 
                        fontWeight: FontWeight.bold
                      ),
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: isDark ? Border.all(color: color.withOpacity(0.5)) : null,
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10, 
          color: isDark ? color.withOpacity(0.9) : color, 
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }
}