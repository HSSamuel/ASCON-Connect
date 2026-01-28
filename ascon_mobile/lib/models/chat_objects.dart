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
  
  // ✅ NEW: Status for UI feedback
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

  // ✅ NEW: For Local Caching (SharedPrefs)
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
    final otherUser = participants.firstWhere(
      (user) => user['_id'] != myUserId,
      orElse: () => {'fullName': 'Unknown', 'profilePicture': null, '_id': null},
    );

    return ChatConversation(
      id: json['_id'] ?? '',
      otherUserName: otherUser['fullName'] ?? 'Alumni Member',
      otherUserImage: otherUser['profilePicture'],
      otherUserId: otherUser['_id'],
      lastMessage: json['lastMessage'] ?? 'Start a conversation',
      lastMessageTime: DateTime.parse(json['lastMessageAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}