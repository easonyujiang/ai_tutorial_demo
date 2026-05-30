import 'package:flutter/material.dart';
import '../models/tutorial.dart';
import '../services/tutorial_service.dart';
import '../services/overlay_service.dart';

class TutorialScreen extends StatefulWidget {
  final TutorialService service;
  final String sessionId;
  final Tutorial tutorial;

  const TutorialScreen({
    super.key,
    required this.service,
    required this.sessionId,
    required this.tutorial,
  });

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int _currentIndex = 0;
  late Size _screenSize;
  bool _loading = false;
  String _currentTarget = '';
  String _currentPageDesc = '';

  @override
  void initState() {
    super.initState();
    _executeCurrentStep();
  }

  Future<void> _executeCurrentStep() async {
    setState(() => _loading = true);
    try {
      final execData = await widget.service.executeStep(widget.sessionId);
      if (!mounted) return;
      if (execData.completed) {
        _showCompleteDialog();
        return;
      }
      setState(() {
        _currentTarget = execData.targetText;
        _currentPageDesc = execData.pageDescription;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载步骤失败: $e')),
      );
    }
  }

  Future<void> _confirmAndNext() async {
    setState(() => _loading = true);
    try {
      await widget.service.confirmStep(widget.sessionId, _currentIndex);
      if (!mounted) return;
      if (_currentIndex < widget.tutorial.steps.length - 1) {
        setState(() => _currentIndex++);
        _executeCurrentStep();
      } else {
        _showCompleteDialog();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('确认失败: $e')),
      );
    }
  }

  void _showCompleteDialog() {
    OverlayService.stopOverlay();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('教程完成'),
        content: const Text('太棒了！你已经完成了所有步骤。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).maybePop();
            },
            child: const Text('确定'),
          )
        ],
      ),
    );
  }

  // --- UI 部分完全保持原样式，只改了交互逻辑 ---
  @override
  Widget build(BuildContext context) {
    if (widget.tutorial.steps.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('暂无教程步骤')),
      );
    }

    final step = widget.tutorial.steps[_currentIndex];
    final displayInstruction =
        _currentTarget.isNotEmpty
            ? '${step.instruction}\n\n请查找: "$_currentTarget"'
            : step.instruction;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          _screenSize = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: _loading ? null : (_) => _confirmAndNext(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 底层深灰色占位
                Container(
                  color: const Color(0xFF2D2D2D),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '步骤 ${_currentIndex + 1}/${widget.tutorial.steps.length}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 40,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_currentPageDesc.isNotEmpty)
                          Text(
                            '当前页面: $_currentPageDesc',
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 18,
                            ),
                          ),
                        const SizedBox(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            displayInstruction,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 22,
                              height: 1.5,
                            ),
                          ),
                        ),
                        if (_loading) ...[
                          const SizedBox(height: 32),
                          const CircularProgressIndicator(color: Colors.white54),
                        ],
                      ],
                    ),
                  ),
                ),
                if (step.imageAsset.isNotEmpty)
                  Positioned.fill(
                    child: Image.asset(
                      step.imageAsset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
