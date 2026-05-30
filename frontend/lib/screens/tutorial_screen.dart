import 'package:flutter/material.dart';
import '../models/tutorial.dart';
import '../services/overlay_service.dart';
import '../services/tutorial_service.dart';
import '../widgets/step_overlay.dart';

class TutorialScreen extends StatefulWidget {
  final String sessionId;
  final Tutorial tutorial;
  final TutorialService? service;

  const TutorialScreen({
    super.key,
    required this.sessionId,
    required this.tutorial,
    this.service,
  });

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int _currentIndex = 0;
  Size? _screenSize;
  bool _loading = false;
  String _currentTarget = '';
  String _currentPageDesc = '';
  late final TutorialService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? MockTutorialService();
    _executeCurrentStep();
  }

  Future<bool> _confirmExit() async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('退出教程'),
            content: const Text('确定要退出当前教程吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('继续教程'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('退出'),
              ),
            ],
          ),
        )) ??
        false;
  }

  Future<void> _onExit() async {
    if (!await _confirmExit()) return;
    await OverlayService.stopOverlay();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _executeCurrentStep() async {
    setState(() => _loading = true);
    try {
      final execData = await _service.executeStep(widget.sessionId);
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
    if (_screenSize == null) return;
    setState(() => _loading = true);
    try {
      await _service.confirmStep(widget.sessionId, _currentIndex);
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

  @override
  Widget build(BuildContext context) {
    if (widget.tutorial.steps.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('暂无教程步骤')),
      );
    }

    final step = widget.tutorial.steps[_currentIndex];
    String displayInstruction;
    if (_currentTarget.isNotEmpty) {
      displayInstruction = '${step.instruction}\n\n请查找: "$_currentTarget"';
    } else if (step.targetDescription.isNotEmpty) {
      displayInstruction = '${step.instruction}\n\n🎯 目标位置: ${step.targetDescription}';
    } else {
      displayInstruction = step.instruction;
    }

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
                if (_screenSize != null && step.relativeRect != Rect.zero)
                  StepOverlay(
                    screenSize: _screenSize!,
                    relativeRect: step.relativeRect,
                    instruction: displayInstruction,
                    bubbleDirection: step.bubbleDirection,
                  )
                else
                  Container(
                    color: const Color(0xFF2D2D2D),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '步骤 ${_currentIndex + 1}/${widget.tutorial.steps.length}',
                            style: const TextStyle(color: Colors.white54, fontSize: 40),
                          ),
                          const SizedBox(height: 16),
                          if (_currentPageDesc.isNotEmpty)
                            Text(
                              '当前页面: $_currentPageDesc',
                              style: const TextStyle(color: Colors.white38, fontSize: 18),
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
                if (_loading)
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const CircularProgressIndicator(
                          color: Colors.blue,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  right: 16,
                  child: Material(
                    color: Colors.black.withAlpha(115),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _onExit,
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.close, color: Colors.white, size: 24),
                      ),
                    ),
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
