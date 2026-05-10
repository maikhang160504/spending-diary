import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final alignment = message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = message.isUser ? AppColors.teal : AppColors.card;
    final textColor = message.isUser ? Colors.white : AppColors.textPrimary;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Text(message.text, style: TextStyle(color: textColor)),
      ),
    );
  }
}
