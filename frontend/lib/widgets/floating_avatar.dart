import 'package:flutter/material.dart';
import '../controllers/app_ui_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/voice_controller.dart';
import '../models/tutorial.dart';
import 'chat_panel.dart';

class FloatingAvatar extends StatefulWidget {
  final AppUiController uiController;
  final ChatController chatController;
  final VoiceController voiceController;
  final Future<void> Function(Tutorial tutorial, String? sessionId) onStartTutorial;

  const FloatingAvatar({
    super.key,
    required this.uiController,
    required this.chatController,
    required this.voiceController,
    required this.onStartTutorial,
  });

  @override
  State<FloatingAvatar> createState() => _FloatingAvatarState();
}

class _FloatingAvatarState extends State<FloatingAvatar> {
  late Offset _position;

  @override
  void initState() {
    super.initState();
    _position = widget.uiController.avatarPosition;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _position = Offset(
        MediaQuery.of(context).size.width - 72,
        MediaQuery.of(context).padding.top + 100,
      );
      widget.uiController.updateAvatarPosition(_position);
    });
  }

  @override
  Widget build(BuildContext context) {
    final panelOpen = widget.uiController.panelOpen;

    if (panelOpen) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => widget.uiController.closePanel(),
              child: Container(color: Colors.black.withAlpha(80)),
            ),
          ),
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 60,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.88,
                height: MediaQuery.of(context).size.height * 0.65,
                child: ChatPanel(
                  chatController: widget.chatController,
                  voiceController: widget.voiceController,
                  onStartTutorial: widget.onStartTutorial,
                  onCloseRequested: () => widget.uiController.closePanel(),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position.dx + details.delta.dx).clamp(0, MediaQuery.of(context).size.width - 56),
              (_position.dy + details.delta.dy).clamp(
                MediaQuery.of(context).padding.top + 12,
                MediaQuery.of(context).size.height - 156,
              ),
            );
          });
          widget.uiController.updateAvatarPosition(_position);
        },
        child: Material(
          elevation: 6,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: () => widget.uiController.openPanel(),
            customBorder: const CircleBorder(),
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.smart_toy, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
