import 'dart:typed_data'; // ✅ Needed for Uint8List

enum MessageStatus { sending, sent, delivered, read, error }

class ChatMessage {
  final String id;
  final String senderId;
  String text; 
  final DateTime createdAt;
  
  final String type; // 'text', 'image', 'audio', 'file'
  final String? fileUrl;
  final String? fileName;
  
  // ✅ NEW: Store file bytes for Web support
  final Uint8List? localBytes; 
  
  bool isDeleted;
  bool isEdited;
  bool isRead; 
  MessageStatus status; 

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.type = 'text',
    this.fileUrl,
    this.fileName,
    this.localBytes, // ✅ Initialize
    this.isDeleted = false,
    this.isEdited = false,
    this.isRead = false,
    this.status = MessageStatus.sent,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: json['sender'] ?? '',
      text: json['text'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now(),
      type: json['type'] ?? 'text',
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      isDeleted: json['isDeleted'] ?? false,
      isEdited: json['isEdited'] ?? false,
      isRead: json['isRead'] ?? false,
      status: MessageStatus.sent, 
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'sender': senderId,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'type': type,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'isDeleted': isDeleted,
      'isEdited': isEdited,
      'isRead': isRead,
      // Note: We do NOT save localBytes to cache/JSON
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
    
    var otherUser = participants.firstWhere(
      (user) => user['_id'].toString() != myUserId, 
      orElse: () => null,
    );

    if (otherUser == null && participants.isNotEmpty) {
      otherUser = participants[0];
    }

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