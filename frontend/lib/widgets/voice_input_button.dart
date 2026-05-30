import 'package:flutter/material.dart';

class VoiceInputButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onToggle;

  const VoiceInputButton({
    super.key,
    required this.isActive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.red : const Color(0xFF667EEA);

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(30),
          border: Border.all(color: color.withAlpha(100), width: 1.5),
        ),
        child: Icon(
          isActive ? Icons.mic : Icons.keyboard_voice,
          color: color,
          size: 24,
        ),
      ),
    );
  }
}
