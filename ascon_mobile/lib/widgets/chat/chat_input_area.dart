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

  // ✅ SAFE FORMATTING: Prevents keyboard from closing
  void _applyFormat(String tag) {
    final text = controller.text;
    final selection = controller.selection;
    
    String newText;
    int newCursorPos;

    if (!selection.isValid || selection.start == -1) {
      newText = text + "$tag$tag";
      newCursorPos = newText.length - tag.length; 
    } else {
      final selectedText = text.substring(selection.start, selection.end);
      newText = text.replaceRange(selection.start, selection.end, "$tag$selectedText$tag");
      newCursorPos = selection.end + (tag.length * 2);
    }

    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
    
    // Call onTyping to update state/send button
    onTyping(newText);
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we should show Send or Mic
    // On Web, always show Send (Mic not supported yet)
    final bool hasText = controller.text.trim().isNotEmpty;
    final bool showSend = hasText || isRecording || kIsWeb;

    return Column(
      mainAxisSize: MainAxisSize.min, // Compact
      children: [
        // 1. Formatting Toolbar
        if (showFormatting && !isRecording)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFormatBtn(Icons.format_bold, "**", "Bold"),
                _buildFormatBtn(Icons.format_italic, "_", "Italic"),
                _buildFormatBtn(Icons.code, "`", "Monospace"),
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
                if (!isRecording) 
                  IconButton(
                    icon: Icon(Icons.add, color: primaryColor), 
                    onPressed: onAttachmentMenu,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                const SizedBox(width: 8),

                // Text Field or Recording Indicator
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : const Color(0xFFF2F4F5), 
                      borderRadius: BorderRadius.circular(24)
                    ),
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
                          cursorColor: isDark ? const Color(0xFFD4AF37) : primaryColor,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            hintText: "Message...", 
                            border: InputBorder.none,
                            hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
                            contentPadding: const EdgeInsets.symmetric(vertical: 10)
                          ),
                          textCapitalization: TextCapitalization.sentences,
                          keyboardType: TextInputType.multiline,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Send / Mic Button
                GestureDetector(
                  onTap: () {
                    // One-click response logic
                    if (isRecording) { 
                      onStopRecording(); 
                    } else if (hasText) { 
                      onSendMessage(); 
                    } else if (!kIsWeb) { 
                      onStartRecording(); 
                    }
                  },
                  child: CircleAvatar(
                    backgroundColor: primaryColor,
                    radius: 22,
                    child: Icon(
                      showSend ? Icons.send : Icons.mic, 
                      color: Colors.white, 
                      size: 20
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ✅ Button that preserves focus
  Widget _buildFormatBtn(IconData icon, String tag, String tooltip) {
    return InkWell(
      onTap: () => _applyFormat(tag),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Icon(icon, color: isDark ? Colors.white : Colors.grey[700], size: 20),
      ),
    );
  }
}