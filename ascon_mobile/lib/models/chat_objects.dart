class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] ?? '',
      senderId: json['sender'] ?? '',
      text: json['text'] ?? '',
      createdAt: DateTime.parse(json['createdAt']),
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
    final otherUser = participants.firstWhere(
      (user) => user['_id'] != myUserId,
      orElse: () => {'fullName': 'Unknown', 'profilePicture': null},
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