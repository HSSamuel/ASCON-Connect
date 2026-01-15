import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math'; 
import '../services/data_service.dart';
import 'job_detail_screen.dart';
import 'facility_detail_screen.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DataService _dataService = DataService();
  
  // Currency Formatter
  final NumberFormat _currency = NumberFormat.currency(symbol: "₦", decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // Helper to generate consistent colors for companies
  Color _getCompanyColor(String name) {
    final List<Color> colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.redAccent
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        // ✅ 1. Uniform Green Background
        backgroundColor: primaryColor,
        foregroundColor: Colors.white, 
        iconTheme: const IconThemeData(color: Colors.white),
        
        title: Text(
          "Opportunities",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontSize: 22,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        
        // ✅ 2. Cleaner Tab Bar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.white, 
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: isDark ? primaryColor : primaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: isDark ? Colors.white : primaryColor,
              unselectedLabelColor: isDark ? Colors.white70 : Colors.grey[600],
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: "JOBS", height: 40),
                Tab(text: "FACILITIES", height: 40),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildJobsList(isDark, primaryColor),
          _buildFacilitiesList(isDark, primaryColor),
        ],
      ),
    );
  }

  // ==========================================
  // 💼 1. JOBS LIST (Optimized & Modern)
  // ==========================================
  Widget _buildJobsList(bool isDark, Color primaryColor) {
    return FutureBuilder(
      future: _dataService.fetchJobs(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
          return _buildEmptyState("No active job openings.", Icons.work_off);
        }

        final jobs = snapshot.data as List;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: jobs.length,
          itemBuilder: (context, index) {
            return _buildModernJobCard(jobs[index], isDark, primaryColor);
          },
        );
      },
    );
  }

  Widget _buildModernJobCard(dynamic job, bool isDark, Color primaryColor) {
    final String company = job['company'] ?? "ASCON";
    final String initial = company.isNotEmpty ? company[0].toUpperCase() : "A";
    final Color brandColor = _getCompanyColor(company);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(job: job))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: brandColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: brandColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job['title'] ?? "Untitled",
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            company,
                            style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    // Salary Pill
                    if (job['salary'] != null && job['salary'] != "Negotiable")
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          job['salary'],
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.green[700]),
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                const SizedBox(height: 12),

                // Tags Row
                Row(
                  children: [
                    _buildTag(job['type'] ?? 'Full-time', Colors.blue, isDark),
                    const SizedBox(width: 8),
                    _buildTag(job['location'] ?? 'Remote', Colors.orange, isDark),
                    const Spacer(),
                    Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      "Recently", 
                      style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 🏢 2. FACILITIES LIST (Refined)
  // ==========================================
  Widget _buildFacilitiesList(bool isDark, Color primaryColor) {
    return FutureBuilder(
      future: _dataService.fetchFacilities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
          return _buildEmptyState("No facilities listed.", Icons.apartment);
        }

        final facilities = snapshot.data as List;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: facilities.length,
          itemBuilder: (context, index) {
            return _buildFacilityCard(facilities[index], isDark, primaryColor);
          },
        );
      },
    );
  }

  Widget _buildFacilityCard(dynamic facility, bool isDark, Color primaryColor) {
    final String? imageUrl = facility['image'];
    final bool isActive = facility['isActive'] == true;
    final List<dynamic> rates = facility['rates'] ?? [];
    
    String priceTag = "View Details";
    if (rates.isNotEmpty) {
      try {
        final lowestRate = rates[0]['naira']; 
        if (lowestRate != null) {
          priceTag = "From ${_currency.format(int.tryParse(lowestRate.replaceAll(',', '')) ?? 0)}";
        }
      } catch (e) {
        priceTag = "Check Rates";
      }
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FacilityDetailScreen(facility: facility))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image
            Stack(
              children: [
                Hero(
                  tag: 'facility_img_${facility['_id'] ?? facility['name']}',
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : Container(color: Colors.grey[300], child: Icon(Icons.business, size: 50, color: Colors.grey[400])),
                    ),
                  ),
                ),
                Positioned(
                  top: 12, right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.withOpacity(0.9) : Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Row(
                      children: [
                        Icon(isActive ? Icons.check_circle : Icons.lock, color: Colors.white, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          isActive ? "AVAILABLE" : "BOOKED",
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          facility['name'] ?? "Facility Name",
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 17),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        priceTag,
                        style: GoogleFonts.inter(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    facility['description'] ?? "No description available.",
                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13, height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  
                  // Footer
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      Text(" 4.8", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      const Spacer(),
                      Text(
                        "Book Now",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: primaryColor, fontSize: 12),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_right_alt, size: 16, color: primaryColor),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(msg, style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}