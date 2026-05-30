import 'package:flutter/material.dart';
import '../controllers/chat_controller.dart';
import '../controllers/voice_controller.dart';
import '../models/chat_message.dart';
import '../models/tutorial.dart';
import 'voice_input_button.dart';

class ChatPanel extends StatefulWidget {
  final ChatController chatController;
  final VoiceController voiceController;
  final Future<void> Function(Tutorial tutorial, String? sessionId) onStartTutorial;
  final VoidCallback? onCloseRequested;

  const ChatPanel({
    super.key,
    required this.chatController,
    required this.voiceController,
    required this.onStartTutorial,
    this.onCloseRequested,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.chatController.addListener(_onDataChanged);
    widget.voiceController.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    widget.chatController.removeListener(_onDataChanged);
    widget.voiceController.removeListener(_onDataChanged);
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chatController;
    final voice = widget.voiceController;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMessageList(chat)),
          _buildInputBar(chat, voice),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
            ),
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'AI 教程助手',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (widget.onCloseRequested != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70, size: 20),
              onPressed: widget.onCloseRequested,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ChatController chat, VoiceController voice) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: '粘贴视频链接或输入消息...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFBBBBBB)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _analyze(chat, voice),
            ),
          ),
          const SizedBox(width: 8),
          VoiceInputButton(
            isActive: voice.isActive,
            onToggle: () async {
              if (voice.isActive) {
                await voice.stop();
              } else {
                await voice.toggle(
                  sessionId: chat.currentSessionId,
                  demoMode: chat.currentSessionId == null,
                  appendMessage: (text) {
                    chat.addUserMessage(text);
                    chat.addAgentMessage('(语音回复) $text');
                  },
                  updateMessage: (id, text, {kind}) {
                    chat.updateMessage(id, text, kind: kind);
                  },
                );
              }
            },
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.send, size: 20, color: Color(0xFF667EEA)),
            onPressed: () => _analyze(chat, voice),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(ChatController chat) {
    if (chat.messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '输入视频链接开始解析，或点击语音按钮与我对话',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA)),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: chat.messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final message = chat.messages[index];
        return _MessageBubble(
          message: message,
          onStartTutorial: ((message.kind == ChatMessageKind.tutorialReady) ||
                  (message.kind == ChatMessageKind.error && message.metadata?['can_continue'] == true)) &&
              chat.currentTutorial != null
              ? () => widget.onStartTutorial(chat.currentTutorial!, chat.currentSessionId)
              : null,
        );
      },
    );
  }

  Future<void> _analyze(ChatController chat, VoiceController voice) async {
    final url = _textController.text.trim();
    if (url.isEmpty) {
      chat.addSystemMessage('请先粘贴视频链接。');
      return;
    }

    if (voice.isActive) {
      await voice.stop();
    }

    await chat.analyzeVideo(url);
    await Future.delayed(const Duration(milliseconds: 100));
    _scrollToBottom();
  }
}

class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback? onStartTutorial;

  const _MessageBubble({required this.message, this.onStartTutorial});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isUser = message.sender == MessageSender.user;
    final isSystem = message.sender == MessageSender.system;
    final bg = isSystem
        ? const Color(0xFFF0F0F0)
        : (isUser ? const Color(0xFF667EEA) : const Color(0xFFF0F0F0));
    final fg = isSystem
        ? const Color(0xFF666666)
        : (isUser ? Colors.white : const Color(0xFF333333));
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final borderRadius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(12),
          );

    return Column(
      crossAxisAlignment: align,
      children: [
        Row(
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              _AvatarIcon(message.sender),
            if (!isUser) const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: bg, borderRadius: borderRadius),
                child: Text(
                  message.text,
                  style: TextStyle(fontSize: 14, height: 1.5, color: fg),
                ),
              ),
            ),
            if (isUser) const SizedBox(width: 8),
            if (isUser) _AvatarIcon(message.sender),
          ],
        ),
        if (message.kind == ChatMessageKind.error && message.metadata?['detail'] != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4F4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD6D6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFD14343), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              (message.metadata?['title'] ?? '错误详情').toString(),
                              style: const TextStyle(
                                color: Color(0xFFD14343),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Icon(
                            _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            color: const Color(0xFFD14343),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_expanded) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        message.metadata?['detail'].toString() ?? '',
                        style: const TextStyle(
                          color: Color(0xFF7A2E2E),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if ((message.kind == ChatMessageKind.tutorialReady || message.metadata?['can_continue'] == true) &&
            widget.onStartTutorial != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: widget.onStartTutorial,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF667EEA),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text((message.metadata?['button_label'] ?? '开始教程').toString()),
            ),
          ),
        ],
      ],
    );
  }
}

class _AvatarIcon extends StatelessWidget {
  final MessageSender sender;
  const _AvatarIcon(this.sender);

  @override
  Widget build(BuildContext context) {
    final icon = sender == MessageSender.user ? Icons.person : Icons.smart_toy;
    final bg = sender == MessageSender.user ? const Color(0xFFEAF0FF) : const Color(0xFFF5F5F5);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(shape: BoxShape.circle, color: bg),
      child: Icon(icon, size: 16, color: const Color(0xFF667EEA)),
    );
  }
}
