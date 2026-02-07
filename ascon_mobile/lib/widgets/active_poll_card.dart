import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../services/data_service.dart';
import '../services/auth_service.dart';

class ActivePollCard extends StatefulWidget {
  final String? groupId; 

  const ActivePollCard({super.key, this.groupId});

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
    
    List<dynamic> polls;
    if (widget.groupId != null) {
      polls = await DataService().fetchGroupPolls(widget.groupId!);
    } else {
      polls = await DataService().fetchPolls();
    }
    
    if (mounted) {
      setState(() {
        _myUserId = userId;
        _poll = (polls.isNotEmpty) ? polls.first : null;
        _isLoading = false;
        
        if (_poll != null && _myUserId != null) {
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
    
    setState(() {
      _hasVoted = true;
      final options = _poll!['options'] as List;
      final optIndex = options.indexWhere((o) => o['_id'] == optionId);
      if (optIndex != -1) {
        int currentCount = options[optIndex]['voteCount'] ?? 0;
        options[optIndex]['voteCount'] = currentCount + 1;
      }
    });
    
    await DataService().votePoll(_poll!['_id'], optionId);
  }

  // ✅ ACTION: Delete Poll
  Future<void> _deletePoll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Poll"),
        content: const Text("Are you sure? This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("Delete")),
        ],
      )
    );

    if (confirm == true && _poll != null) {
      setState(() => _isLoading = true);
      await DataService().deletePoll(_poll!['_id']);
      if (mounted) _loadPoll(); // Refresh to show next poll or empty
    }
  }

  // ✅ ACTION: Edit Poll
  Future<void> _editPoll() async {
    final ctrl = TextEditingController(text: _poll!['question']);
    final newQuestion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Edit Question"),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Question"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text("Save"),
          ),
        ],
      )
    );

    if (newQuestion != null && newQuestion.isNotEmpty && newQuestion != _poll!['question']) {
      setState(() => _isLoading = true);
      await DataService().updatePollQuestion(_poll!['_id'], newQuestion);
      if (mounted) _loadPoll();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _poll == null) return const SizedBox.shrink();

    final question = _poll!['question'];
    final List options = _poll!['options'];
    final int totalVotes = options.fold(0, (sum, item) => sum + (item['voteCount'] ?? 0) as int);
    
    // ✅ Check Ownership (Only creator sees the menu)
    final bool isCreator = _poll!['createdBy'] == _myUserId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                "Active Poll", 
                style: GoogleFonts.lato(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue[800])
              ),
              const Spacer(),
              
              // ✅ CREATOR MENU (Edit / Delete)
              if (isCreator)
                PopupMenuButton<String>(
                  onSelected: (val) {
                    if (val == 'edit') _editPoll();
                    if (val == 'delete') _deletePoll();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text("Edit Question")])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
                  ],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.more_horiz, color: Colors.grey, size: 20),
                )
              else if (widget.groupId == null) 
                IconButton(
                  icon: const Icon(Icons.history, color: Colors.grey, size: 20),
                  tooltip: "Past Polls",
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => context.push('/polls'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(question, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          
          ...options.map((opt) {
            final int votes = opt['voteCount'] ?? 0;
            final double percent = totalVotes == 0 ? 0 : votes / totalVotes;
            
            if (_hasVoted) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(opt['text'], style: const TextStyle(fontSize: 13)),
                        Text("${(percent * 100).toStringAsFixed(0)}%", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 6,
                        backgroundColor: Colors.grey[100],
                        color: Colors.blueAccent,
                      ),
                    ),
                  ],
                ),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: InkWell(
                  onTap: () => _vote(opt['_id']),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.radio_button_unchecked, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Text(opt['text'], style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  ),
                ),
              );
            }
          }).toList(),
          
          if (_hasVoted)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text("$totalVotes votes", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}