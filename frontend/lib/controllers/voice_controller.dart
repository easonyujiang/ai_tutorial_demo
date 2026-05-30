import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../services/chat_service.dart';
import '../services/voice_service.dart';

class VoiceController extends ChangeNotifier {
  final VoiceService _voiceService;
  final ChatService _chatService;
  final Uuid _uuid = const Uuid();

  bool _isActive = false;
  WebSocket? _ws;
  StreamSubscription<Uint8List>? _audioStreamSub;
  StreamSubscription? _wsSub;
  bool _disposed = false;

  VoiceController({
    required VoiceService voiceService,
    required ChatService chatService,
  })  : _voiceService = voiceService,
        _chatService = chatService;

  bool get isActive => _isActive;

  void _emitIfAlive() {
    if (!_disposed) notifyListeners();
  }

  Future<void> toggle({
    String? sessionId,
    bool demoMode = false,
    required void Function(String) appendMessage,
    required void Function(String, String, {ChatMessageKind? kind}) updateMessage,
  }) async {
    if (_isActive) {
      await stop();
      return;
    }

    _isActive = true;
    _emitIfAlive();

    if (demoMode) {
      await _runDemoFlow(appendMessage, updateMessage);
      return;
    }

    try {
      await _voiceService.startAudioStream(demoMode: false);
    } catch (e) {
      appendMessage('语音启动失败：$e');
      _isActive = false;
      _emitIfAlive();
      return;
    }

    try {
      _ws = await _chatService.connectVoiceStream(sessionId);
    } catch (e) {
      appendMessage('语音连接失败，降级为文字模式：$e');
      _isActive = false;
      _emitIfAlive();
      return;
    }

    _wsSub = _ws!.listen(
      (data) {
        if (data is String) {
          appendMessage(data);
        }
      },
      onDone: () {
        _isActive = false;
        _emitIfAlive();
      },
      onError: (e) {
        appendMessage('语音连接异常：$e');
        _isActive = false;
        _emitIfAlive();
      },
    );
  }

  Future<void> _runDemoFlow(
    void Function(String) appendMessage,
    void Function(String, String, {ChatMessageKind? kind}) updateMessage,
  ) async {
    final demoId = _uuid.v4();
    updateMessage(demoId, '语音对话中... (演示模式)');

    try {
      await _voiceService.startAudioStream(demoMode: true);
    } catch (e) {
      updateMessage(demoId, '演示模式语音启动失败：$e');
      _isActive = false;
      _emitIfAlive();
      return;
    }

    await Future.delayed(const Duration(seconds: 2));
    if (!_isActive) return;

    updateMessage(demoId, '你好！我是 AI 教程助手。请粘贴视频链接，我会帮你解析并生成操作步骤。');

    await Future.delayed(const Duration(seconds: 2));
    _isActive = false;
    _emitIfAlive();
  }

  Future<void> stop() async {
    _isActive = false;
    _emitIfAlive();
    try {
      await _voiceService.stopAudioStream();
    } catch (_) {}
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
    _wsSub?.cancel();
    _wsSub = null;
    _audioStreamSub?.cancel();
    _audioStreamSub = null;
  }

  void disposeController() {
    _disposed = true;
    stop();
  }
}
