import 'package:flutter/material.dart';
import '../models/tutorial.dart';
import '../widgets/step_overlay.dart';

class TutorialScreen extends StatefulWidget {
  final Tutorial tutorial;
  const TutorialScreen({super.key, required this.tutorial});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  int _currentIndex = 0;
  late Size _screenSize;

  void _onScreenTap(Offset globalPosition) {
    final step = widget.tutorial.steps[_currentIndex];
    final hitRect = Rect.fromLTWH(
      step.relativeRect.left * _screenSize.width,
      step.relativeRect.top * _screenSize.height,
      step.relativeRect.width * _screenSize.width,
      step.relativeRect.height * _screenSize.height,
    );

    if (hitRect.contains(globalPosition)) {
      if (_currentIndex < widget.tutorial.steps.length - 1) {
        setState(() => _currentIndex++);
      } else {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('教程完成'),
            content: const Text('太棒了！你已经完成了所有步骤。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              )
            ],
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请点击高亮区域完成操作')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.tutorial.steps[_currentIndex];
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          _screenSize = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) => _onScreenTap(details.localPosition),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 底层：用深灰色占位容器代替截图
                Container(
                  color: const Color(0xFF2D2D2D),
                  child: Center(
                    child: Text(
                      '步骤${_currentIndex + 1}',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 40,
                      ),
                    ),
                  ),
                ),
                // 覆盖层
                StepOverlay(
                  screenSize: _screenSize,
                  relativeRect: step.relativeRect,
                  instruction: step.instruction,
                  bubbleDirection: step.bubbleDirection,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}