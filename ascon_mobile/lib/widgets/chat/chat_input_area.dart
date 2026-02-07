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

  // ✅ NEW: Helper to insert text formatting and maintain focus
  void _applyFormat(String tag) {
    final text = controller.text;
    final selection = controller.selection;
    
    String newText;
    int newCursorPos;

    // 1. If invalid selection (lost focus), insert at end
    if (!selection.isValid || selection.start == -1) {
      newText = text + "$tag$tag";
      newCursorPos = newText.length - tag.length; // Place cursor inside tags
    } 
    // 2. If valid selection range (text highlighted)
    else {
      final selectedText = text.substring(selection.start, selection.end);
      newText = text.replaceRange(
        selection.start, 
        selection.end, 
        "$tag$selectedText$tag"
      );
      newCursorPos = selection.end + (tag.length * 2); // Cursor after closing tag
    }

    // 3. Update Controller
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );

    // 4. ✅ CRITICAL FIX: Re-request focus to keep keyboard open
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
  }

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
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFormatBtn(Icons.format_bold, "**", "Bold"),
                _buildFormatBtn(Icons.format_italic, "_", "Italic"),
                _buildFormatBtn(Icons.code, "`", "Code"),
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

  // ✅ NEW: Uses IconButton instead of GestureDetector for better click feedback
  Widget _buildFormatBtn(IconData icon, String tag, String tooltip) {
    return IconButton(
      icon: Icon(icon, color: isDark ? Colors.white : Colors.black87),
      tooltip: tooltip,
      onPressed: () => _applyFormat(tag),
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
    );
  }
}