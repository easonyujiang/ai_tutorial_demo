import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tutorial_service.dart';

class LoadingScreen extends StatefulWidget {
  final TutorialService service;
  final String sessionId;

  const LoadingScreen({super.key, required this.service, required this.sessionId});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  late AnimationController _pulseCtrl;
  Timer? _timer;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _startPolling();
  }

  void _startPolling() {
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_progress < 0.95) {
          _progress += 0.015;
        }
      });
    });

    widget.service.waitForReady(widget.sessionId).then((_) {
      if (!mounted) return;
      _timer?.cancel();
      setState(() {
        _progress = 1.0;
        _done = true;
      });
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    }).catchError((e) {
      if (!mounted) return;
      _timer?.cancel();
      Navigator.of(context).pop(false);
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
    // --- UI 完全保持原样式 ---
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
                  Text(
                    _done ? '分析完成！' : '正在生成教程步骤...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
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
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
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
