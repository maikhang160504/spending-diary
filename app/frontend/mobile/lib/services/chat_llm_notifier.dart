import 'package:flutter/foundation.dart';

class ChatLlmUpdate {
  final String sessionId;
  final String messageId;
  final String? content;
  final String? mood;
  final bool failed;
  final Map<String, dynamic>? intentAction;

  const ChatLlmUpdate({
    required this.sessionId,
    required this.messageId,
    this.content,
    this.mood,
    this.failed = false,
    this.intentAction,
  });
}

final chatLlmUpdateNotifier = ValueNotifier<ChatLlmUpdate?>(null);

void notifyChatLlmUpdate(ChatLlmUpdate update) {
  chatLlmUpdateNotifier.value = update;
}
