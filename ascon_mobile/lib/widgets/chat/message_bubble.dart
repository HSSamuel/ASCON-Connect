import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vibration/vibration.dart';
import '../../models/chat_objects.dart';
import '../../widgets/full_screen_image.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final String myUserId;
  final bool isMe;
  final bool isDark;
  final Color primaryColor;
  
  // State from Parent
  final bool isSelectionMode;
  final bool isSelected;
  final String? playingMessageId;
  final Duration currentPosition;
  final Duration totalDuration;
  final String? downloadingFileId;
  final bool isAdmin; // ✅ For Admin Privileges

  // Callbacks
  final Function(String) onSwipeReply;
  final Function(String) onToggleSelection;
  final Function(String, bool) onReply; // msgId, isLongPress
  final Function(String) onEdit;
  final Function(String) onDelete;
  final Function(String) onPlayAudio;
  final Function(String, String) onPauseAudio;
  final Function(Duration) onSeekAudio;
  final Function(String, String) onDownloadFile; // url, fileName

  const MessageBubble({
    super.key,
    required this.msg,
    required this.myUserId,
    required this.isMe,
    required this.isDark,
    required this.primaryColor,
    required this.isSelectionMode,
    required this.isSelected,
    this.playingMessageId,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.downloadingFileId,
    this.isAdmin = false,
    required this.onSwipeReply,
    required this.onToggleSelection,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onPlayAudio,
    required this.onPauseAudio,
    required this.onSeekAudio,
    required this.onDownloadFile,
  });

  @override
  Widget build(BuildContext context) {
    // Hide completely deleted messages
    if (msg.isDeleted && msg.text.contains("🚫")) {
       return Padding(
         padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
         child: Center(
           child: Text(
             msg.text, 
             style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)
           )
         ),
       );
    }

    return Dismissible(
      key: Key(msg.id),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        onSwipeReply(msg.id);
        Vibration.vibrate(duration: 50);
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(Icons.reply_rounded, color: isDark ? Colors.white70 : Colors.grey[700]),
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () {
            // ✅ Allow Admin to Long Press ANY message
            if (!isMe && !isAdmin && !isSelectionMode) return; 
            _showOptionsSheet(context);
          },
          onTap: () {
            if (isSelectionMode) onToggleSelection(msg.id); // Allow both to select
          },
          child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected 
                  ? primaryColor.withOpacity(0.5) 
                  : (isMe ? primaryColor : (isDark ? const Color(0xFF2C2C2C) : Colors.white)),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                if (!isSelected)
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ ADMIN / SENDER VISUALS
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, right: 10, top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          msg.senderName ?? "Member",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            // Gold Color for Admins
                            color: isAdmin ? Colors.amber[800] : (isDark ? Colors.tealAccent : primaryColor),
                          ),
                        ),
                        if (isAdmin)
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Icon(Icons.verified_user, size: 12, color: Colors.amber[800]),
                          ),
                      ],
                    ),
                  ),

                // Reply Preview
                if (msg.replyToId != null) _buildReplyPreview(),

                // Content
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildMessageContent(context),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (msg.isEdited) const Text("edited • ", style: TextStyle(fontSize: 10, color: Colors.white70)),
                          Text(DateFormat('h:mm a').format(msg.createdAt.toLocal()), style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey)),
                          if (isMe) ...[const SizedBox(width: 4), _buildStatusIcon()],
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showOptionsSheet(BuildContext context) {
    showModalBottomSheet(context: context, builder: (c) => Wrap(
      children: [
        ListTile(leading: const Icon(Icons.reply), title: const Text("Reply"), onTap: () { Navigator.pop(c); onReply(msg.id, false); }),
        
        // Only sender can edit
        if (isMe && msg.type == 'text') 
          ListTile(leading: const Icon(Icons.edit), title: const Text("Edit"), onTap: () { Navigator.pop(c); onEdit(msg.id); }),
        
        // ✅ ADMIN DELETE: Shows for Sender OR Group Admin
        if (isMe || isAdmin)
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red), 
            title: Text(isAdmin && !isMe ? "Delete (Admin)" : "Delete", style: const TextStyle(color: Colors.red)), 
            onTap: () { Navigator.pop(c); onDelete(msg.id); }
          ),
      ],
    ));
  }

  Widget _buildReplyPreview() {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(8),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: isMe ? Colors.white : primaryColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(msg.replyToSenderName ?? "User", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isMe ? Colors.white70 : primaryColor)),
          const SizedBox(height: 2),
          Text(msg.replyToType == 'text' ? (msg.replyToText ?? "") : "Media Attachment", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: isMe ? Colors.white60 : Colors.grey[700])),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (msg.type == 'image') {
      if (msg.localBytes != null) return _buildImage(Image.memory(msg.localBytes!, height: 200, width: 200, fit: BoxFit.cover), context);
      if (msg.fileUrl != null && !msg.fileUrl!.startsWith('http')) return _buildImage(Image.file(File(msg.fileUrl!), height: 200, width: 200, fit: BoxFit.cover), context);
      return _buildImage(CachedNetworkImage(imageUrl: msg.fileUrl!, height: 200, fit: BoxFit.cover), context);
    }
    
    if (msg.type == 'audio') {
      bool isPlaying = playingMessageId == msg.id;
      return Container(width: 200, padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
        GestureDetector(
          onTap: () {
             if (isPlaying) { onPauseAudio(msg.id, msg.fileUrl!); } 
             else { onPlayAudio(msg.fileUrl!); }
          }, 
          child: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 36, color: isMe ? Colors.white : primaryColor)
        ), 
        Expanded(child: Slider(
          value: isPlaying ? currentPosition.inSeconds.toDouble() : 0.0, 
          max: isPlaying ? totalDuration.inSeconds.toDouble() : 1.0, 
          activeColor: isMe ? Colors.white : primaryColor, 
          inactiveColor: isMe ? Colors.white38 : Colors.grey[300], 
          onChanged: (val) { if(isPlaying) onSeekAudio(Duration(seconds: val.toInt())); }
        ))
      ]));
    }

    if (msg.type == 'file') {
      bool isDownloading = downloadingFileId == msg.id;
      return Container(
        padding: const EdgeInsets.all(10), 
        decoration: BoxDecoration(color: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[200], borderRadius: BorderRadius.circular(8)), 
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(onTap: () => onDownloadFile(msg.fileUrl!, msg.fileName ?? "Doc"), child: Icon(Icons.description, color: isMe ? Colors.white : primaryColor, size: 30)), 
          const SizedBox(width: 8), 
          Flexible(child: GestureDetector(
            onTap: () => onDownloadFile(msg.fileUrl!, msg.fileName ?? "Doc"), 
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(msg.fileName ?? "Document", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.white : Colors.black87, decoration: TextDecoration.underline)), 
              const SizedBox(height: 2), 
              Text(isDownloading ? "Downloading..." : "Tap to open", style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.grey))
            ])
          )), 
          if (isDownloading) const Padding(padding: EdgeInsets.only(left: 8.0), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
        ])
      );
    }

    return Text.rich(TextSpan(children: _parseFormattedText(msg.text, TextStyle(color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87), fontSize: 15))));
  }

  Widget _buildImage(Widget imageWidget, BuildContext context) {
    return GestureDetector(
      onTap: () { if (msg.fileUrl != null) Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(imageUrl: msg.fileUrl!, heroTag: msg.id))); },
      child: Hero(tag: msg.id, child: ClipRRect(borderRadius: BorderRadius.circular(8), child: imageWidget))
    );
  }

  Widget _buildStatusIcon() {
    IconData icon; Color color;
    switch (msg.status) {
      case MessageStatus.sending: icon = Icons.access_time; color = Colors.white70; break;
      case MessageStatus.error: icon = Icons.error_outline; color = Colors.redAccent; break;
      case MessageStatus.read: icon = Icons.done_all; color = Colors.lightBlueAccent; break;
      default: icon = msg.isRead ? Icons.done_all : Icons.check; color = msg.isRead ? Colors.lightBlueAccent : Colors.white70; break;
    }
    return Icon(icon, size: 14, color: color);
  }

  List<TextSpan> _parseFormattedText(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final RegExp exp = RegExp(r'([*_~])(.*?)\1'); 
    text.splitMapJoin(exp, onMatch: (Match m) {
        final String marker = m.group(1)!; final String content = m.group(2)!;
        TextStyle newStyle = baseStyle;
        if (marker == '*') newStyle = newStyle.copyWith(fontWeight: FontWeight.bold);
        if (marker == '_') newStyle = newStyle.copyWith(fontStyle: FontStyle.italic);
        if (marker == '~') newStyle = newStyle.copyWith(decoration: TextDecoration.underline);
        spans.add(TextSpan(text: content, style: newStyle));
        return '';
      }, onNonMatch: (String s) { spans.add(TextSpan(text: s, style: baseStyle)); return ''; },
    );
    return spans;
  }
}