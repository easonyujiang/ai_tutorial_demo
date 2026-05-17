import 'package:flutter/material.dart';
import '../data/demo_tutorials.dart';
import '../services/overlay_service.dart';
import 'loading_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onAnalyze() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请粘贴视频链接', textScaleFactor: 1.0),
        ),
      );
      return;
    }

    final canDraw = await OverlayService.canDrawOverlays();
    if (!canDraw) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要悬浮窗权限', textScaleFactor: 1.0),
          content: const Text(
            '为了在系统设置上显示引导层，需要授予「显示在其他应用上层」的权限。',
            textScaleFactor: 1.0,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消', textScaleFactor: 1.0),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('去授权', textScaleFactor: 1.0),
            ),
          ],
        ),
      );
      if (ok == true) {
        await OverlayService.requestOverlayPermission();
      }
      return;
    }

    final accEnabled = await OverlayService.isAccessibilityEnabled();
    if (!accEnabled) {
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('需要无障碍权限', textScaleFactor: 1.0),
          content: const Text(
            '为了自动推进教程步骤，需要开启无障碍服务。\n\n请在下个页面中找到「frontend」并开启。',
            textScaleFactor: 1.0,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('跳过（仅手动）', textScaleFactor: 1.0),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('去开启', textScaleFactor: 1.0),
            ),
          ],
        ),
      );
      if (ok == true) {
        await OverlayService.openAccessibilitySettings();
      }
    }

    if (!mounted) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoadingScreen()),
    );

    if (result == true && mounted) {
      try {
        await OverlayService.startOverlay(tutorial: DemoTutorials.adTutorial);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启动失败：$e', textScaleFactor: 1.0)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF42A5F5),
      body: SafeArea(
        child: Center(
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
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF42A5F5),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'AI 教程助手',
                  textScaleFactor: 1.0,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        color: Color(0x40000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '粘贴视频链接，AI 解析操作步骤\n在您的真实界面上叠加引导',
                  textScaleFactor: 1.0,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFE3F2FD),
                    fontSize: 20,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: _controller,
                  enabled: !_isLoading,
                  style: const TextStyle(
                    fontSize: 20,
                    color: Color(0xFF1A237E),
                  ),
                  decoration: InputDecoration(
                    hintText: '粘贴视频链接',
                    hintStyle: const TextStyle(
                      color: Color(0xFF90CAF9),
                      fontSize: 20,
                    ),
                    prefixIcon: const Icon(
                      Icons.link,
                      color: Color(0xFF42A5F5),
                      size: 28,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                        color: Color(0xFF1565C0),
                        width: 2.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                  ),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _onAnalyze(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _onAnalyze,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color(0xFF42A5F5),
                            ),
                          )
                        : const Icon(Icons.analytics_outlined, size: 30),
                    label: Text(
                      _isLoading ? '正在启动...' : '分析',
                      textScaleFactor: 1.0,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1565C0),
                      disabledBackgroundColor: Colors.white54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
