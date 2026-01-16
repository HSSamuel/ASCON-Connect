import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
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
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

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
          // ✅ Facilities Tab with Video Header
          const FacilitiesTab(), 
        ],
      ),
    );
  }

  // ==========================================
  // 💼 JOBS LIST 
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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

// ==========================================
// 🏢 FACILITIES TAB (Fixed Video Logic)
// ==========================================
class FacilitiesTab extends StatefulWidget {
  const FacilitiesTab({super.key});

  @override
  State<FacilitiesTab> createState() => _FacilitiesTabState();
}

class _FacilitiesTabState extends State<FacilitiesTab> {
  final DataService _dataService = DataService();
  final NumberFormat _currency = NumberFormat.currency(symbol: "₦", decimalDigits: 0);
  
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // ✅ FIX: Use a direct MP4 link. YouTube links will NOT work.
  // This is a sample video provided by Flutter that is guaranteed to play.
  // For your own video, upload an .mp4 file to your server or cloud storage.
  final String _videoUrl = "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4";

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      // ✅ Use networkUrl for online MP4s
      _videoController = VideoPlayerController.networkUrl(Uri.parse(_videoUrl));

      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.setVolume(0.0); // Mute for autoplay
      _videoController!.play();
      
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint("❌ Video Initialization Error: $e");
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
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
          itemCount: facilities.isEmpty ? 1 : facilities.length + 1,
          itemBuilder: (context, index) {
            // 🎬 1. VIDEO HEADER (Position 0)
            if (index == 0) {
              return Column(
                children: [
                  if (_isVideoInitialized && _videoController != null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_videoController!.value.isPlaying) {
                            _videoController!.pause();
                          } else {
                            _videoController!.play();
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                VideoPlayer(_videoController!),
                                // Gradient Overlay
                                Container(
                                  width: double.infinity,
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Colors.transparent, Colors.black54],
                                    ),
                                  ),
                                ),
                                // Text Overlay
                                Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Text(
                                    "Experience ASCON Facilities",
                                    style: GoogleFonts.inter(
                                      color: Colors.white, 
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                // Play Icon when paused
                                if (!_videoController!.value.isPlaying)
                                  const Center(
                                    child: Icon(Icons.play_circle_fill, color: Colors.white54, size: 50),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  
                  if (facilities.isEmpty)
                    _buildEmptyState("No facilities listed.", Icons.apartment),
                ],
              );
            }

            // 🏢 2. FACILITY CARDS
            return _buildFacilityCard(facilities[index - 1], isDark, primaryColor);
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
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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

  Widget _buildSafeImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[300], 
        child: Icon(Icons.business, size: 50, color: Colors.grey[400])
      );
    }
    if (imageUrl.startsWith('http')) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(color: Colors.grey[300]),
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
          Text(msg, style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}