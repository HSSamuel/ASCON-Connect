import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import 'package:go_router/go_router.dart'; // ✅ IMPORT GO_ROUTER
import '../services/data_service.dart';
import '../widgets/skeleton_loader.dart'; 
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
  
  late Future<List<dynamic>> _jobsFuture;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _jobsFuture = _dataService.fetchJobs(); 
  }

  Future<void> _refreshJobs() async {
    final newJobs = _dataService.fetchJobs();
    setState(() {
      _jobsFuture = newJobs;
    });
    await newJobs; 
  }

  Color _getCompanyColor(String name) {
    final List<Color> colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.redAccent, Colors.indigo
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;

    // ✅ WRAPPED WITH POPSCOPE
    return PopScope(
      canPop: false, 
      onPopInvoked: (didPop) {
        if (didPop) return;
        context.go('/home'); // Go to Home Tab
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white, 
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(
            "Opportunities & Facilities",
            style: GoogleFonts.lato(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: 22,
            ),
          ),
          centerTitle: false,
          elevation: 0,
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
                labelStyle: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 13),
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
            const FacilitiesTab(), 
          ],
        ),
      ),
    );
  }

  Widget _buildJobsList(bool isDark, Color primaryColor) {
    return RefreshIndicator(
      onRefresh: _refreshJobs, 
      color: primaryColor,
      child: FutureBuilder(
        future: _jobsFuture, 
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const JobSkeletonList();
          }
          if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: _buildEmptyState("No active job openings.", Icons.work_off),
                ),
              ],
            );
          }

          final jobs = snapshot.data as List;
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(), 
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              return _buildPremiumJobCard(jobs[index], isDark, primaryColor);
            },
          );
        },
      ),
    );
  }

  Widget _buildPremiumJobCard(dynamic job, bool isDark, Color primaryColor) {
    final String company = job['company'] ?? "ASCON";
    final String initial = company.isNotEmpty ? company[0].toUpperCase() : "A";
    final Color brandColor = _getCompanyColor(company);
    final String salary = job['salary'] ?? "";
    final String? logoUrl = job['image'] ?? job['logo']; 

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JobDetailScreen(job: job))),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: brandColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        image: (logoUrl != null && logoUrl.startsWith('http')) 
                            ? DecorationImage(image: CachedNetworkImageProvider(logoUrl), fit: BoxFit.cover)
                            : null
                      ),
                      alignment: Alignment.center,
                      child: (logoUrl == null || !logoUrl.startsWith('http')) 
                        ? Text(
                            initial,
                            style: GoogleFonts.rubik(
                              fontSize: 22, 
                              fontWeight: FontWeight.bold, 
                              color: brandColor
                            ),
                          )
                        : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job['title'] ?? "Untitled Role",
                            style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 17, height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            company,
                            style: GoogleFonts.lato(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    _buildTag(job['type'] ?? 'Full-time', Colors.blue, isDark),
                    _buildTag(job['location'] ?? 'Remote', Colors.orange, isDark),
                    if (salary.isNotEmpty && salary != "Negotiable")
                      _buildTag(salary, Colors.green, isDark, isSalary: true),
                  ],
                ),

                const SizedBox(height: 20),
                Divider(height: 1, color: Colors.grey.withOpacity(0.1)),
                const SizedBox(height: 14),

                Row(
                  children: [
                    Icon(Icons.access_time_filled, size: 14, color: Colors.grey[400]),
                    const SizedBox(width: 6),
                    Text(
                      "Posted recently", 
                      style: GoogleFonts.lato(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
                    ),
                    const Spacer(),
                    
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: primaryColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "View Details",
                            style: GoogleFonts.lato(
                              fontSize: 12, 
                              fontWeight: FontWeight.w700, 
                              color: primaryColor
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 14, color: primaryColor)
                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String text, Color color, bool isDark, {bool isSalary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: isSalary ? Border.all(color: color.withOpacity(0.3), width: 1) : null,
      ),
      child: Text(
        text,
        style: GoogleFonts.lato(
          color: isDark ? color.withOpacity(0.9) : color.darken(0.1), 
          fontWeight: FontWeight.w700, 
          fontSize: 11
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: Colors.grey[400]),
          ),
          const SizedBox(height: 16),
          Text(msg, style: GoogleFonts.lato(color: Colors.grey[500], fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ==========================================
// 🏢 FACILITIES TAB 
// ==========================================
class FacilitiesTab extends StatefulWidget {
  const FacilitiesTab({super.key});

  @override
  State<FacilitiesTab> createState() => _FacilitiesTabState();
}

class _FacilitiesTabState extends State<FacilitiesTab> {
  final DataService _dataService = DataService();
  final NumberFormat _currency = NumberFormat.currency(symbol: "₦", decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showVideoPopup();
    });
  }

  void _showVideoPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const VideoPopupDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return FutureBuilder(
      future: _dataService.fetchFacilities(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }
        
        final facilities = (snapshot.data as List?) ?? [];

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: facilities.isEmpty ? 1 : facilities.length,
          itemBuilder: (context, index) {
            if (facilities.isEmpty) {
               return _buildEmptyState("No facilities listed.", Icons.apartment);
            }
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
            Stack(
              children: [
                Hero(
                  tag: 'facility_img_${facility['_id'] ?? facility['name']}',
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: _buildSafeImage(imageUrl),
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
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Row(
                      children: [
                        Icon(isActive ? Icons.check_circle : Icons.lock, color: Colors.white, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          isActive ? "AVAILABLE" : "BOOKED",
                          style: GoogleFonts.lato(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
                          style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 17),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        priceTag,
                        style: GoogleFonts.lato(color: primaryColor, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    facility['description'] ?? "No description available.",
                    style: GoogleFonts.lato(color: Colors.grey[600], fontSize: 13, height: 1.4),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.star_rounded, size: 16, color: Colors.amber),
                      Text(" 4.8", style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                      const Spacer(),
                      Text(
                        "Book Now",
                        style: GoogleFonts.lato(fontWeight: FontWeight.w600, color: primaryColor, fontSize: 12),
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

  Widget _buildSafeImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[300], 
        child: Icon(Icons.business, size: 50, color: Colors.grey[400])
      );
    }

    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => const SkeletonImage(),
        errorWidget: (context, url, error) => Container(color: Colors.grey[300]),
      );
    }

    try {
      String cleanBase64 = imageUrl;
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }
      return Image.memory(
        base64Decode(cleanBase64),
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
      );
    } catch (e) {
      return Container(color: Colors.grey[300]);
    }
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
          Text(msg, style: GoogleFonts.lato(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class VideoPopupDialog extends StatefulWidget {
  const VideoPopupDialog({super.key});

  @override
  State<VideoPopupDialog> createState() => _VideoPopupDialogState();
}

class _VideoPopupDialogState extends State<VideoPopupDialog> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  
  final String _assetVideoPath = 'assets/videos/facility_intro.mp4';

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(_assetVideoPath)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
          _controller.play(); 
          _controller.setVolume(1.0); 
        }
      }).catchError((error) {
        debugPrint("❌ Popup Video Error: $error");
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent, 
      insetPadding: const EdgeInsets.symmetric(horizontal: 10), 
      child: Container(
        clipBehavior: Clip.hardEdge, 
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _initialized
                  ? AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    )
                  : const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
              
              InkWell(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12), 
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor, 
                  ),
                  child: Text(
                    "Close Video", 
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      color: Theme.of(context).primaryColor,
                      fontSize: 15
                    )
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

extension ColorDarken on Color {
  Color darken([double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}