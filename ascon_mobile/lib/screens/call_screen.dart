import 'package:flutter/material.dart';
import '../services/call_service.dart';

class CallScreen extends StatefulWidget {
  final String remoteName;
  final String remoteId;
  final bool isCaller; // true if I initiated the call
  final Map<String, dynamic>? offer; // For incoming calls

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

class _CallScreenState extends State<CallScreen> {
  final CallService _callService = CallService();
  String _status = "Initializing...";

  @override
  void initState() {
    super.initState();
    _initCall();
  }

  Future<void> _initCall() async {
    try {
      if (widget.isCaller) {
        setState(() => _status = "Calling ${widget.remoteName}...");
        await _callService.startCall(widget.remoteId);
      } else {
        setState(() => _status = "Incoming Call from ${widget.remoteName}...");
        if (widget.offer != null) {
          // Auto-answer for now (Feature Refinement: Add Accept/Reject Buttons)
          await _callService.answerCall(widget.offer!, widget.remoteId);
          setState(() => _status = "Connected");
        }
      }
    } catch (e) {
      setState(() => _status = "Call Failed: $e");
    }
  }

  @override
  void dispose() {
    _callService.endCall();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 60, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              widget.remoteName,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              _status,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 60),
            FloatingActionButton(
              onPressed: () => Navigator.pop(context), // Hang up
              backgroundColor: Colors.red,
              child: const Icon(Icons.call_end),
            ),
          ],
        ),
      ),
    );
  }
}