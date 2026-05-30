import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/chat_controller.dart';
import '../controllers/voice_controller.dart';
import '../models/tutorial.dart';
import '../widgets/chat_panel.dart';

class AnalysisPage extends StatelessWidget {
  final Future<void> Function(Tutorial tutorial, String? sessionId) onStartTutorial;

  const AnalysisPage({super.key, required this.onStartTutorial});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 8),
          Expanded(
            child: Consumer2<ChatController, VoiceController>(
              builder: (_, chat, voice, child) {
                return Container(
                  margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A35),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF2A2A4A)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: ChatPanel(
                      chatController: chat,
                      voiceController: voice,
                      onStartTutorial: onStartTutorial,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF8A8AB0)),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('视频解析', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              Text('粘贴链接，AI 生成操作教程', style: TextStyle(color: Color(0xFF6A6A9A), fontSize: 11)),
            ],
          ),
          const Spacer(),
          _buildStatusDot(),
        ],
      ),
    );
  }

  Widget _buildStatusDot() {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF22C55E)),
    );
  }
}
