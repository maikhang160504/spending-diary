import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
                itemCount: MockData.chatMessages.length,
                itemBuilder: (context, index) {
                  final message = MockData.chatMessages[index];
                  return _ChatBubble(message: message);
                },
              ),
            ),
            _ChatComposer(),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.xl),
          bottomRight: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: const Text('😎', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chat voi Mimo', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                    const SizedBox(height: 2),
                    Text('AI assistant co the thuc hien actions', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.chatHistory),
                icon: const Icon(Icons.history, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              _ActionChip(label: 'Bao cao'),
              SizedBox(width: 8),
              _ActionChip(label: 'Muc tieu'),
              SizedBox(width: 8),
              _ActionChip(label: 'Ngan sach'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;

  const _ActionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white)),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = message.isUser ? AppColors.teal : Colors.white;
    final textColor = message.isUser ? Colors.white : AppColors.textPrimary;
    final alignment = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Container(
          margin: EdgeInsets.only(bottom: AppSpacing.md, left: message.isUser ? 60 : 0, right: message.isUser ? 0 : 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadii.lg),
              topRight: const Radius.circular(AppRadii.lg),
              bottomLeft: Radius.circular(message.isUser ? AppRadii.lg : 4),
              bottomRight: Radius.circular(message.isUser ? 4 : AppRadii.lg),
            ),
            boxShadow: message.isUser
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 6,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor)),
              const SizedBox(height: 6),
              Text(message.time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor.withValues(alpha: 0.7))),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatComposer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.add_circle_outline, color: AppColors.teal)),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Nhap tin nhan...',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.teal,
            child: IconButton(onPressed: () {}, icon: const Icon(Icons.send, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}