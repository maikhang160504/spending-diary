import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../data/mock_data.dart';
import '../../utils/formatters.dart';
import '../../widgets/mimo_overlay.dart';

class ChatScreen extends StatefulWidget {
  /// Optional sessionId passed from ChatHistoryScreen (CHH-02)
  final String? sessionId;
  const ChatScreen({super.key, this.sessionId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiClient();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _messages = [];

  bool _aiThinking = false;
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initSession() async {
    // If sessionId passed from history, reuse it and load messages
    if (widget.sessionId != null) {
      _sessionId = widget.sessionId;
      try {
        final msgs = await _api.getChatMessages(_sessionId!);
        if (!mounted) return;
        setState(() {
          for (final m in msgs) {
            final role = m['role'] as String? ?? 'user';
            final content = m['content'] as String? ?? '';
            _messages.add(_ChatMsg(
              text: content,
              isUser: role == 'user',
              time: _formatMsgTime(m['created_at'] as String?),
            ));
          }
        });
        _scrollToBottom();
      } catch (_) {}
      return;
    }
    try {
      final session = await _api.createChatSession(title: 'Chat ${DateTime.now().day}/${DateTime.now().month}');
      _sessionId = session['id'] as String?;
    } catch (_) {}
  }

  String _formatMsgTime(String? iso) {
    if (iso == null) return _now();
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return _now();
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final userText = text.trim();
    _inputCtrl.clear();

    setState(() {
      _messages.add(_ChatMsg(text: userText, isUser: true, time: _now()));
      _aiThinking = true;
    });
    _scrollToBottom();

    // Save to backend chat
    if (_sessionId != null) {
      try { await _api.sendChatMessage(_sessionId!, userText); } catch (_) {}
    }

    // Call NLU for AI response
    try {
      final nlu = await _api.aiNlu(userText, runLlm: false);
      final intent = nlu['intent'] as String? ?? 'Chitchat';
      final amount = nlu['amount'] ?? nlu['amount_spent'];
      final category = nlu['category'] as String?;

      String replyText;
      _ChatMsg? previewCard;

      final moodRaw = nlu['mascot_mood'] as String?;

      if (intent == 'Record' && amount != null) {
        final amountInt = (amount is num) ? amount.toInt() : 0;
        replyText = '📝 Mimo hiểu bạn muốn ghi nhận chi tiêu:';
        previewCard = _ChatMsg(
          text: replyText,
          isUser: false,
          time: _now(),
          txPreview: _TxPreview(
            category: category ?? 'Other',
            amount: amountInt,
            note: nlu['clean_content'] as String? ?? userText,
          ),
        );
      } else if (intent == 'Action') {
        final actionType = nlu['action_type'] as String? ?? '';
        replyText = '⚡ Mimo nhận lệnh: $actionType. Tính năng sẽ sớm được hỗ trợ!';
      } else {
        // Chitchat — use nlg_response if available, else default
        replyText = (nlu['nlg_response'] as String?) ?? 'Mimo đây! Bạn cần gì nào? 😊';
      }

      if (!mounted) return;
      setState(() {
        _aiThinking = false;
        if (previewCard != null) {
          _messages.add(previewCard);
        } else {
          _messages.add(_ChatMsg(text: replyText, isUser: false, time: _now()));
        }
      });
      _scrollToBottom();

      // M4-02: Show mascot mood from API response
      final moodStatus = moodRaw ?? (intent == 'Record' ? 'Happy' : 'Chill');
      mimoController.show(MiMoResponse(
        status: moodStatus,
        message: replyText.length > 60 ? '${replyText.substring(0, 60)}...' : replyText,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiThinking = false;
        _messages.add(_ChatMsg(text: 'Mimo gặp lỗi rồi 😅 Thử lại sau nhé!', isUser: false, time: _now()));
      });
      _scrollToBottom();
    }
  }

  String _now() {
    final dt = DateTime.now();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
                itemCount: _messages.length + (_aiThinking ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _aiThinking) {
                    return const _TypingIndicator();
                  }
                  return _ChatBubble(message: _messages[index], onSaveTx: _saveTransaction);
                },
              ),
            ),
            // Quick action chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _QuickChip(label: 'Tuần này sao?', onTap: () => _sendMessage('Tuần này sao?')),
                  const SizedBox(width: 8),
                  _QuickChip(label: 'Tổng chi tiêu', onTap: () => _sendMessage('Tổng chi tiêu')),
                  const SizedBox(width: 8),
                  _QuickChip(label: 'Phở 50k', onTap: () => _sendMessage('Phở 50k')),
                  const SizedBox(width: 8),
                  _QuickChip(label: 'Cafe 35k', onTap: () => _sendMessage('Cafe 35k')),
                ]),
              ),
            ),
            _ChatComposer(
              controller: _inputCtrl,
              onSend: () => _sendMessage(_inputCtrl.text),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTransaction(_TxPreview preview) async {
    try {
      final wallets = await _api.getWallets();
      if (wallets.isEmpty) return;
      await _api.createTransaction({
        'walletId': wallets[0]['id'],
        'amount': preview.amount,
        'type': 'expense',
        'categoryCode': preview.category,
        'note': preview.note,
      });
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(text: '✅ Đã lưu giao dịch ${formatVnd(preview.amount)} thành công!', isUser: false, time: _now()));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(text: '❌ Không thể lưu giao dịch', isUser: false, time: _now()));
      });
    }
  }
}

