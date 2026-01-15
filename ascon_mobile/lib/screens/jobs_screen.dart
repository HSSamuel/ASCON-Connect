import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart'; // ✅ Required for Currency Formatting
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
  
  // ✅ Currency Formatter for "Starts at ₦..."
  final NumberFormat _currency = NumberFormat.currency(symbol: "₦", decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 1. Theme Detection
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        // ✅ 2. PRO REQUEST: Uniform Green in Light Mode, White in Dark Mode
        title: Text(
          "Opportunities & Resources",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : primaryColor,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
        iconTheme: IconThemeData(color: isDark ? Colors.white : primaryColor),
        
        // ✅ 3. Custom Tab Bar Container
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
                ],
              ),
              labelColor: primaryColor,
              unselectedLabelColor: Colors.grey,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: "CAREERS", iconMargin: EdgeInsets.zero),
                Tab(text: "FACILITIES", iconMargin: EdgeInsets.zero),
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
  // 💼 1. JOBS LIST (Professional Card Layout)
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
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: jobs.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final job = jobs[index];
            return _buildJobCard(job, isDark, primaryColor);
          },
        );
      },
    );
  }

  Widget _buildJobCard(dynamic job, bool isDark, Color primaryColor) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(job: job))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.business_center, color: primaryColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job['title'] ?? "Untitled",
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job['company'] ?? "ASCON Network",
                          style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildTag(job['type'] ?? 'Full-time', Colors.blue, isDark),
                  const SizedBox(width: 8),
                  _buildTag(job['location'] ?? 'Remote', Colors.orange, isDark),
                  const Spacer(),
                  if (job['salary'] != null && job['salary'] != "Negotiable")
                    Text(
                      job['salary'],
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.green[700]),
                    ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 🏢 2. FACILITIES LIST (Immersive Hero Layout)
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
            final facility = facilities[index];
            return _buildFacilityCard(facility, isDark, primaryColor);
          },
        );
      },
    );
  }

  Widget _buildFacilityCard(dynamic facility, bool isDark, Color primaryColor) {
    final String? imageUrl = facility['image'];
    final bool isActive = facility['isActive'] == true;
    final List<dynamic> rates = facility['rates'] ?? [];
    
    // ✅ SMART PRICING: Shows "From ₦50,000" if rates exist
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
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🖼️ HERO IMAGE AREA
            Stack(
              children: [
                Hero(
                  tag: 'facility_img_${facility['_id'] ?? facility['name']}',
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl, 
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(color: Colors.grey[300], child: const Icon(Icons.image_not_supported)),
                            )
                          : Container(color: Colors.grey[300], child: Icon(Icons.business, size: 50, color: Colors.grey[400])),
                    ),
                  ),
                ),
                // ✨ GLASSMORPHISM STATUS BADGE
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.withOpacity(0.9) : Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Row(
                      children: [
                        Icon(isActive ? Icons.check_circle : Icons.lock, color: Colors.white, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          isActive ? "AVAILABLE" : "BOOKED",
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 📝 CONTENT AREA
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          facility['name'] ?? "Facility Name",
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 🏷️ PRICE BADGE
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          priceTag,
                          style: GoogleFonts.inter(color: primaryColor, fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    facility['description'] ?? "No description available.",
                    style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 14, height: 1.5),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  
                  // 🦶 FOOTER ACTIONS
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: Colors.orange[400]),
                      const SizedBox(width: 4),
                      Text("4.8 (Rating)", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
                      const Spacer(),
                      Text(
                        "View Details",
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: primaryColor, fontSize: 13),
                      ),
                      Icon(Icons.arrow_forward, size: 16, color: primaryColor),
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

  // --- HELPERS ---
  Widget _buildTag(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(msg, style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}