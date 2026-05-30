import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/app_ui_controller.dart';
import '../controllers/chat_controller.dart';
import '../controllers/voice_controller.dart';
import '../models/tutorial.dart';
import '../services/overlay_service.dart';
import '../widgets/floating_avatar.dart';
import 'tutorial_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    final uiCtrl = context.read<AppUiController>();
    if (uiCtrl.panelOpen) {
      uiCtrl.closePanel();
      return false;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出应用？'),
        content: const Text('确定要退出 AI 教程助手吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      SystemNavigator.pop();
    }
    return false;
  }

  Future<void> _startTutorial(Tutorial tutorial, String? sessionId) async {
    final sid = sessionId ?? tutorial.id;
    final uiCtrl = context.read<AppUiController>();
    final voiceCtrl = context.read<VoiceController>();

    try {
      final canDraw = await OverlayService.canDrawOverlays();
      if (!canDraw && mounted) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('需要悬浮窗权限'),
            content: const Text('为了在系统设置上显示引导层，需要授予「显示在其他应用上层」的权限。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('去授权'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await OverlayService.requestOverlayPermission();
        }
      }

      final accEnabled = await OverlayService.isAccessibilityEnabled();
      if (!accEnabled && mounted) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('需要无障碍权限'),
            content: const Text(
              '为了自动推进教程步骤，需要开启无障碍服务。\n\n请在下个页面中找到「frontend」并开启。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('跳过（仅手动）'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('去开启'),
              ),
            ],
          ),
        );
        if (ok == true) {
          await OverlayService.openAccessibilitySettings();
        }
      }

      if (!mounted) return;

      final reopenPanel = uiCtrl.panelOpen;
      uiCtrl.markReopenAfterTutorial(reopenPanel);
      uiCtrl.closePanel();
      await voiceCtrl.stop();

      await OverlayService.startOverlay(tutorial: tutorial);

      if (!mounted) return;
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => TutorialScreen(
            sessionId: sid,
            tutorial: tutorial,
          ),
        ),
      );

      if (!mounted) return;
      if (uiCtrl.reopenPanelAfterTutorial && result != false) {
        uiCtrl.openPanel();
        uiCtrl.clearTutorialReopenFlag();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('启动失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        children: [
          Center(
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'AI 教程助手',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '点击右上角头像开始对话\n粘贴视频链接，AI 帮你生成操作教程',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB0B0D0),
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Consumer<AppUiController>(
                      builder: (_, uiCtrl, __) {
                        if (uiCtrl.panelOpen) return const SizedBox.shrink();
                        return SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: () => uiCtrl.openPanel(),
                            icon: const Icon(Icons.chat_bubble_outline, size: 24),
                            label: const Text('打开对话', style: TextStyle(fontSize: 18)),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF667EEA),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          FloatingAvatar(
            uiController: context.watch<AppUiController>(),
            chatController: context.watch<ChatController>(),
            voiceController: context.watch<VoiceController>(),
            onStartTutorial: _startTutorial,
          ),
        ],
      ),
    );
  }
}
