import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/tutorial.dart';
import '../services/chat_service.dart';
import '../services/tutorial_service.dart';

class ChatController extends ChangeNotifier {
  final ChatService _chatService;
  final TutorialService _tutorialService;
  final Uuid _uuid = const Uuid();

  String? _currentSessionId;
  Tutorial? _currentTutorial;
  final List<ChatMessage> _messages = [];
  Timer? _pollTimer;
  bool _disposed = false;
  WebSocket? _voiceSocket;

  ChatController({
    required ChatService chatService,
    required TutorialService tutorialService,
  })  : _chatService = chatService,
        _tutorialService = tutorialService;

  String? get currentSessionId => _currentSessionId;
  Tutorial? get currentTutorial => _currentTutorial;
  List<ChatMessage> get messages => _messages;

  void _emitIfAlive() {
    if (!_disposed) notifyListeners();
  }

  void addMessage(ChatMessage message) {
    _messages.add(message);
    _emitIfAlive();
  }

  void addUserMessage(String text) {
    addMessage(ChatMessage(
      id: _uuid.v4(),
      sender: MessageSender.user,
      text: text,
      timestamp: DateTime.now(),
    ));
  }

  void addAgentMessage(String text) {
    addMessage(ChatMessage(
      id: _uuid.v4(),
      sender: MessageSender.agent,
      text: text,
      timestamp: DateTime.now(),
    ));
  }

  void addSystemMessage(String text) {
    addMessage(ChatMessage(
      id: _uuid.v4(),
      sender: MessageSender.system,
      text: text,
      timestamp: DateTime.now(),
    ));
  }

  void updateMessage(String id, String text, {ChatMessageKind? kind}) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1) return;
    _messages[index] = ChatMessage(
      id: id,
      sender: _messages[index].sender,
      text: text,
      timestamp: _messages[index].timestamp,
      kind: kind ?? _messages[index].kind,
      metadata: _messages[index].metadata,
    );
    _emitIfAlive();
  }

  void appendToMessage(String id, String text) {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1) return;
    final old = _messages[index];
    _messages[index] = ChatMessage(
      id: old.id,
      sender: old.sender,
      text: old.text + text,
      timestamp: old.timestamp,
      kind: old.kind,
      metadata: old.metadata,
    );
    _emitIfAlive();
  }

  Future<void> analyzeVideo(String url) async {
    addUserMessage(url);
    final loadingId = _uuid.v4();
    addMessage(ChatMessage(
      id: loadingId,
      sender: MessageSender.system,
      text: '正在解析视频...',
      timestamp: DateTime.now(),
      kind: ChatMessageKind.loading,
    ));

    try {
      final sessionId = await _tutorialService.createSession(url);
      _currentSessionId = sessionId;

      final ready = await _tutorialService.waitForReady(sessionId);
      updateMessage(loadingId, ready ? '视频解析完成！' : '视频解析超时，请重试。',
          kind: ready ? ChatMessageKind.tutorialReady : ChatMessageKind.error);

      if (ready) {
        final status = await _tutorialService.getStatus(sessionId);
        _currentTutorial = Tutorial(
          id: sessionId,
          title: status.title,
          steps: status.steps,
        );
        addMessage(ChatMessage(
          id: _uuid.v4(),
          sender: MessageSender.agent,
          text: '教程 "${status.title}" 已就绪，共 ${status.steps.length} 个步骤。点击下方按钮开始。',
          timestamp: DateTime.now(),
          kind: ChatMessageKind.tutorialReady,
        ));
      }
    } catch (e) {
      updateMessage(loadingId, '解析失败：$e');
    }
  }

  Future<String?> sendTextMessage(String text) async {
    try {
      final reply = await _chatService.sendTextMessage(
        text.trim(),
        _currentSessionId,
      );
      addAgentMessage(reply);
      return reply;
    } catch (e) {
      addSystemMessage('消息发送失败，请重试：$e');
      return null;
    }
  }

  void setVoiceSocket(WebSocket? socket) {
    _voiceSocket = socket;
  }

  WebSocket? get voiceSocket => _voiceSocket;

  void stopAll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void disposeController() {
    _disposed = true;
    _pollTimer?.cancel();
    _pollTimer = null;
    try {
      _voiceSocket?.close();
    } catch (_) {}
    _voiceSocket = null;
  }
}
