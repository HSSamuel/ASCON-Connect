import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key});

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  final DataService _dataService = DataService();
  List<dynamic> _polls = [];
  bool _isLoading = true;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = await AuthService().currentUserId;
    final polls = await _dataService.fetchPolls();
    if (mounted) {
      setState(() {
        _myUserId = userId;
        _polls = polls;
        _isLoading = false;
      });
    }
  }

  Future<void> _vote(String pollId, String optionId) async {
    // Optimistic Update
    setState(() {
      final pollIndex = _polls.indexWhere((p) => p['_id'] == pollId);
      if (pollIndex != -1) {
        // Remove my vote from any other option
        for (var opt in _polls[pollIndex]['options']) {
          List votes = opt['votes'];
          votes.remove(_myUserId);
        }
        // Add to new option
        final optIndex = _polls[pollIndex]['options'].indexWhere((o) => o['_id'] == optionId);
        if (optIndex != -1) {
          _polls[pollIndex]['options'][optIndex]['votes'].add(_myUserId);
        }
      }
    });

    await _dataService.votePoll(pollId, optionId);
    _loadData(); // Refresh to sync
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Polls & Voting", style: GoogleFonts.lato(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _polls.isEmpty
              ? const Center(child: Text("No active polls."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _polls.length,
                  itemBuilder: (context, index) => _buildPollCard(_polls[index]),
                ),
    );
  }

  Widget _buildPollCard(Map<String, dynamic> poll) {
    final List options = poll['options'];
    final int totalVotes = options.fold(0, (sum, item) => sum + (item['votes'] as List).length as int);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poll['question'], style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("$totalVotes Votes", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(),
            ...options.map((opt) {
              final bool isVoted = (opt['votes'] as List).contains(_myUserId);
              final int votes = (opt['votes'] as List).length;
              final double percent = totalVotes == 0 ? 0 : votes / totalVotes;

              return InkWell(
                onTap: () => _vote(poll['_id'], opt['_id']),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isVoted ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isVoted ? Theme.of(context).primaryColor : Colors.transparent),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(opt['text'], style: TextStyle(fontWeight: isVoted ? FontWeight.bold : FontWeight.normal)),
                          if (isVoted) const Icon(Icons.check_circle, size: 16, color: Colors.green),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: percent, backgroundColor: Colors.grey[300], color: Theme.of(context).primaryColor),
                      const SizedBox(height: 4),
                      Text("${(percent * 100).toStringAsFixed(1)}% ($votes votes)", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}