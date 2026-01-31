import 'dart:typed_data'; // ✅ FIXED Typo: Changed from dart:typed_material

enum MessageStatus { sending, sent, delivered, read, error }

class ChatMessage {
  final String id;
  final String senderId;
  String text; 
  final DateTime createdAt;
  
  final String type; // 'text', 'image', 'audio', 'file'
  final String? fileUrl;
  final String? fileName;
  
  // Store file bytes for Web support
  final Uint8List? localBytes; 
  
  // Reply Data (for Swipe-to-Reply)
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderName;
  final String? replyToType; // 'text', 'image', etc.
  
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
    this.localBytes, 
    this.replyToId,
    this.replyToText,
    this.replyToSenderName,
    this.replyToType,
    this.isDeleted = false,
    this.isEdited = false,
    this.isRead = false,
    this.status = MessageStatus.sent,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    String? rId;
    String? rText;
    String? rSender;
    String? rType;

    if (json['replyTo'] != null) {
      if (json['replyTo'] is Map) {
        rId = json['replyTo']['_id'];
        rText = json['replyTo']['text'];
        rType = json['replyTo']['type'];
        if (json['replyTo']['sender'] is Map) {
           rSender = json['replyTo']['sender']['fullName'];
        }
      } else {
        rId = json['replyTo'].toString();
      }
    }

    return ChatMessage(
      id: json['_id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: (json['sender'] is Map) ? json['sender']['_id'] : json['sender'] ?? '',
      text: json['text'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now(),
      type: json['type'] ?? 'text',
      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      replyToId: rId,
      replyToText: rText,
      replyToSenderName: rSender,
      replyToType: rType,
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
      'replyTo': replyToId != null ? {
        '_id': replyToId,
        'text': replyToText,
        'type': replyToType,
        'sender': {'fullName': replyToSenderName}
      } : null,
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
  
  bool isOnline;
  String? lastSeen;

  ChatConversation({
    required this.id,
    required this.otherUserName,
    this.otherUserImage,
    this.otherUserId,
    required this.lastMessage,
    required this.lastMessageTime,
    this.isOnline = false,
    this.lastSeen,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json, String myUserId) {
    final participants = (json['participants'] as List?) ?? []; // ✅ Safe null check
    
    // ✅ Safe search for the other participant
    var otherUser = participants.firstWhere(
      (user) => user != null && user['_id'].toString() != myUserId, 
      orElse: () => null,
    );

    // Fallback if the other user isn't found
    if (otherUser == null && participants.isNotEmpty) {
      otherUser = participants[0];
    }

    final String name = otherUser?['fullName'] ?? 'Alumni Member';
    final String? image = otherUser?['profilePicture'];
    final String? uid = otherUser?['_id'];
    
    final bool online = otherUser?['isOnline'] ?? false;
    final String? seen = otherUser?['lastSeen']?.toString();

    return ChatConversation(
      id: json['_id'] ?? '',
      otherUserName: name,
      otherUserImage: image,
      otherUserId: uid,
      lastMessage: json['lastMessage'] ?? 'Start a conversation',
      lastMessageTime: DateTime.tryParse(json['lastMessageAt']?.toString() ?? '') ?? DateTime.now(),
      isOnline: online,
      lastSeen: seen,
    );
  }
}