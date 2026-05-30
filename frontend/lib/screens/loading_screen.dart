import 'dart:async';
import 'package:flutter/material.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  String _stageText = '正在解析视频链接...';
  int _stageIndex = 0;
  late AnimationController _pulseCtrl;
  Timer? _timer;

  static const _stages = [
    _Stage(label: '正在解析视频链接...', progress: 0.20),
    _Stage(label: '正在下载视频...', progress: 0.45),
    _Stage(label: 'AI 正在分析操作步骤...', progress: 0.80),
    _Stage(label: '正在生成引导层...', progress: 1.0),
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _startStagedProgress();
  }

  void _startStagedProgress() {
    final tickMs = 120;
    _timer = Timer.periodic(Duration(milliseconds: tickMs), (timer) {
      if (!mounted) { timer.cancel(); return; }

      final currentStage = _stages[_stageIndex];
      final incr = currentStage.progress / (currentStage.progress * 1000 / tickMs).clamp(1, 100);

      setState(() {
        _progress += incr;
        if (_progress >= currentStage.progress) {
          _progress = currentStage.progress;
          _stageIndex++;
          if (_stageIndex >= _stages.length) {
            _progress = 1.0;
            _stageText = _stages.last.label;
            timer.cancel();
            Future<void>.delayed(const Duration(milliseconds: 400), () {
              if (mounted) Navigator.of(context).pop(true);
            });
            return;
          }
          _stageText = _stages[_stageIndex].label;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF42A5F5), Color(0xFFE3F2FD)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _pulseCtrl,
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: 40),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      _stageText,
                      key: ValueKey(_stageText),
                      textScaleFactor: 1.0,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 14,
                        backgroundColor: Colors.white30,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '${(_progress * 100).toInt()}%',
                      key: ValueKey((_progress * 100).toInt()),
                      textScaleFactor: 1.0,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stage {
  final String label;
  final double progress;
  const _Stage({required this.label, required this.progress});
}
