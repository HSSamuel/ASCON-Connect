class ChatMessage {
  final String id;
  final String senderId;
  String text; // ✅ Not final so we can update it locally when editing
  final DateTime createdAt;
  
  // ✅ NEW FIELDS: Support for WhatsApp-style features
  final String type; // 'text', 'image', 'audio', 'file'
  final String? fileUrl;
  bool isDeleted;
  bool isEdited;
  bool isRead; // ✅ Added Read Status

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.type = 'text',
    this.fileUrl,
    this.isDeleted = false,
    this.isEdited = false,
    this.isRead = false, // ✅ Default to false
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] ?? '',
      senderId: json['sender'] ?? '',
      text: json['text'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
      type: json['type'] ?? 'text',
      fileUrl: json['fileUrl'],
      isDeleted: json['isDeleted'] ?? false,
      isEdited: json['isEdited'] ?? false,
      isRead: json['isRead'] ?? false, // ✅ Map from API
    );
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

  // Helper to parse the complex Conversation object from API
  factory ChatConversation.fromJson(Map<String, dynamic> json, String myUserId) {
    // Find the participant that is NOT me
    final participants = (json['participants'] as List).toList();
    
    // Handle edge case where user might be deleted or null
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