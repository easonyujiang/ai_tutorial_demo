import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../controllers/app_ui_controller.dart';
import '../controllers/voice_controller.dart';
import '../models/tutorial.dart';
import '../services/overlay_service.dart';
import '../services/tutorial_service.dart';
import 'analysis_page.dart';
import 'skill_library_page.dart';
import 'tutorial_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPermissions());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    if (!mounted) return;
    final uiCtrl = context.read<AppUiController>();
    uiCtrl.updatePermissions(checking: true);
    try {
      final overlay = await OverlayService.canDrawOverlays();
      final acc = await OverlayService.isAccessibilityEnabled();
      if (mounted) {
        uiCtrl.updatePermissions(
          overlayGranted: overlay,
          accessibilityEnabled: acc,
          checking: false,
        );
      }
    } catch (_) {
      if (mounted) {
        uiCtrl.updatePermissions(checking: false);
      }
    }
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
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('去授权')),
            ],
          ),
        );
        if (ok == true) await OverlayService.requestOverlayPermission();
      }

      final accEnabled = await OverlayService.isAccessibilityEnabled();
      if (!accEnabled && mounted) {
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('需要无障碍权限'),
            content: const Text('为了自动推进教程步骤，需要开启无障碍服务。\n\n请在下个页面中找到「frontend」并开启。'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('跳过（仅手动）')),
              FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('去开启')),
            ],
          ),
        );
        if (ok == true) {
          await OverlayService.openAccessibilitySettings();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('请在设置中开启无障碍服务后，重新点击技能')),
            );
          }
          return;
        }
      }

      if (!mounted) return;
      await voiceCtrl.stop();

      await OverlayService.startOverlay(tutorial: tutorial);

      if (!mounted) return;
      final ts = TutorialService(baseUrl: AppConfig.backendUrl);
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => TutorialScreen(sessionId: sid, tutorial: tutorial, service: ts),
        ),
      );

      if (mounted) {
        uiCtrl.clearTutorialReopenFlag();
        _checkPermissions();
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
      backgroundColor: const Color(0xFF0F0F1A),
      drawer: _buildDrawer(context),
      body: Consumer<AppUiController>(
        builder: (_, uiCtrl, child) {
          switch (uiCtrl.currentPage) {
            case MainPage.analysis:
              return AnalysisPage(onStartTutorial: _startTutorial);
            case MainPage.skillLibrary:
              return SkillLibraryPage(onStartTutorial: _startTutorial);
          }
        },
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final uiCtrl = context.watch<AppUiController>();
    final perms = uiCtrl.permissions;

    return Drawer(
      width: 280,
      child: Container(
        color: const Color(0xFF12122A),
        child: SafeArea(
          child: Column(
            children: [
              _buildDrawerHeader(),
              const Divider(color: Color(0xFF2A2A4A), height: 1),
              _buildNavItem(
                icon: Icons.auto_awesome,
                label: '解析',
                subtitle: '视频解析与教程生成',
                isSelected: uiCtrl.currentPage == MainPage.analysis,
                onTap: () {
                  uiCtrl.switchTo(MainPage.analysis);
                  Navigator.pop(context);
                },
              ),
              _buildNavItem(
                icon: Icons.bookmark_outline,
                label: '技能库',
                subtitle: '已保存的教程',
                isSelected: uiCtrl.currentPage == MainPage.skillLibrary,
                onTap: () {
                  uiCtrl.switchTo(MainPage.skillLibrary);
                  Navigator.pop(context);
                },
              ),
              const Spacer(),
              const Divider(color: Color(0xFF2A2A4A), height: 1),
              _buildInfoSection(perms),
              _buildModeSection(uiCtrl),
              _buildPermissionSection(perms),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('AI 教程助手', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
              Text('v2.0.0', style: TextStyle(color: Color(0xFF6A6A9A), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF667EEA).withAlpha(30) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF667EEA) : const Color(0xFF6A6A9A), size: 22),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                Text(subtitle, style: const TextStyle(color: Color(0xFF5A5A8A), fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection(PermissionStatus perms) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('说明', style: TextStyle(color: Color(0xFF8A8AB0), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 8),
          const Text(
            '粘贴视频链接，AI 自动分析关键帧并生成分步操作教程。支持抖音、B站、YouTube。',
            style: TextStyle(color: Color(0xFF6A6A9A), fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSection(AppUiController uiCtrl) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        children: [
          const Text('模式', style: TextStyle(color: Color(0xFF8A8AB0), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: uiCtrl.isDemoMode ? const Color(0xFFF97316).withAlpha(25) : const Color(0xFF22C55E).withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: uiCtrl.isDemoMode ? const Color(0xFFF97316).withAlpha(60) : const Color(0xFF22C55E).withAlpha(60)),
            ),
            child: Text(
              uiCtrl.isDemoMode ? '演示' : '在线',
              style: TextStyle(color: uiCtrl.isDemoMode ? const Color(0xFFF97316) : const Color(0xFF22C55E), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSection(PermissionStatus perms) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('权限状态', style: TextStyle(color: Color(0xFF8A8AB0), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
          const SizedBox(height: 8),
          if (perms.checking)
            const Row(children: [SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF6A6A9A))), SizedBox(width: 8), Text('检测中...', style: TextStyle(color: Color(0xFF6A6A9A), fontSize: 12))])
          else ...[
            _permRow('悬浮窗', perms.overlayGranted),
            const SizedBox(height: 6),
            _permRow('无障碍', perms.accessibilityEnabled),
          ],
        ],
      ),
    );
  }

  Widget _permRow(String label, bool granted) {
    return Row(
      children: [
        Icon(granted ? Icons.check_circle : Icons.cancel, size: 14, color: granted ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Color(0xFF8A8AB0), fontSize: 12)),
        const Spacer(),
        Text(granted ? '已授权' : '未授权', style: TextStyle(color: granted ? const Color(0xFF22C55E) : const Color(0xFFEF4444), fontSize: 11)),
      ],
    );
  }
}
