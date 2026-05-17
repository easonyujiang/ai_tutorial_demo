import 'package:flutter/material.dart';
import 'instruction_bubble.dart';

class StepOverlay extends StatelessWidget {
  final Size screenSize;
  final Rect relativeRect;   // 0~1 比例
  final String instruction;
  final String bubbleDirection;

  const StepOverlay({
    super.key,
    required this.screenSize,
    required this.relativeRect,
    required this.instruction,
    required this.bubbleDirection,
  });

  @override
  Widget build(BuildContext context) {
    final r = Rect.fromLTWH(
      relativeRect.left * screenSize.width,
      relativeRect.top * screenSize.height,
      relativeRect.width * screenSize.width,
      relativeRect.height * screenSize.height,
    );

    return Stack(
      children: [
        // 四块遮罩留出目标区域
        // 上
        Positioned(
          top: 0, left: 0, right: 0,
          height: r.top,
          child: Container(color: Colors.black54),
        ),
        // 下
        Positioned(
          top: r.bottom, left: 0, right: 0, bottom: 0,
          child: Container(color: Colors.black54),
        ),
        // 左
        Positioned(
          top: r.top, bottom: r.bottom, left: 0,
          width: r.left,
          child: Container(color: Colors.black54),
        ),
        // 右
        Positioned(
          top: r.top, bottom: r.bottom, right: 0,
          width: screenSize.width - r.right,
          child: Container(color: Colors.black54),
        ),
        // 高亮边框
        Positioned.fromRect(
          rect: r,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.blueAccent, width: 2.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        // 提示气泡
        InstructionBubble(
          targetRect: r,
          screenSize: screenSize,
          text: instruction,
          direction: bubbleDirection,
        ),
      ],
    );
  }
}