// ─── Models ──────────────────────────────────────────────────────────

class _TxPreview {
  final String category;
  final int amount;
  final String note;
  const _TxPreview({required this.category, required this.amount, required this.note});
}

class _ChatMsg {
  final String text;
  final bool isUser;
  final String time;
  final _TxPreview? txPreview;

  const _ChatMsg({required this.text, required this.isUser, required this.time, this.txPreview});
}

// ─── Widgets ─────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  const _ChatHeader();

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
      child: Row(children: [
        IconButton(
          onPressed: () => ctx.pop(),
          icon: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
          ),
        ),
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: const Center(child: Text('😎', style: TextStyle(fontSize: 20))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Chat với Mimo', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          Text('AI Assistant có thể ghi nhận chi tiêu', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.white70)),
        ])),
        IconButton(
          onPressed: () => ctx.push(AppRoutes.chatHistory),
          icon: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.access_time, color: Colors.white, size: 18),
          ),
        ),
      ]),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        margin: const EdgeInsets.only(bottom: 12, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadii.lg),
            topRight: Radius.circular(AppRadii.lg),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(AppRadii.lg),
          ),
          boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 6, offset: Offset(0, 4))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('😎', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text('Mimo đang nghĩ', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontStyle: FontStyle.italic)),
          const SizedBox(width: 4),
          const _DotsAnimation(),
        ]),
      ),
    ]);
  }
}

class _DotsAnimation extends StatefulWidget {
  const _DotsAnimation();

  @override
  State<_DotsAnimation> createState() => _DotsAnimationState();
}

class _DotsAnimationState extends State<_DotsAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final phase = _ctrl.value;
        return Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) {
          final offset = ((phase * 3 - i) % 3).clamp(0.0, 1.0);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Opacity(
              opacity: 0.3 + 0.7 * (1 - offset),
              child: Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.muted, shape: BoxShape.circle)),
            ),
          );
        }));
      },
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMsg message;
  final Future<void> Function(_TxPreview)? onSaveTx;

  const _ChatBubble({required this.message, this.onSaveTx});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = message.isUser ? AppColors.teal : Colors.white;
    final textColor = message.isUser ? Colors.white : AppColors.textPrimary;
    final alignment = message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Column(crossAxisAlignment: alignment, children: [
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
          boxShadow: message.isUser ? null : const [BoxShadow(color: Color(0x12000000), blurRadius: 6, offset: Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(message.text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor)),
          // Transaction preview card
          if (message.txPreview != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFB),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.receipt_long, color: AppColors.teal, size: 16),
                  const SizedBox(width: 6),
                  Text(message.txPreview!.category, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const Spacer(),
                  Text('-${formatVnd(message.txPreview!.amount)}',
                    style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
                if (message.txPreview!.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(message.txPreview!.note, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () => onSaveTx?.call(message.txPreview!),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    child: const Text('💾 Lưu giao dịch'),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 6),
          Text(message.time, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor.withValues(alpha: 0.7))),
        ]),
      ),
    ]);
  }
}

class _ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  const _ChatComposer({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, -4))],
      ),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: 'Nhắn tin cho Mimo...',
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.lg), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: IconButton(onPressed: onSend, icon: const Icon(Icons.send, color: AppColors.teal, size: 18)),
        ),
      ]),
    );
  }
}