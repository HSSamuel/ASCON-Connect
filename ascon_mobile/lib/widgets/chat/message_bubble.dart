import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';

import '../../models/chat_objects.dart';
import '../full_screen_image.dart'; // Ensure this exists

class MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final String myUserId;
  final bool isMe;
  final bool isDark;
  final Color primaryColor;
  final bool isSelectionMode;
  final bool isSelected;
  final String? playingMessageId;
  final Duration currentPosition;
  final Duration totalDuration;
  final String? downloadingFileId;
  final bool isAdmin;
  // ✅ FIX: Added this parameter
  final bool showSenderName;
  
  final Function(String) onSwipeReply;
  final Function(String) onToggleSelection;
  final Function(String, String) onReply;
  final Function(String) onEdit;
  final Function(String) onDelete;
  final Function(String) onPlayAudio;
  final Function(String, String) onPauseAudio;
  final Function(Duration) onSeekAudio;
  final Function(String, String) onDownloadFile;

  const MessageBubble({
    super.key, required this.msg, required this.myUserId, required this.isMe, required this.isDark, required this.primaryColor,
    required this.isSelectionMode, required this.isSelected, required this.playingMessageId, required this.currentPosition, required this.totalDuration,
    required this.downloadingFileId, required this.isAdmin, required this.showSenderName,
    required this.onSwipeReply, required this.onToggleSelection, required this.onReply, required this.onEdit, required this.onDelete,
    required this.onPlayAudio, required this.onPauseAudio, required this.onSeekAudio, required this.onDownloadFile
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a').format(msg.createdAt);
    final statusIcon = msg.status == MessageStatus.sending ? Icons.access_time : (msg.isRead ? Icons.done_all : Icons.check);
    final statusColor = msg.status == MessageStatus.sending ? Colors.grey : (msg.isRead ? Colors.blue : Colors.grey);

    return Dismissible(
      key: Key(msg.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (d) async { onSwipeReply(msg.id); return false; },
      background: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), color: Colors.transparent, child: Icon(Icons.reply, color: primaryColor)),
      child: GestureDetector(
        onLongPress: () => onToggleSelection(msg.id),
        onTap: () { if (isSelectionMode) onToggleSelection(msg.id); },
        child: Container(
          color: isSelected ? primaryColor.withOpacity(0.2) : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (showSenderName && !isMe)
                    Padding(padding: const EdgeInsets.only(left: 12, bottom: 4), child: Text(msg.senderName ?? "User", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange[800]))),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: isMe 
                          ? LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.85)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                          : null,
                      color: isMe ? null : (isDark ? Colors.grey[800] : Colors.white),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: isMe ? const Radius.circular(18) : const Radius.circular(4),
                        bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(18),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (msg.replyToId != null) 
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: isMe ? Colors.white : primaryColor, width: 4))),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(msg.replyToSenderName ?? "Reply", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)), Text(msg.replyToText ?? "Message", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))]),
                          ),
                        
                        if (msg.fileUrl != null || msg.localBytes != null)
                           _buildMediaContent(context),

                        if (msg.text.isNotEmpty)
                          Text(msg.text, style: GoogleFonts.lato(fontSize: 15, color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87))),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4, left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(time, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                        if (isMe) ...[const SizedBox(width: 4), Icon(statusIcon, size: 12, color: statusColor)],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaContent(BuildContext context) {
    if (msg.type == 'image') {
      return GestureDetector(
        onTap: () {
           if (msg.fileUrl != null) Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(imageUrl: msg.fileUrl!, heroTag: msg.id)));
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: msg.localBytes != null 
              ? Image.memory(msg.localBytes!, fit: BoxFit.cover)
              : CachedNetworkImage(imageUrl: msg.fileUrl!, placeholder: (c, u) => const CircularProgressIndicator(), errorWidget: (c, u, e) => const Icon(Icons.broken_image)),
        ),
      );
    }
    return const SizedBox.shrink(); 
  }
}