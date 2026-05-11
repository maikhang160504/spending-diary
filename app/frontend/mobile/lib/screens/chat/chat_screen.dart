import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
            _ChatHeader(context: context),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
                itemCount: MockData.chatMessages.length,
                itemBuilder: (context, index) {
                  return _ChatBubble(message: MockData.chatMessages[index]);
                },
              ),
            ),
            // Quick action chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: const [
                    _QuickChip(label: 'Tuần này sao?'),
                    SizedBox(width: 8),
                    _QuickChip(label: 'Tổng chi tiêu'),
                    SizedBox(width: 8),
                    _QuickChip(label: 'Mục tiêu của tôi'),
                  ],
                ),
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
  final BuildContext context;

  const _ChatHeader({required this.context});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.xl),
          bottomRight: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(ctx),
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('😎', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Chat với Mimo', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                Text('AI Assistant có thể thực hiện actions', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.white70)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.chatHistory),
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.access_time, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;

  const _QuickChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
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
                : const [BoxShadow(color: Color(0x12000000), blurRadius: 6, offset: Offset(0, 4))],
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
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, -4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Nhắn tin cho Mimo...',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.send, color: AppColors.teal, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}