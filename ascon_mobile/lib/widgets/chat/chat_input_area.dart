import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../models/chat_objects.dart';

class ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final Color primaryColor;
  final bool isRecording;
  final int recordDuration;
  final bool showFormatting;
  
  // Reply/Edit Context
  final ChatMessage? replyingTo;
  final ChatMessage? editingMessage;
  final String myUserId;

  // Callbacks
  final VoidCallback onCancelReply;
  final VoidCallback onCancelEdit;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;
  final VoidCallback onSendMessage;
  final VoidCallback onAttachmentMenu;
  final Function(String) onTyping;

  const ChatInputArea({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.primaryColor,
    required this.isRecording,
    required this.recordDuration,
    required this.showFormatting,
    this.replyingTo,
    this.editingMessage,
    required this.myUserId,
    required this.onCancelReply,
    required this.onCancelEdit,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
    required this.onSendMessage,
    required this.onAttachmentMenu,
    required this.onTyping,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. Formatting Toolbar
        if (showFormatting && !isRecording)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            child: Row(
              children: [
                _buildFormatBtn(Icons.format_bold, "*", isDark),
                const SizedBox(width: 8),
                _buildFormatBtn(Icons.format_italic, "_", isDark),
                const SizedBox(width: 8),
                _buildFormatBtn(Icons.format_underlined, "~", isDark),
              ],
            ),
          ),

        // 2. Reply/Edit Preview
        if (replyingTo != null || editingMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            child: Row(
              children: [
                Icon(editingMessage != null ? Icons.edit : Icons.reply, color: primaryColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        editingMessage != null ? "Editing Message" : "Replying to ${replyingTo!.senderId == myUserId ? 'Yourself' : 'User'}",
                        style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
                      ),
                      Text(
                        editingMessage != null ? editingMessage!.text : (replyingTo!.type == 'text' ? replyingTo!.text : "Media"),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20), 
                  onPressed: editingMessage != null ? onCancelEdit : onCancelReply
                )
              ],
            ),
          ),

        // 3. Main Input Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: SafeArea(
            child: Row(
              children: [
                // Attach Button
                if (!isRecording || kIsWeb) 
                  IconButton(icon: Icon(Icons.add, color: primaryColor), onPressed: onAttachmentMenu),
                
                // Text Field or Recording Indicator
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: isDark ? Colors.grey[900] : const Color(0xFFF2F4F5), borderRadius: BorderRadius.circular(24)),
                    child: isRecording 
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                          children: [
                            const Icon(Icons.mic, color: Colors.red, size: 20), 
                            Text("Recording... ${recordDuration ~/ 60}:${(recordDuration % 60).toString().padLeft(2, '0')}", style: const TextStyle(fontWeight: FontWeight.bold)), 
                            TextButton(onPressed: onCancelRecording, child: const Text("Cancel", style: TextStyle(color: Colors.red)))
                          ]
                        )
                      : TextField(
                          controller: controller, 
                          focusNode: focusNode,
                          maxLines: 4, minLines: 1,
                          onChanged: onTyping,
                          decoration: const InputDecoration(hintText: "Message...", border: InputBorder.none),
                          textCapitalization: TextCapitalization.sentences,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Send / Mic Button
                CircleAvatar(
                  backgroundColor: primaryColor,
                  child: IconButton(
                    icon: Icon((controller.text.trim().isNotEmpty || isRecording || kIsWeb) ? Icons.send : Icons.mic, color: Colors.white, size: 20),
                    onPressed: () {
                      if (isRecording) { onStopRecording(); }
                      else if (controller.text.trim().isNotEmpty) { onSendMessage(); }
                      else if (!kIsWeb) { onStartRecording(); }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatBtn(IconData icon, String char, bool isDark) {
    return GestureDetector(
      onTap: () {
        final text = controller.text;
        final selection = controller.selection;
        if (!selection.isValid || selection.start == -1) {
          controller.value = TextEditingValue(text: text + "$char$char", selection: TextSelection.collapsed(offset: text.length + 1));
        } else {
          final newText = text.replaceRange(selection.start, selection.end, "$char${text.substring(selection.start, selection.end)}$char");
          controller.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: selection.end + 2));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: isDark ? Colors.grey[700] : Colors.grey[300], borderRadius: BorderRadius.circular(4)),
        child: Icon(icon, size: 18, color: isDark ? Colors.white : Colors.black87),
      ),
    );
  }
}