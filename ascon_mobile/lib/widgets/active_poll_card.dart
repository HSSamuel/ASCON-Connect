import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart'; // ✅ Import GoRouter
import '../services/data_service.dart';
import '../services/auth_service.dart';

class ActivePollCard extends StatefulWidget {
  const ActivePollCard({super.key});

  @override
  State<ActivePollCard> createState() => _ActivePollCardState();
}

class _ActivePollCardState extends State<ActivePollCard> {
  Map<String, dynamic>? _poll;
  bool _isLoading = true;
  String? _myUserId;
  bool _hasVoted = false;

  @override
  void initState() {
    super.initState();
    _loadPoll();
  }

  Future<void> _loadPoll() async {
    final userId = await AuthService().currentUserId;
    final polls = await DataService().fetchPolls();
    
    if (mounted) {
      setState(() {
        _myUserId = userId;
        // Get the most recent active poll
        _poll = (polls.isNotEmpty) ? polls.first : null;
        _isLoading = false;
        
        if (_poll != null && _myUserId != null) {
          // ✅ NEW LOGIC: Check 'votedUsers' array instead of options
          final List votedUsers = _poll!['votedUsers'] ?? [];
          if (votedUsers.contains(_myUserId)) {
            _hasVoted = true;
          }
        }
      });
    }
  }

  Future<void> _vote(String optionId) async {
    if (_poll == null) return;
    
    // ✅ Optimistic Update for Instant Feedback
    setState(() {
      _hasVoted = true;
      
      // Increment local count for the UI
      final options = _poll!['options'] as List;
      final optIndex = options.indexWhere((o) => o['_id'] == optionId);
      if (optIndex != -1) {
        int currentCount = options[optIndex]['voteCount'] ?? 0;
        options[optIndex]['voteCount'] = currentCount + 1;
      }
    });
    
    await DataService().votePoll(_poll!['_id'], optionId);
    // Note: No need to reload; optimistic update holds until next refresh
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _poll == null) return const SizedBox.shrink();

    final question = _poll!['question'];
    final List options = _poll!['options'];
    
    // ✅ NEW LOGIC: Calculate total from voteCount
    final int totalVotes = options.fold(0, (sum, item) => sum + (item['voteCount'] ?? 0) as int);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.how_to_vote, color: Colors.blue),
              const SizedBox(width: 8),
              Text("Active Poll", style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[900])),
              const Spacer(),
              
              // ✅ HISTORY BUTTON (Navigates to Full List)
              IconButton(
                icon: const Icon(Icons.history, color: Colors.grey, size: 22),
                tooltip: "Past Polls",
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  GoRouter.of(context).push('/polls'); 
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(question, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          
          ...options.map((opt) {
            final int votes = opt['voteCount'] ?? 0;
            final double percent = totalVotes == 0 ? 0 : votes / totalVotes;
            
            // Since voting is anonymous, we don't highlight a specific "selected" option anymore.
            // We just show the results view if the user has participated.

            if (_hasVoted) {
              // Result View
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(opt['text'], style: const TextStyle(fontSize: 13)),
                        // No checkmark because we are anonymous
                      ],
                    ),
                    const SizedBox(height: 4),
                    Stack(
                      children: [
                        Container(height: 8, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4))),
                        FractionallySizedBox(
                          widthFactor: percent,
                          child: Container(height: 8, decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text("${(percent * 100).toStringAsFixed(1)}%", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              );
            } else {
              // Voting View
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: OutlinedButton(
                  onPressed: () => _vote(opt['_id']),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    alignment: Alignment.centerLeft,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(opt['text']),
                ),
              );
            }
          }).toList(),
          
          if (_hasVoted)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text("$totalVotes votes total", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}