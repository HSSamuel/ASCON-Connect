import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/call_service.dart';
import '../services/socket_service.dart';

class CallScreen extends StatefulWidget {
  final String remoteName;
  final String remoteId;
  final bool isCaller; 
  final Map<String, dynamic>? offer; 

  const CallScreen({
    super.key,
    required this.remoteName,
    required this.remoteId,
    required this.isCaller,
    this.offer,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with SingleTickerProviderStateMixin {
  final CallService _callService = CallService();
  final SocketService _socketService = SocketService();
  late AnimationController _pulseController;
  StreamSubscription? _callSubscription;
  
  String _status = "Initializing...";
  bool _isMuted = false;
  bool _isSpeakerOn = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _setupSignalListeners();
    _initCall();
  }

  // LISTEN FOR ANSWER & ICE CANDIDATES
  void _setupSignalListeners() {
    _callSubscription = _socketService.callEvents.listen((event) async {
      final type = event['type'];
      final data = event['data'];

      if (type == 'answer_made') {
        if (widget.isCaller) {
          debugPrint("📞 Remote answered. Connecting...");
          setState(() => _status = "Connected");
          await _callService.handleAnswer(data['answer']);
        }
      } else if (type == 'ice_candidate') {
        await _callService.handleIceCandidate(data['candidate']);
      }
    });
  }

  Future<void> _initCall() async {
    // ✅ FIX: Ensure socket is connected before starting
    if (SocketService().socket == null || !SocketService().socket!.connected) {
       setState(() => _status = "Connecting to Server...");
       await SocketService().initSocket();
       // Wait up to 3 seconds for connection
       int retries = 0;
       while ((SocketService().socket == null || !SocketService().socket!.connected) && retries < 30) {
         await Future.delayed(const Duration(milliseconds: 100));
         retries++;
       }
    }

    try {
      if (widget.isCaller) {
        setState(() => _status = "Calling...");
        await _callService.startCall(widget.remoteId);
      } else {
        setState(() => _status = "Connecting...");
        if (widget.offer != null) {
          await _callService.answerCall(widget.offer!, widget.remoteId);
          setState(() => _status = "Connected"); 
        }
      }
    } catch (e) {
      debugPrint("Call Init Error: $e");
      if (mounted) {
        setState(() => _status = "Call Failed: ${e.toString()}");
      }
    }
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    _pulseController.dispose();
    _callService.endCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. PREMIUM BACKGROUND
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F3621), 
                  Color(0xFF000000), 
                ],
              ),
            ),
          ),

          // 2. MAIN CONTENT
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 1),

                // 3. PULSING AVATAR
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ScaleTransition(
                      scale: Tween(begin: 1.0, end: 1.2).animate(
                        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)
                      ),
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1B5E3A).withOpacity(0.2), 
                        ),
                      ),
                    ),
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey[800],
                        border: Border.all(color: Colors.white10, width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))
                        ],
                      ),
                      child: const Icon(Icons.person, size: 60, color: Colors.white54),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // 4. CALLER INFO
                Text(
                  widget.remoteName,
                  style: GoogleFonts.lato(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _status,
                  style: GoogleFonts.lato(
                    color: (_status.contains("Failed")) ? Colors.redAccent : Colors.white54,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.0,
                  ),
                ),

                const Spacer(flex: 2),

                // 5. CONTROL PANEL
                Padding(
                  padding: const EdgeInsets.only(bottom: 60.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Mute Button
                      _buildControlButton(
                        icon: _isMuted ? Icons.mic_off : Icons.mic,
                        label: "Mute",
                        isActive: _isMuted,
                        onTap: () {
                          setState(() => _isMuted = !_isMuted);
                          _callService.toggleMute(_isMuted);
                        },
                      ),

                      // End Call Button (Hero)
                      FloatingActionButton.large(
                        onPressed: () => Navigator.pop(context),
                        backgroundColor: Colors.redAccent,
                        elevation: 10,
                        shape: const CircleBorder(),
                        child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 36),
                      ),

                      // Speaker Button
                      _buildControlButton(
                        icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                        label: "Speaker",
                        isActive: _isSpeakerOn,
                        onTap: () {
                          setState(() => _isSpeakerOn = !_isSpeakerOn);
                          _callService.toggleSpeaker(_isSpeakerOn);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required String label, required bool isActive, required VoidCallback onTap}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(50),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.black : Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: GoogleFonts.lato(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }
}