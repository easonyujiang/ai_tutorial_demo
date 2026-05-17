import 'dart:ui';

class Tutorial {
  final String id;
  final String title;
  final List<TutorialStep> steps;

  const Tutorial({
    required this.id,
    required this.title,
    required this.steps,
  });

  factory Tutorial.fromJson(Map<String, dynamic> json) {
    return Tutorial(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      steps: (json['steps'] as List?)
              ?.map((s) => TutorialStep.fromJson(s))
              .toList() ??
          [],
    );
  }
}

class TutorialStep {
  final String imageAsset;       // 暂时不用真实图片，用颜色代替
  final String instruction;
  final Rect relativeRect;       // 0~1 比例矩形
  final String bubbleDirection;  // 'top','bottom','left','right'

  const TutorialStep({
    required this.imageAsset,
    required this.instruction,
    required this.relativeRect,
    this.bubbleDirection = 'top',
  });

  factory TutorialStep.fromJson(Map<String, dynamic> json) {
    return TutorialStep(
      imageAsset: json['image'] ?? '',
      instruction: json['instruction'] ?? '',
      relativeRect: Rect.fromLTWH(
        (json['rect']?['left'] as num?)?.toDouble() ?? 0,
        (json['rect']?['top'] as num?)?.toDouble() ?? 0,
        (json['rect']?['width'] as num?)?.toDouble() ?? 0,
        (json['rect']?['height'] as num?)?.toDouble() ?? 0,
      ),
      bubbleDirection: json['bubble_dir'] ?? 'top',
    );
  }
}