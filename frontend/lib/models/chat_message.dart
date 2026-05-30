enum MessageSender { user, agent, system }

enum ChatMessageKind { text, tutorialReady, loading, error }

class ChatMessage {
  final String id;
  final MessageSender sender;
  final String text;
  final DateTime timestamp;
  final ChatMessageKind kind;
  final Map<String, dynamic>? metadata;

  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.kind = ChatMessageKind.text,
    this.metadata,
  });
}
