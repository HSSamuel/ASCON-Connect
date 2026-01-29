// ✅ Enum for Optimistic UI
enum MessageStatus { sending, sent, delivered, read, error }

class ChatMessage {
  final String id;
  final String senderId;
  String text; 
  final DateTime createdAt;
  
  final String type; // 'text', 'image', 'audio', 'file'
  final String? fileUrl;
  bool isDeleted;
  bool isEdited;
  bool isRead; 
  
  // ✅ Status for UI feedback
  MessageStatus status; 

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.type = 'text',
    this.fileUrl,
    this.isDeleted = false,
    this.isEdited = false,
    this.isRead = false,
    this.status = MessageStatus.sent, // Default to sent for incoming
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(), // Fallback for temp IDs
      senderId: json['sender'] ?? '',
      text: json['text'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now(),
      type: json['type'] ?? 'text',
      fileUrl: json['fileUrl'],
      isDeleted: json['isDeleted'] ?? false,
      isEdited: json['isEdited'] ?? false,
      isRead: json['isRead'] ?? false,
      status: MessageStatus.sent, 
    );
  }

  // ✅ For Local Caching (SharedPrefs)
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'sender': senderId,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'type': type,
      'fileUrl': fileUrl,
      'isDeleted': isDeleted,
      'isEdited': isEdited,
      'isRead': isRead,
    };
  }
}

class ChatConversation {
  final String id;
  final String otherUserName;
  final String? otherUserImage;
  final String? otherUserId;
  final String lastMessage;
  final DateTime lastMessageTime;

  ChatConversation({
    required this.id,
    required this.otherUserName,
    this.otherUserImage,
    this.otherUserId,
    required this.lastMessage,
    required this.lastMessageTime,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json, String myUserId) {
    final participants = (json['participants'] as List).toList();
    
    // ✅ FIX: Improved Logic to find the "Other" user
    var otherUser = participants.firstWhere(
      (user) => user['_id'].toString() != myUserId, // Convert to string for safe comparison
      orElse: () => null,
    );

    // ✅ FALLBACK: If we couldn't find an "other" user (e.g. self-chat), use the first participant
    if (otherUser == null && participants.isNotEmpty) {
      otherUser = participants[0];
    }

    // ✅ FINAL SAFETY CHECK: Ensure we don't display "Unknown" if data is missing
    final String name = otherUser?['fullName'] ?? 'Alumni Member';
    final String? image = otherUser?['profilePicture'];
    final String? uid = otherUser?['_id'];

    return ChatConversation(
      id: json['_id'] ?? '',
      otherUserName: name,
      otherUserImage: image,
      otherUserId: uid,
      lastMessage: json['lastMessage'] ?? 'Start a conversation',
      lastMessageTime: DateTime.parse(json['lastMessageAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}