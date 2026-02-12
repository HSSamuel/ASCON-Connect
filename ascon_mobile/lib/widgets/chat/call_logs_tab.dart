import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../services/api_client.dart';
import '../../services/call_history_service.dart';
import '../../screens/call_screen.dart'; 
import '../../screens/call_log_detail_screen.dart'; // ✅ Import Details Screen

class CallLogsTab extends StatefulWidget {
  const CallLogsTab({super.key});

  @override
  State<CallLogsTab> createState() => _CallLogsTabState();
}

class _CallLogsTabState extends State<CallLogsTab> {
  final ApiClient _api = ApiClient();
  bool _isLoading = true;
  
  // ✅ Stores Raw Data (for deletion/clearing)
  List<Map<String, dynamic>> _rawLogs = [];
  
  // ✅ Stores Grouped Data (for display)
  List<Map<String, dynamic>> _groupedLogs = [];
  
  bool _isSelectionMode = false;
  final Set<String> _selectedGroupIds = {}; // Stores callerIds of selected groups

  @override
  void initState() {
    super.initState();
    _fetchAllLogs();
  }

  Future<void> _fetchAllLogs() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> missedCalls = [];
      try {
        final result = await _api.get('/api/notifications/my-notifications');
        if (mounted && result['success'] == true && result['data'] is List) {
          final List<dynamic> allNotes = result['data'];
          missedCalls = allNotes
              .where((n) => n['data'] != null && n['data']['type'] == 'call_incoming') 
              .map((n) {
                return {
                  'id': n['_id'], 
                  'callerId': n['data']['callerId'],
                  'callerName': n['data']['callerName'],
                  'callerPic': "", 
                  'type': 'missed',
                  'createdAt': n['createdAt'],
                  'source': 'api'
                };
              })
              .toList().cast<Map<String, dynamic>>();
        }
      } catch (e) {
        debugPrint("API Fetch Error: $e");
      }

      final List<Map<String, dynamic>> localLogs = await CallHistoryService().getLocalLogs();
      for (var log in localLogs) {
        log['source'] = 'local';
      }

