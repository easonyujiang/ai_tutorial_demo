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
      id: (json['session_id'] ?? json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      steps: (json['steps'] as List?)
              ?.map((s) => TutorialStep.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const <TutorialStep>[],
    );
  }

  static List<TutorialStep> get mockSteps => const [
        TutorialStep(
          index: 0,
          instruction: '在设置主页找到「账号管理」选项，点击进入',
          targetText: '账号管理',
          pageDescription: '设置页面',
        ),
        TutorialStep(
          index: 1,
          instruction: '找到「关于小米账号」并点击',
          targetText: '关于小米账号',
          pageDescription: '账号管理页面',
        ),
        TutorialStep(
          index: 2,
          instruction: '找到「系统广告」并点击',
          targetText: '系统广告',
          pageDescription: '关于小米账号页面',
        ),
        TutorialStep(
          index: 3,
          instruction: '关闭「系统工具广告」开关',
          targetText: '系统工具广告',
          pageDescription: '系统广告页面',
        ),
      ];
}

class TutorialStep {
  final int index;
  final String instruction;
  final String targetText;
  final String pageDescription;
  final String status;

  final String imageAsset;
  final Rect relativeRect;
  final String bubbleDirection;

  const TutorialStep({
    this.index = 0,
    required this.instruction,
    this.targetText = '',
    this.pageDescription = '',
    this.status = 'pending',
    this.imageAsset = '',
    this.relativeRect = const Rect.fromLTWH(0.1, 0.2, 0.8, 0.08),
    this.bubbleDirection = 'bottom',
  });

  TutorialStep copyWith({Rect? relativeRect}) {
    return TutorialStep(
      index: index,
      instruction: instruction,
      targetText: targetText,
      pageDescription: pageDescription,
      status: status,
      imageAsset: imageAsset,
      relativeRect: relativeRect ?? this.relativeRect,
      bubbleDirection: bubbleDirection,
    );
  }

  factory TutorialStep.fromJson(Map<String, dynamic> json) {
    final rect = (json['rect'] as Map?)?.cast<String, dynamic>() ?? const {};
    final index = json['index'] as int? ?? 0;
    return TutorialStep(
      index: index,
      instruction: (json['instruction'] ?? '') as String,
      targetText: (json['target_text'] ?? '') as String,
      pageDescription: (json['page_description'] ?? '') as String,
      status: (json['status'] ?? 'pending') as String,
      imageAsset: (json['image'] ?? '') as String,
      relativeRect: Rect.fromLTWH(
        ((rect['left'] as num?)?.toDouble() ?? 0.1),
        ((rect['top'] as num?)?.toDouble() ?? 0.2),
        ((rect['width'] as num?)?.toDouble() ?? 0.8),
        ((rect['height'] as num?)?.toDouble() ?? 0.08),
      ),
      bubbleDirection: (json['bubble_dir'] ?? 'bottom') as String,
    );
  }
}

class SessionStatusData {
  final String sessionId;
  final String status;
  final String title;
  final int totalSteps;
  final int currentStep;
  final List<TutorialStep> steps;
  final String errorMessage;

  const SessionStatusData({
    required this.sessionId,
    required this.status,
    this.title = '',
    this.totalSteps = 0,
    this.currentStep = 0,
    this.steps = const [],
    this.errorMessage = '',
  });

  factory SessionStatusData.fromJson(Map<String, dynamic> json) {
    return SessionStatusData(
      sessionId: (json['session_id'] ?? '') as String,
      status: (json['status'] ?? 'error') as String,
      title: (json['title'] ?? '') as String,
      totalSteps: (json['total_steps'] as int?) ?? 0,
      currentStep: (json['current_step'] as int?) ?? 0,
      steps: (json['steps'] as List?)
              ?.map((s) => TutorialStep.fromJson(s as Map<String, dynamic>))
              .toList() ??
          const [],
      errorMessage: (json['error_message'] ?? '') as String,
    );
  }
}

class ExecuteData {
  final bool completed;
  final int stepIndex;
  final int totalSteps;
  final String instruction;
  final String targetText;
  final String pageDescription;

  const ExecuteData({
    required this.completed,
    this.stepIndex = 0,
    this.totalSteps = 0,
    this.instruction = '',
    this.targetText = '',
    this.pageDescription = '',
  });

  factory ExecuteData.fromJson(Map<String, dynamic> json) {
    return ExecuteData(
      completed: (json['completed'] as bool?) ?? false,
      stepIndex: (json['step_index'] as int?) ?? 0,
      totalSteps: (json['total_steps'] as int?) ?? 0,
      instruction: (json['instruction'] ?? '') as String,
      targetText: (json['target_text'] ?? '') as String,
      pageDescription: (json['page_description'] ?? '') as String,
    );
  }
}

class OcrBbox {
  final String text;
  final double confidence;
  final Rect rect;

  const OcrBbox({required this.text, required this.confidence, required this.rect});

  factory OcrBbox.fromJson(Map<String, dynamic> json) {
    final r = (json['rect'] as Map?)?.cast<String, dynamic>() ?? const {};
    return OcrBbox(
      text: (json['text'] ?? '') as String,
      confidence: ((json['confidence'] as num?)?.toDouble() ?? 0),
      rect: Rect.fromLTWH(
        ((r['left'] as num?)?.toDouble() ?? 0),
        ((r['top'] as num?)?.toDouble() ?? 0),
        ((r['width'] as num?)?.toDouble() ?? 0),
        ((r['height'] as num?)?.toDouble() ?? 0),
      ),
    );
  }
}

class OcrResultData {
  final int stepIndex;
  final bool found;
  final String targetText;
  final List<OcrBbox> bboxes;
  final String suggestion;

  const OcrResultData({
    required this.stepIndex,
    required this.found,
    this.targetText = '',
    this.bboxes = const [],
    this.suggestion = '',
  });

  factory OcrResultData.fromJson(Map<String, dynamic> json) {
    return OcrResultData(
      stepIndex: (json['step_index'] as int?) ?? 0,
      found: (json['found'] as bool?) ?? false,
      targetText: (json['target_text'] ?? '') as String,
      bboxes: (json['bboxes'] as List?)
              ?.map((b) => OcrBbox.fromJson(b as Map<String, dynamic>))
              .toList() ??
          const [],
      suggestion: (json['suggestion'] ?? '') as String,
    );
  }
}

class StepActionData {
  final bool ok;
  final int nextStep;

  const StepActionData({required this.ok, this.nextStep = -1});

  factory StepActionData.fromJson(Map<String, dynamic> json) {
    return StepActionData(
      ok: (json['ok'] as bool?) ?? false,
      nextStep: (json['next_step'] as int?) ?? -1,
    );
  }
}
