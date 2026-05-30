import 'package:flutter/material.dart';

class InstructionBubble extends StatelessWidget {
  final Rect targetRect; // 目标区域的屏幕绝对坐标（像素）
  final Size screenSize;
  final String text;
  final String direction; // 'top','bottom','left','right'

  const InstructionBubble({
    super.key,
    required this.targetRect,
    required this.screenSize,
    required this.text,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    double top, left;
    const bubbleWidth = 140.0;
    const bubbleHeight = 45.0;

    switch (direction) {
      case 'top':
        top = targetRect.top - bubbleHeight - 10;
        left = targetRect.center.dx - bubbleWidth / 2;
        break;
      case 'bottom':
        top = targetRect.bottom + 10;
        left = targetRect.center.dx - bubbleWidth / 2;
        break;
      case 'left':
        top = targetRect.center.dy - bubbleHeight / 2;
        left = targetRect.left - bubbleWidth - 10;
        break;
      case 'right':
        top = targetRect.center.dy - bubbleHeight / 2;
        left = targetRect.right + 10;
        break;
      default:
        top = targetRect.top - bubbleHeight - 10;
        left = targetRect.center.dx - bubbleWidth / 2;
    }

    // 边界裁剪
    top = top.clamp(0.0, screenSize.height - bubbleHeight);
    left = left.clamp(0.0, screenSize.width - bubbleWidth);

    return Positioned(
      top: top,
      left: left,
      child: Container(
        width: bubbleWidth,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              blurRadius: 4,
              color: Colors.black.withOpacity(0.2),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.black87, fontSize: 13),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
