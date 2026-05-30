import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../controllers/chat_controller.dart';
import '../controllers/voice_controller.dart';
import '../models/tutorial.dart';
import '../services/tutorial_service.dart';
import '../widgets/chat_panel.dart';

class AnalysisPage extends StatefulWidget {
  final Future<void> Function(Tutorial tutorial, String? sessionId) onStartTutorial;

  const AnalysisPage({super.key, required this.onStartTutorial});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  List<Map<String, dynamic>> _demos = [];
  bool _demosLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchDemos();
  }

  Future<void> _fetchDemos() async {
    if (_demosLoading) return;
    setState(() => _demosLoading = true);
    try {
      final service = TutorialService(baseUrl: AppConfig.backendUrl);
      final demos = await service.fetchDemos();
      if (mounted) setState(() => _demos = demos.cast<Map<String, dynamic>>());
    } catch (_) {
    } finally {
      if (mounted) setState(() => _demosLoading = false);
    }
  }

  void _startDemo(Map<String, dynamic> demo) {
    final title = (demo['title'] ?? '演示教程') as String;
    final steps = (demo['steps'] as List?)
            ?.map((s) => TutorialStep.fromJson(s as Map<String, dynamic>))
            .toList() ??
        const <TutorialStep>[];
    final tutorial = Tutorial(id: demo['id'] as String? ?? 'demo', title: title, steps: steps);
    widget.onStartTutorial(tutorial, null);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(context),
          if (_demos.isNotEmpty) _buildDemoBar(),
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
                      onStartTutorial: widget.onStartTutorial,
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

  Widget _buildDemoBar() {
    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.rocket_launch, color: Color(0xFF667EEA), size: 14),
                SizedBox(width: 4),
                Text('预分析演示（秒开）',
                    style: TextStyle(color: Color(0xFF8A8AB0), fontSize: 11)),
              ],
            ),
          ),
          Expanded(
            child: _demosLoading
                ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _demos.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 10),
                    itemBuilder: (ctx, i) {
                      final d = _demos[i];
                      final title = (d['title'] ?? '演示') as String;
                      final steps = (d['steps'] as List?)?.length ?? 0;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _startDemo(d),
                        child: Container(
                          width: 160,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E1E4A), Color(0xFF2A1A4A)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF3A3A6A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.play_circle_fill, color: Color(0xFF667EEA), size: 16),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF667EEA).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('$steps 步', style: const TextStyle(color: Color(0xFF667EEA), fontSize: 10)),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
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
}
