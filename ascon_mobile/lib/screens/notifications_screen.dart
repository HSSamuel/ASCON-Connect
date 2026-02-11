import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../services/api_client.dart';
// import '../config/theme.dart'; // No longer strictly needed as we use Theme.of(context)

// ✅ Provider to fetch notifications
final notificationsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ApiClient();
  // Ensure the backend route is now '/' in 'backend/routes/notifications.js'
  final result = await api.get('/api/notifications'); 
  
  if (result['success'] == true) {
    // result['data'] is the HTTP Response Body (Map) containing { success: true, data: [...] }
    final body = result['data'];
    
    // We need to return the inner 'data' list
    if (body is Map && body.containsKey('data') && body['data'] is List) {
      return body['data'];
    }
  }
  return [];
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final theme = Theme.of(context); // ✅ Get theme context

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        centerTitle: true,
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("No notifications yet", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final note = notifications[index];
              final isMissedCall = note['title']?.contains("Missed Call") ?? false;
              final date = DateTime.tryParse(note['createdAt'] ?? '') ?? DateTime.now();

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isMissedCall ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                  child: Icon(
                    isMissedCall ? Icons.phone_missed : Icons.notifications,
                    // ✅ FIXED: Use Theme.of(context).primaryColor instead of AppTheme.primaryColor
                    color: isMissedCall ? Colors.red : theme.primaryColor,
                  ),
                ),
                title: Text(
                  note['title'] ?? "Notification",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(note['message'] ?? ""),
                    const SizedBox(height: 4),
                    Text(
                      timeago.format(date),
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                  ],
                ),
                onTap: () {
                  // Handle tap (e.g., mark as read or navigate)
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text("Error: $err")),
      ),
    );
  }
}