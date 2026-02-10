import 'package:flutter/foundation.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:flutter_riverpod/flutter_riverpod.dart'; // ✅ RIVERPOD
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart'; 

import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart'; 
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart'; 

import '../services/api_client.dart'; 
import '../viewmodels/chat_detail_view_model.dart'; // ✅ VM
import '../models/chat_objects.dart';
import '../config.dart';
import '../config/storage_config.dart';
import '../utils/presence_formatter.dart';
import 'group_info_screen.dart'; 

import '../widgets/full_screen_image.dart';
import '../widgets/chat/poll_creation_sheet.dart';
import '../widgets/active_poll_card.dart';
import '../widgets/chat/message_bubble.dart'; 
import '../widgets/chat/chat_input_area.dart'; 

class ChatScreen extends ConsumerStatefulWidget {
  final String? conversationId;
  final String receiverId;
  final String receiverName;
  final String? receiverProfilePic;
  final bool isOnline;
  final String? lastSeen;
  final bool isGroup; 
  final String? groupId; 

  const ChatScreen({
    super.key,
    this.conversationId,
    required this.receiverId,
    required this.receiverName,
    this.receiverProfilePic,
    this.isOnline = false,
    this.lastSeen,
    this.isGroup = false, 
    this.groupId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final FocusNode _focusNode = FocusNode(); 

  late AudioRecorder _audioRecorder;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  Timer? _typingDebounce;

  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _playingMessageId; 
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  bool _isSelectionMode = false;
  final Set<String> _selectedMessageIds = {};
  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;

  String? _downloadingFileId;

  // ✅ PROVIDER ACCESS
  AutoDisposeStateNotifierProvider<ChatDetailNotifier, ChatDetailState> get _provider => chatDetailProvider({
    'receiverId': widget.receiverId,
    'isGroup': widget.isGroup,
    'groupId': widget.groupId,
    'conversationId': widget.conversationId,
    'isOnline': widget.isOnline,
    'lastSeen': widget.lastSeen,
  });

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _setupAudioPlayerListeners();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.hasClients && _scrollController.position.pixels == 0) {
        ref.read(_provider.notifier).loadMoreMessages();
      }
    });
  }

  void _setupAudioPlayerListeners() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (state == PlayerState.completed) {
        setState(() {
          _playingMessageId = null;
          _currentPosition = Duration.zero;
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((p) => setState(() => _currentPosition = p));
    _audioPlayer.onDurationChanged.listen((d) => setState(() => _totalDuration = d));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose(); 
    _typingDebounce?.cancel();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ✅ UPDATED: Call Provider
  Future<void> _sendMessage({String? text, String? filePath, Uint8List? fileBytes, String? fileName, String type = 'text'}) async {
    // 1. Edit Message
    if (_editingMessage != null && type == 'text') {
      await ref.read(_provider.notifier).editMessage(_editingMessage!.id, text ?? "");
      setState(() {
        _editingMessage = null;
        _textController.clear();
      });
      return;
    }

    // 2. Send New Message
    final error = await ref.read(_provider.notifier).sendMessage(
      text: text, 
      filePath: filePath, 
      fileBytes: fileBytes, 
      fileName: fileName, 
      type: type, 
      replyToId: _replyingTo?.id,
      replyingToMessage: _replyingTo
    );
    
    if (!mounted) return;

    if (error == null) {
      setState(() {
        _replyingTo = null;
        _textController.clear();
      });
      _scrollToBottom();
    } else {
      // ✅ Now correctly shows error for ALL types (text, image, file)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _handleTyping(String val) {
    if (val.isNotEmpty) {
      ref.read(_provider.notifier).sendTyping();
      _typingDebounce?.cancel();
      _typingDebounce = Timer(const Duration(seconds: 2), () {
         // Optionally stop typing
      });
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // --- RECORDING ---
  Future<void> _startRecording() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Voice recording not supported on Web yet.")));
      return;
    }
    if (await Permission.microphone.request().isGranted) {
      try {
        if (await Vibration.hasVibrator() ?? false) Vibration.vibrate(duration: 50);
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() => _recordDuration++);
        });
      } catch (e) {
        debugPrint("Recording Error: $e");
      }
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    _recordTimer?.cancel();
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (send && path != null) {
      _sendMessage(filePath: path, type: 'audio');
    }
  }

  void _cancelRecording() {
    _stopRecording(send: false);
  }

  Future<void> _downloadAndOpenWith(String messageId, String url, String fileName) async {
    if (kIsWeb) {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      }
      return;
    }

    try {
      setState(() => _downloadingFileId = messageId);

      final dir = await getTemporaryDirectory();
      final safeFileName = fileName.replaceAll(RegExp(r'[^\w\s\.-]'), '_');
      final savePath = "${dir.path}/$safeFileName"; 

      final response = await http.get(Uri.parse(url));
      
      if (!mounted) return;

      if (response.statusCode == 200) {
        final file = File(savePath);
        await file.writeAsBytes(response.bodyBytes);

        final result = await OpenFile.open(savePath);
        
        if (result.type != ResultType.done) {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
               content: Text("Could not open file: ${result.message}"),
               backgroundColor: Colors.red,
             ));
           }
        }
      } else {
        throw Exception("Download failed with status: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Failed to download file."),
          backgroundColor: Colors.red,
        ));
      }
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } finally {
      if (mounted) setState(() => _downloadingFileId = null);
    }
  }

  // --- PICKERS ---
  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        _sendMessage(fileBytes: bytes, fileName: image.name, type: 'image');
      } else {
        _sendMessage(filePath: image.path, type: 'image');
      }
    }
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null) {
      if (kIsWeb) {
        PlatformFile file = result.files.first;
        if (file.bytes != null) _sendMessage(fileBytes: file.bytes, fileName: file.name, type: 'file');
      } else {
        if (result.files.single.path != null) _sendMessage(filePath: result.files.single.path!, type: 'file');
      }
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent, 
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly, 
          children: [
            _attachOption(Icons.image, Colors.purple, "Gallery", () => _pickImage(ImageSource.gallery)), 
            _attachOption(Icons.camera_alt, Colors.pink, "Camera", () => _pickImage(ImageSource.camera)), 
            _attachOption(Icons.insert_drive_file, Colors.blue, "Document", _pickFile),
            if (widget.isGroup)
              _attachOption(Icons.bar_chart_rounded, Colors.orange, "Poll", () {
                  Navigator.pop(context); 
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true, 
                    backgroundColor: Colors.transparent,
                    builder: (c) => PollCreationSheet(groupId: widget.groupId!),
                  );
              }),
          ]
        ),
      )
    );
  }
  
  Widget _attachOption(IconData icon, Color color, String label, VoidCallback onTap) {
    return Padding(padding: const EdgeInsets.all(16.0), child: GestureDetector(onTap: () { Navigator.pop(context); onTap(); }, child: Column(children: [CircleAvatar(radius: 25, backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)), const SizedBox(height: 8), Text(label, style: const TextStyle(fontSize: 12))])));
  }

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) _isSelectionMode = false;
      } else {
        _isSelectionMode = true;
        _selectedMessageIds.add(messageId);
      }
    });
  }

  Future<void> _deleteSelectedMessages() async {
    final idsToDelete = _selectedMessageIds.toList();
    await ref.read(_provider.notifier).deleteMessages(idsToDelete);
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  Widget _buildDateHeader(String dateStr) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
          child: Text(dateStr, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
      ),
    );
  }

  String _getStatusText(bool isTyping, bool isOnline, String? lastSeen) {
    if (widget.isGroup) return "Group";
    if (isTyping) return "Typing...";
    if (isOnline) return "Active Now";
    if (lastSeen == null) return "Offline";
    return "Last seen ${PresenceFormatter.format(lastSeen)}";
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_provider);
    final notifier = ref.read(_provider.notifier);

    // Kicked Logic
    if (state.isKicked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (c) => AlertDialog(
              title: const Text("Access Revoked"),
              content: const Text("You have been removed from this group by an admin."),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(c);
                    Navigator.pop(context);
                  },
                  child: const Text("OK"),
                )
              ],
            ),
          );
        }
      });
    }

    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        if (_isSelectionMode) {
          setState(() { _isSelectionMode = false; _selectedMessageIds.clear(); });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.grey[900] : const Color(0xFFF2F4F7),
        appBar: _isSelectionMode 
          ? AppBar(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              leading: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _isSelectionMode = false; _selectedMessageIds.clear(); })),
              title: Text("${_selectedMessageIds.length} Selected"),
              actions: [
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _deleteSelectedMessages),
              ],
            )
          : AppBar(
            titleSpacing: 0,
            backgroundColor: Theme.of(context).cardColor,
            foregroundColor: isDark ? Colors.white : Colors.black,
            elevation: 1,
            shadowColor: Colors.black.withOpacity(0.05),
            title: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: (widget.receiverProfilePic != null && widget.receiverProfilePic!.isNotEmpty)
                      ? CachedNetworkImageProvider(widget.receiverProfilePic!)
                      : null,
                  child: (widget.receiverProfilePic == null || widget.receiverProfilePic!.isEmpty)
                      ? Text(widget.receiverName.substring(0, 1).toUpperCase(), style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.receiverName, style: GoogleFonts.lato(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (!widget.isGroup)
                      Text(
                        _getStatusText(state.isPeerTyping, state.isPeerOnline, state.peerLastSeen), 
                        style: TextStyle(fontSize: 11, color: state.isPeerOnline ? Colors.green : Colors.grey)
                      ),
                  ],
                ),
              ],
            ),
            actions: [
              if (widget.isGroup && widget.groupId != null)
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => GroupInfoScreen(groupId: widget.groupId!, groupName: widget.receiverName)));
                  },
                ),
            ],
          ),
        body: Column(
          children: [
            if (widget.isGroup && widget.groupId != null)
               ActivePollCard(groupId: widget.groupId),

            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                itemCount: state.messages.length,
                itemBuilder: (context, index) {
                  final msg = state.messages[index];
                  bool showDate = false;
                  if (index == 0) {
                    showDate = true;
                  } else {
                    final prevMsg = state.messages[index - 1];
                    if (msg.createdAt.day != prevMsg.createdAt.day || msg.createdAt.month != prevMsg.createdAt.month) {
                      showDate = true;
                    }
                  }

                  String dateLabel = "";
                  if (showDate) {
                    final now = DateTime.now();
                    final diff = now.difference(msg.createdAt).inDays;
                    if (diff == 0 && now.day == msg.createdAt.day) dateLabel = "Today";
                    else if (diff == 1) dateLabel = "Yesterday";
                    else dateLabel = DateFormat("MMM d, y").format(msg.createdAt);
                  }

                  return Column(
                    children: [
                      if (showDate) _buildDateHeader(dateLabel),
                      
                      MessageBubble(
                        msg: msg,
                        myUserId: state.myUserId,
                        isMe: msg.senderId == state.myUserId,
                        isDark: isDark,
                        primaryColor: primaryColor,
                        isSelectionMode: _isSelectionMode,
                        isSelected: _selectedMessageIds.contains(msg.id),
                        playingMessageId: _playingMessageId,
                        currentPosition: _currentPosition,
                        totalDuration: _totalDuration,
                        downloadingFileId: _downloadingFileId,
                        isAdmin: widget.isGroup && state.groupAdminIds.contains(msg.senderId),
                        
                        showSenderName: widget.isGroup && msg.senderId != state.myUserId,
                        
                        onSwipeReply: (id) {
                          setState(() { _replyingTo = msg; _editingMessage = null; });
                          _focusNode.requestFocus();
                        },
                        onToggleSelection: _toggleSelection,
                        onReply: (id, _) {
                          setState(() { _replyingTo = msg; _editingMessage = null; });
                          _focusNode.requestFocus();
                        },
                        onEdit: (id) {
                          setState(() { _editingMessage = msg; _replyingTo = null; _textController.text = msg.text; });
                          _focusNode.requestFocus();
                        },
                        onDelete: (id) { _toggleSelection(id); notifier.deleteMessages(_selectedMessageIds.toList()); setState(() => _isSelectionMode = false); },
                        onPlayAudio: (url) async {
                          if (url.startsWith('http')) { await _audioPlayer.play(UrlSource(url)); } 
                          else { await _audioPlayer.play(DeviceFileSource(url)); }
                          setState(() => _playingMessageId = msg.id);
                        },
                        onPauseAudio: (id, _) async { await _audioPlayer.pause(); setState(() => _playingMessageId = null); },
                        onSeekAudio: (pos) => _audioPlayer.seek(pos),
                        onDownloadFile: (url, name) => _downloadAndOpenWith(msg.id, url, name),
                      ),
                    ],
                  );
                },
              ),
            ),
            
            if (state.isPeerTyping) 
               const Padding(padding: EdgeInsets.only(left: 16, bottom: 4), child: Align(alignment: Alignment.centerLeft, child: Text("Typing...", style: TextStyle(color: Colors.grey, fontSize: 12)))),

            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]
              ),
              child: SafeArea(
                child: ChatInputArea(
                  controller: _textController,
                  focusNode: _focusNode,
                  isDark: isDark,
                  primaryColor: primaryColor,
                  isRecording: _isRecording,
                  recordDuration: _recordDuration,
                  replyingTo: _replyingTo,
                  editingMessage: _editingMessage,
                  myUserId: state.myUserId,
                  onCancelReply: () => setState(() => _replyingTo = null),
                  onCancelEdit: () => setState(() { _editingMessage = null; _textController.clear(); }),
                  onStartRecording: _startRecording,
                  onStopRecording: () => _stopRecording(send: true),
                  onCancelRecording: _cancelRecording,
                  onSendMessage: () => _sendMessage(text: _textController.text),
                  onAttachmentMenu: _showAttachmentMenu,
                  onTyping: _handleTyping,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}