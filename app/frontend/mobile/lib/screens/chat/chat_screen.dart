import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/transaction_notifier.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../data/mock_data.dart';
import '../../utils/formatters.dart';
import '../../widgets/mimo_overlay.dart';

/// Truncate LLM story text to [maxLen] characters for display.
String _truncLlm(String text, [int maxLen = 120]) {
  if (text.length <= maxLen) return text;
  return '${text.substring(0, maxLen)}...';
}

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
            final metadata = (m['intent_action'] ?? m['intentAction'] ?? m['metadata']) as Map<String, dynamic>?;
            
            _TxPreview? txPreview;
            _ActionPreview? actionPreview;
            String? mood;

            if (metadata != null) {
              mood = metadata['mood'] as String?;
              final nlu = metadata['nlu'] as Map<String, dynamic>?;
              if (nlu != null) {
                final intent = metadata['intent'] as String?;
                if (intent == 'Record') {
                  final amount = metadata['amount'] ?? nlu['amount_spent'] ?? nlu['amount'];
                  final amountInt = (amount is num) ? amount.toInt() : 0;
                  txPreview = _TxPreview(
                    category: metadata['category'] as String? ?? 'Other',
                    amount: amountInt,
                    note: nlu['clean_content'] as String? ?? m['content'] as String? ?? '',
                    recordType: nlu['record_type'] as String? ?? 'Expense',
                  );
                } else if (intent == 'Action') {
                  final actionType = nlu['action_type'] as String? ?? 'Unknown';
                  final sig = '${actionType}_${(m['content'] as String? ?? '').hashCode}';
                  actionPreview = _ActionPreview(
                    actionType: actionType,
                    signature: sig,
                    originalText: m['content'] as String? ?? '',
                  );
                }
              }
            }

            _messages.add(_ChatMsg(
              text: m['content'] as String? ?? '',
              isUser: role == 'user',
              time: _formatMsgTime(m['created_at'] as String?),
              mood: mood,
            ));
            if (txPreview != null || actionPreview != null) {
              _messages.add(_ChatMsg(
                text: '',
                isUser: false,
                time: _formatMsgTime(m['created_at'] as String?),
                txPreview: txPreview,
                actionPreview: actionPreview,
                isSaved: txPreview != null,
              ));
            }
          }
        });
        _scrollToBottom();
      } catch (_) {}
      return;
    }
    try {
      final sessions = await _api.getChatSessions();
      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final todaySession = sessions.cast<Map<String, dynamic>>().where((s) {
        final createdAt = s['created_at'] as String? ?? s['createdAt'] as String? ?? '';
        return createdAt.startsWith(todayStr);
      }).firstOrNull;
      if (todaySession != null) {
        _sessionId = todaySession['id'] as String?;
        final msgs = await _api.getChatMessages(_sessionId!);
        if (mounted) {
          setState(() {
            for (final m in msgs) {
              final role = m['role'] as String? ?? 'user';
              final metadata = (m['intent_action'] ?? m['intentAction'] ?? m['metadata']) as Map<String, dynamic>?;
              
              _TxPreview? txPreview;
              _ActionPreview? actionPreview;
              String? mood;

              if (metadata != null) {
                mood = metadata['mood'] as String?;
                final nlu = metadata['nlu'] as Map<String, dynamic>?;
                if (nlu != null) {
                  final intent = metadata['intent'] as String?;
                  if (intent == 'Record') {
                    final amount = metadata['amount'] ?? nlu['amount_spent'] ?? nlu['amount'];
                    final amountInt = (amount is num) ? amount.toInt() : 0;
                    txPreview = _TxPreview(
                      category: metadata['category'] as String? ?? 'Other',
                      amount: amountInt,
                      note: nlu['clean_content'] as String? ?? m['content'] as String? ?? '',
                      recordType: nlu['record_type'] as String? ?? 'Expense',
                    );
                  } else if (intent == 'Action') {
                    final actionType = nlu['action_type'] as String? ?? 'Unknown';
                    final sig = '${actionType}_${(m['content'] as String? ?? '').hashCode}';
                    actionPreview = _ActionPreview(
                      actionType: actionType,
                      signature: sig,
                      originalText: m['content'] as String? ?? '',
                    );
                  }
                }
              }

              _messages.add(_ChatMsg(
                text: m['content'] as String? ?? '',
                isUser: role == 'user',
                time: _formatMsgTime(m['created_at'] as String?),
                mood: mood,
              ));
              if (txPreview != null || actionPreview != null) {
                _messages.add(_ChatMsg(
                  text: '',
                  isUser: false,
                  time: _formatMsgTime(m['created_at'] as String?),
                  txPreview: txPreview,
                  actionPreview: actionPreview,
                  isSaved: txPreview != null,
                ));
              }
            }
          });
          _scrollToBottom();
        }
      } else {
        final session = await _api.createChatSession(title: 'Chat ${today.day}/${today.month}');
        _sessionId = session['id'] as String?;
      }
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
      final nlu = await _api.aiNlu(userText, runLlm: true);
      final intent = nlu['intent'] as String? ?? 'Chitchat';
      final amount = nlu['amount'] ?? nlu['amount_spent'];
      final category = nlu['category'] as String?;

      String replyText;

      // NLU returns emotion in gemini_json.emotion (normalized by backend)
      // fallback: mascot_mood (legacy), then llama_json.emotion
      final geminiJson = nlu['gemini_json'] as Map?;
      final llamaJson = nlu['llama_json'] as Map?;
      final moodRaw = (geminiJson?['emotion'] as String?)
          ?? (llamaJson?['emotion'] as String?)
          ?? (nlu['mascot_mood'] as String?);
      final String fallbackMood = intent == 'Record' ? 'Happy' : (intent == 'Action' ? 'Thinking' : 'Chill');
      final moodStatus = mapApiStatusToAsset(moodRaw, fallback: fallbackMood);

      _ChatMsg? textMsg;
      _ChatMsg? confirmMsg;

      if (intent == 'Record' && amount != null) {
        final amountInt = (amount is num) ? amount.toInt() : 0;
        final recordType = nlu['record_type'] as String? ?? 'Expense';
        final llmStory = geminiJson?['story'] as String? ?? llamaJson?['story'] as String?;
        final nlgResponse = nlu['nlg_response'] as String? ?? geminiJson?['response'] as String?;
        final defaultLabel = recordType == 'Income' ? '📝 Mimo hiểu bạn muốn ghi nhận thu nhập:' : '📝 Mimo hiểu bạn muốn ghi nhận chi tiêu:';
        replyText = _truncLlm(llmStory ?? nlgResponse ?? defaultLabel);
        textMsg = _ChatMsg(
          text: replyText,
          isUser: false,
          time: _now(),
          mood: moodStatus,
        );
        confirmMsg = _ChatMsg(
          text: '',
          isUser: false,
          time: _now(),
          txPreview: _TxPreview(
            category: category ?? 'Other',
            amount: amountInt,
            note: nlu['clean_content'] as String? ?? userText,
            recordType: recordType,
            mood: moodStatus,
            aiComment: replyText,
          ),
        );
      } else if (intent == 'Action') {
        final actionType = nlu['action_type'] as String? ?? 'Unknown';
        final sig = '${actionType}_${userText.hashCode}';
        final llmStory = geminiJson?['story'] as String? ?? llamaJson?['story'] as String?;
        final nlgResponse = nlu['nlg_response'] as String? ?? geminiJson?['response'] as String?;
        replyText = _truncLlm(llmStory ?? nlgResponse ?? '⚡ Mimo nhận lệnh: $actionType');
        textMsg = _ChatMsg(
          text: replyText,
          isUser: false,
          time: _now(),
          mood: moodStatus,
        );
        confirmMsg = _ChatMsg(
          text: '',
          isUser: false,
          time: _now(),
          actionPreview: _ActionPreview(
            actionType: actionType,
            signature: sig,
            originalText: userText,
          ),
        );
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          _executeAction(actionType, sig, userText);
        });
      } else {
        final llmStory = geminiJson?['story'] as String? ?? geminiJson?['response'] as String?;
        replyText = _truncLlm(llmStory ?? (nlu['nlg_response'] as String?) ?? 'Mimo đây! Bạn cần gì nào? 😊');
        textMsg = _ChatMsg(
          text: replyText,
          isUser: false,
          time: _now(),
          mood: moodStatus,
        );
      }

      if (!mounted) return;
      setState(() {
        _aiThinking = false;
        if (textMsg != null) _messages.add(textMsg);
        if (confirmMsg != null) _messages.add(confirmMsg);
      });
      _scrollToBottom();

      // Save AI reply to backend chat
      if (_sessionId != null) {
        try {
          final payload = {
            'content': replyText,
            'role': 'assistant',
            'intentAction': {
              'mood': moodStatus,
              'intent': intent,
              'amount': amount,
              'category': category,
              'nlu': nlu,
            }
          };
          await _api.sendChatMessageRaw(_sessionId!, payload);
        } catch (_) {}
      }

      // M4-02: Show mascot mood from API response
      final llmStoryForMimo = (nlu['gemini_json'] as Map?)?['story'] as String?;
      final mimoMsg = llmStoryForMimo ?? (replyText.length > 80 ? '${replyText.substring(0, 80)}...' : replyText);
      mimoController.show(MiMoResponse(
        status: moodStatus,
        message: mimoMsg,
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

  Future<void> _executeAction(String actionType, String signature, String originalText) async {
    try {
      await _api.aiConfirmAction(signature, actionType: actionType);
      if (!mounted) return;

      final type = actionType.toUpperCase();
      if (type.contains('REPORT')) {
        context.go(AppRoutes.report);
      } else if (type.contains('LIMIT')) {
        context.push(AppRoutes.limits);
      } else if (type.contains('SETTING')) {
        context.go(AppRoutes.settings);
      } else if (type.contains('GOAL')) {
        context.go(AppRoutes.goals);
      } else if (type.contains('DELETE_RECORD')) {
        try {
          final txRes = await _api.getTransactions(pageSize: 1);
          final txData = txRes['data'];
          List<dynamic>? txs;
          if (txData is Map<String, dynamic>) {
            txs = txData['items'] as List<dynamic>?;
          } else if (txData is List<dynamic>) {
            txs = txData;
          }
          if (txs != null && txs.isNotEmpty) {
            final latestTxId = txs[0]['id'] as String;
            await _api.deleteTransaction(latestTxId);
            notifyTransactionChanged();
            if (mounted) {
              setState(() {
                _messages.add(_ChatMsg(text: '✅ Đã xóa giao dịch gần nhất thành công!', isUser: false, time: _now()));
              });
              _scrollToBottom();
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
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
                  return _ChatBubble(
                    message: _messages[index],
                    onSaveTx: _saveTransaction,
                    onConfirmAction: _handleActionConfirm,
                    onRejectAction: _handleActionReject,
                    onEditTxCategory: _showEditTxSheet,
                  );
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

  Future<void> _handleActionConfirm(_ActionPreview action) async {
    try {
      await _api.aiConfirmAction(action.signature, actionType: action.actionType);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(text: '✅ Đã thực hiện hành động!', isUser: false, time: _now()));
      });
      _scrollToBottom();

      final type = action.actionType.toUpperCase();
      if (type.contains('REPORT')) {
        context.go(AppRoutes.report);
      } else if (type.contains('LIMIT')) {
        context.push(AppRoutes.limits);
      } else if (type.contains('SETTING')) {
        context.go(AppRoutes.settings);
      } else if (type.contains('DELETE_RECORD')) {
        try {
          final txRes = await _api.getTransactions(pageSize: 1);
          final txData = txRes['data'];
          List<dynamic>? txs;
          if (txData is Map<String, dynamic>) {
            txs = txData['items'] as List<dynamic>?;
          } else if (txData is List<dynamic>) {
            txs = txData;
          }
          if (txs != null && txs.isNotEmpty) {
            final latestTxId = txs[0]['id'] as String;
            await _api.deleteTransaction(latestTxId);
            notifyTransactionChanged();
            if (mounted) {
              setState(() {
                _messages.add(_ChatMsg(text: '✅ Đã xóa giao dịch gần nhất thành công!', isUser: false, time: _now()));
              });
              _scrollToBottom();
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _handleActionReject(_ActionPreview action) async {
    try {
      await _api.aiRejectAction(text: action.originalText);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(text: '❌ Đã bỏ qua. Mimo sẽ cải thiện sau!', isUser: false, time: _now()));
      });
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _saveTransaction(_ChatMsg msg) async {
    final preview = msg.txPreview;
    if (preview == null) return;
    try {
      final wallets = await _api.getWallets();
      if (wallets.isEmpty) return;
      await _api.createTransaction({
        'walletId': wallets[0]['id'],
        'amount': preview.amount,
        'type': preview.recordType == 'Income' ? 'income' : 'expense',
        'categoryCode': preview.category,
        'note': preview.note,
        // Lưu kèm emotion + comment LLM để story feed / detail hiển thị đúng mascot.
        if (preview.mood != null) 'mascotMood': preview.mood,
        if (preview.aiComment != null && preview.aiComment!.isNotEmpty) 'aiComment': preview.aiComment,
      });
      if (!mounted) return;
      notifyTransactionChanged();
      setState(() {
        msg.isSaved = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(text: '❌ Không thể lưu giao dịch', isUser: false, time: _now()));
      });
    }
  }

  void _showEditTxSheet(_ChatMsg msg) {
    final preview = msg.txPreview;
    if (preview == null) return;
    final amountCtrl = TextEditingController(text: preview.amount.toString());
    final noteCtrl = TextEditingController(text: preview.note);
    String editCategory = preview.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: ctx.palette.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('Chỉnh sửa giao dịch', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text('Số tiền', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Nhập số tiền', suffixText: 'đ'),
              ),
              const SizedBox(height: 12),
              Text('Danh mục', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: CategoryTheme.styles.containsKey(editCategory) ? editCategory : 'Other',
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                ),
                items: CategoryTheme.styles.entries
                    .where((e) => CategoryTheme.primaryCodes.contains(e.key))
                    .map((e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Row(children: [
                            CategoryTheme.iconOf(e.key, size: 22),
                            const SizedBox(width: 8),
                            Text(e.value.label),
                          ]),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setSheetState(() => editCategory = val);
                },
              ),
              const SizedBox(height: 12),
              Text('Ghi chú', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(hintText: 'Ghi chú cho giao dịch'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    setState(() {
                      preview.amount = int.tryParse(amountCtrl.text) ?? preview.amount;
                      preview.note = noteCtrl.text;
                      preview.category = editCategory;
                    });
                    ctx.pop();
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('Lưu chỉnh sửa'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Models ──────────────────────────────────────────────────────────

class _TxPreview {
  String category;
  int amount;
  String note;
  String recordType;
  /// Emotion (PascalCase) + câu comment LLM — để lưu kèm khi tạo giao dịch.
  String? mood;
  String? aiComment;
  _TxPreview({required this.category, required this.amount, required this.note, this.recordType = 'Expense', this.mood, this.aiComment});
}

class _ChatMsg {
  final String text;
  final bool isUser;
  final String time;
  final _TxPreview? txPreview;
  final _ActionPreview? actionPreview;
  final String? mood;
  bool isSaved;

  _ChatMsg({required this.text, required this.isUser, required this.time, this.txPreview, this.actionPreview, this.mood, this.isSaved = false});
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
          child: ClipOval(child: Image.asset('assets/MiMo/emotions/Cool.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Text('😎')))),
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

/// Emotion mascot hiển thị nhỏ như 1 sticker/emoji (Zalo-style).
class _MoodSticker extends StatelessWidget {
  final String mood;
  const _MoodSticker({required this.mood});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        'assets/MiMo/emotions/$mood.png',
        width: 56, height: 56,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
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
          color: context.palette.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: context.palette.border),
          boxShadow: context.palette.softShadow,
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
          color: context.palette.card,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadii.lg),
            topRight: Radius.circular(AppRadii.lg),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(AppRadii.lg),
          ),
          boxShadow: context.palette.softShadow,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/MiMo/emotions/Thinking.png', width: 22, height: 22, errorBuilder: (_, __, ___) => const Text('🤔', style: TextStyle(fontSize: 14))),
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

// ─── Action Preview ─────────────────────────────────────────────────

class _ActionPreview {
  final String actionType;
  final String signature;
  final String originalText;
  const _ActionPreview({required this.actionType, required this.signature, required this.originalText});
}

class _ChatBubble extends StatelessWidget {
  final _ChatMsg message;
  final Future<void> Function(_ChatMsg)? onSaveTx;
  final Future<void> Function(_ActionPreview)? onConfirmAction;
  final Future<void> Function(_ActionPreview)? onRejectAction;
  final void Function(_ChatMsg)? onEditTxCategory;

  const _ChatBubble({required this.message, this.onSaveTx, this.onConfirmAction, this.onRejectAction, this.onEditTxCategory});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = message.isUser ? AppColors.teal : context.palette.card;
    final textColor = message.isUser ? Colors.white : context.palette.textPrimary;
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
          if (message.text.isNotEmpty) ...[
            Text(message.text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor)),
            if (!message.isUser && message.mood != null) ...[
              const SizedBox(height: 6),
              _MoodSticker(mood: message.mood!),
            ],
          ] else if (!message.isUser && message.mood != null) ...[
            _MoodSticker(mood: message.mood!),
          ],
          // Action confirm/reject card
          if (message.actionPreview != null) ...[          
            if (message.text.isNotEmpty || message.mood != null)
              const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.flash_on, color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(message.actionPreview!.actionType,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
                ]),
                const SizedBox(height: 4),
                Text(message.actionPreview!.originalText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () => onRejectAction?.call(message.actionPreview!),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 6)),
                    child: const Text('Bỏ qua', style: TextStyle(fontSize: 12)),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: FilledButton(
                    onPressed: () => onConfirmAction?.call(message.actionPreview!),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(vertical: 6)),
                    child: const Text('Xác nhận', style: TextStyle(fontSize: 12)),
                  )),
                ]),
              ]),
            ),
          ],
          // Transaction preview card
          if (message.txPreview != null) ...[
            if (message.text.isNotEmpty || message.mood != null)
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
                  Text(
                    '${message.txPreview!.recordType == 'Income' ? '+' : '-'}${formatVnd(message.txPreview!.amount)}',
                    style: TextStyle(
                      color: message.txPreview!.recordType == 'Income' ? const Color(0xFF22C55E) : AppColors.danger,
                      fontWeight: FontWeight.w700, fontSize: 14)),
                ]),
                if (message.txPreview!.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(message.txPreview!.note, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                ],
                const SizedBox(height: 8),
                message.isSaved
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: AppColors.teal, size: 16),
                          SizedBox(width: 6),
                          Text('Đã lưu giao dịch', style: TextStyle(color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => onEditTxCategory?.call(message),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                side: const BorderSide(color: AppColors.teal),
                              ),
                              child: const Text('✏️ Chỉnh sửa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.teal)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () => onSaveTx?.call(message),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              child: const Text('💾 Lưu'),
                            ),
                          ),
                        ],
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
      decoration: BoxDecoration(
        color: context.palette.card,
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, -4))],
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
              fillColor: context.palette.surfaceAlt,
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