      if (mounted) {
        setState(() {
          _rawLogs = [...missedCalls, ...localLogs];
          // 1. Sort Raw by Date Descending
          _rawLogs.sort((a, b) {
            DateTime dateA = DateTime.parse(a['createdAt']);
            DateTime dateB = DateTime.parse(b['createdAt']);
            return dateB.compareTo(dateA);
          });

          // 2. Group by Caller
          _groupLogs();
          
          _isLoading = false;
          _isSelectionMode = false;
          _selectedGroupIds.clear();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("Error fetching logs: $e");
    }
  }

  // ✅ GROUPING LOGIC
  void _groupLogs() {
    Map<String, Map<String, dynamic>> groups = {};

    for (var log in _rawLogs) {
      // Use callerId as key, fallback to name if ID missing
      String key = log['callerId'] ?? log['callerName'] ?? "Unknown";
      
      if (!groups.containsKey(key)) {
        groups[key] = {
          'key': key,
          'callerId': log['callerId'],
          'callerName': log['callerName'],
          'callerPic': log['callerPic'],
          'latestLog': log,
          'logs': <Map<String, dynamic>>[],
          'count': 0,
        };
      }
      
      groups[key]!['logs'].add(log);
      groups[key]!['count'] += 1;
    }

    _groupedLogs = groups.values.toList();
    // Sort groups by the date of their latest log
    _groupedLogs.sort((a, b) {
      DateTime dateA = DateTime.parse(a['latestLog']['createdAt']);
      DateTime dateB = DateTime.parse(b['latestLog']['createdAt']);
      return dateB.compareTo(dateA);
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedGroupIds.isEmpty) return;

    final confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Logs?"),
        content: Text("Delete history for ${_selectedGroupIds.length} contact(s)?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    List<String> localIdsToDelete = [];
    
    // Find all raw logs belonging to selected groups
    for (var groupKey in _selectedGroupIds) {
      // Find the group object
      final group = _groupedLogs.firstWhere((g) => g['key'] == groupKey, orElse: () => {});
      if (group.isEmpty) continue;

      final List<Map<String, dynamic>> logsInGroup = group['logs'];
      
      for (var log in logsInGroup) {
        if (log['source'] == 'local') {
          localIdsToDelete.add(log['id']);
        } else if (log['source'] == 'api') {
          _api.delete('/api/notifications/${log['id']}');
        }
      }
    }

    if (localIdsToDelete.isNotEmpty) {
      await CallHistoryService().deleteLogs(localIdsToDelete);
    }

    _fetchAllLogs();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Clear History?"),
        content: const Text("This will remove all call logs locally and from the server."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Clear All", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    await CallHistoryService().clearLocalLogs();
    
    // Bulk delete via loop (since backend doesn't have bulk endpoint yet)
    for (var log in _rawLogs) {
      if (log['source'] == 'api') {
        await _api.delete('/api/notifications/${log['id']}');
      }
    }

    _fetchAllLogs();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (_groupedLogs.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Theme.of(context).cardColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_isSelectionMode)
                  Text("${_selectedGroupIds.length} Selected", style: const TextStyle(fontWeight: FontWeight.bold))
                else
                  Text("Recent Calls", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                
                Row(
                  children: [
                    if (_isSelectionMode) ...[
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: _deleteSelected,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = false;
                            _selectedGroupIds.clear();
                          });
                        },
                      )
                    ] else
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_outlined),
                        onPressed: _clearAll,
                        tooltip: "Clear All",
                      ),
                  ],
                )
              ],
            ),
          ),

        Expanded(
          child: _groupedLogs.isEmpty 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_toggle_off, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 10),
                    Text("No call history", style: GoogleFonts.lato(color: Colors.grey)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchAllLogs,
                child: ListView.separated(
                  padding: const EdgeInsets.all(0),
                  itemCount: _groupedLogs.length,
                  separatorBuilder: (c, i) => Divider(height: 1, indent: 70, color: Colors.grey.withOpacity(0.1)),
                  itemBuilder: (context, index) {
                    final group = _groupedLogs[index];
                    final String groupKey = group['key'];
                    final bool isSelected = _selectedGroupIds.contains(groupKey);
                    
                    final latestLog = group['latestLog'];
                    final int count = group['count'];
                    final String type = latestLog['type'];

                    return Material(
                      color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.transparent,
                      child: InkWell(
                        onLongPress: () {
                          setState(() {
                            _isSelectionMode = true;
                            _selectedGroupIds.add(groupKey);
                          });
                        },
                        onTap: () {
                          if (_isSelectionMode) {
                            setState(() {
                              if (isSelected) {
                                _selectedGroupIds.remove(groupKey);
                                if (_selectedGroupIds.isEmpty) _isSelectionMode = false;
                              } else {
                                _selectedGroupIds.add(groupKey);
                              }
                            });
                          } else {
                            // ✅ NAVIGATE TO DETAILS
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => CallLogDetailScreen(
                                name: group['callerName'] ?? "Unknown",
                                avatar: group['callerPic'],
                                callerId: group['callerId'],
                                logs: (group['logs'] as List).cast<Map<String, dynamic>>(),
                              )
                            ));
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              // SELECTION CHECKBOX
                              if (_isSelectionMode)
                                Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                                  ),
                                ),

                              // AVATAR
                              _buildAvatar(group['callerPic'], group['callerName']),
                              
                              const SizedBox(width: 16),
                              
                              // DETAILS
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            group['callerName'] ?? "Unknown", 
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.lato(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)
                                          ),
                                        ),
                                        if (count > 1)
                                          Text("  ($count)", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(_getIcon(type), color: _getIconColor(type), size: 14),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDate(latestLog['createdAt']), 
                                          style: const TextStyle(color: Colors.grey, fontSize: 12)
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // ✅ CALL BUTTON (Navigate to Call Screen)
                              if (!_isSelectionMode && group['callerId'] != null)
                                IconButton(
                                  icon: const Icon(Icons.call, color: Colors.green),
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => CallScreen(
                                        isCaller: true,
                                        remoteId: group['callerId'],
                                        remoteName: group['callerName'] ?? "Unknown",
                                        remoteAvatar: group['callerPic'], 
                                      )
                                    ));
                                  },
                                )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
        ),
      ],
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
}