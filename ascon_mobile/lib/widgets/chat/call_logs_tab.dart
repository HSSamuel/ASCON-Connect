import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';
import '../../screens/call_screen.dart';

class CallLogsTab extends StatefulWidget {
  const CallLogsTab({super.key});

  @override
  State<CallLogsTab> createState() => _CallLogsTabState();
}

class _CallLogsTabState extends State<CallLogsTab> {
  final ApiClient _api = ApiClient();
  bool _isLoading = true;
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // ✅ FETCH CENTRALIZED LOGS FROM BACKEND API
      final res = await _api.get('/api/calls');
      
      if (res['success'] == true) {
        if (mounted) {
          setState(() {
            _logs = res['data'];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching call logs: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteLog(String id) async {
    try {
      // Optimistic UI Update
      setState(() {
        _logs.removeWhere((l) => l['_id'] == id);
      });
      // Send Delete Request
      await _api.delete('/api/calls/$id');
    } catch (e) {
      debugPrint("Delete error: $e");
      // Re-fetch if fails
      _fetchLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text("No call history", style: GoogleFonts.lato(color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchLogs,
      child: ListView.separated(
        itemCount: _logs.length,
        separatorBuilder: (c, i) => Divider(height: 1, indent: 70, color: Colors.grey.withOpacity(0.1)),
        itemBuilder: (context, index) {
          final log = _logs[index];
          // Types mapped from backend: 'dialed', 'received', 'missed'
          final String type = log['type'] ?? 'dialed'; 
          
          return Dismissible(
            key: Key(log['_id']),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => _deleteLog(log['_id']),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: _buildAvatar(log['remotePic'], log['remoteName']),
              title: Text(
                log['remoteName'] ?? "Unknown",
                style: GoogleFonts.lato(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: type == 'missed' ? Colors.red : Theme.of(context).textTheme.bodyLarge?.color
                ),
              ),
              subtitle: Row(
                children: [
                  Icon(_getIcon(type), color: _getIconColor(type), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(log['createdAt']), 
                    style: const TextStyle(fontSize: 12, color: Colors.grey)
                  ),
                  if (log['duration'] != null && log['duration'] > 0)
                    Text(
                      " • ${_formatDuration(log['duration'])}", 
                      style: const TextStyle(fontSize: 12, color: Colors.grey)
                    ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.call, color: Colors.green),
                onPressed: () {
                  // Redial Logic
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CallScreen(
                      isCaller: true,
                      remoteId: log['remoteId'],
                      remoteName: log['remoteName'] ?? "User",
                      remoteAvatar: log['remotePic'], 
                    )
                  ));
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(String? url, String? name) {
    if (url != null && url.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: CachedNetworkImageProvider(url),
        backgroundColor: Colors.grey[200],
      );
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey[200],
      child: Text(
        (name ?? "?").substring(0, 1).toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[600]),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'missed': return Icons.call_missed;
      case 'dialed': return Icons.call_made;
      case 'received': return Icons.call_received;
      default: return Icons.call;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'missed': return Colors.red;
      case 'dialed': return Colors.blue;
      case 'received': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _formatDate(String? iso) {
    if (iso == null) return "";
    try {
      final date = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      
      if (now.difference(date).inDays == 0 && now.day == date.day) {
        return DateFormat('h:mm a').format(date);
      } else if (now.difference(date).inDays == 1) {
        return "Yesterday";
      }
      return DateFormat('MMM d').format(date);
    } catch (e) {
      return "";
    }
  }

  String _formatDuration(dynamic duration) {
    int seconds = 0;
    if (duration is int) seconds = duration;
    if (duration is double) seconds = duration.toInt();

    final d = Duration(seconds: seconds);
    if (d.inMinutes > 0) {
      return "${d.inMinutes}m ${d.inSeconds % 60}s";
    }
    return "${d.inSeconds}s";
  }
}