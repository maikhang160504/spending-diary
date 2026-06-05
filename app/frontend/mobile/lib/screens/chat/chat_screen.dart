import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/streak_celebration.dart';
import '../../services/voice_input_service.dart';
import '../../services/transaction_notifier.dart';
import '../../utils/mimo_emotion.dart';
import '../../utils/nlu_parse.dart';
import '../../utils/vn_time.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';

/// Fallback ngắn khi LLM không trả text (không cắt response LLM).
String _llmDisplayText(String llmText, String fallback) =>
    llmText.trim().isNotEmpty ? llmText.trim() : fallback;

String _actionSignatureFromNlu(Map<String, dynamic> nlu) {
  final fromApi = nlu['action_signature'] as String?;
  if (fromApi != null && fromApi.isNotEmpty) return fromApi;
  final actionType = (nlu['action_type'] as String? ?? 'UNKNOWN').toUpperCase();
  final tr = nlu['time_range'] as Map<String, dynamic>?;
  if (tr != null) return '$actionType|${tr['granularity'] ?? 'default'}';
  final details = nlu['action_details'] as Map<String, dynamic>?;
  final amount = nlu['amount'] ?? nlu['action_param'] ?? details?['value'];
  final cat = _categoryFromNlu(nlu);
  if (actionType.contains('LIMIT')) return '$actionType|${cat ?? 'all'}|$amount';
  if (actionType.contains('DELETE')) return '$actionType|last';
  if (actionType.contains('GOAL')) return '$actionType|$amount';
  return '$actionType|default';
}

String? _categoryFromNlu(Map<String, dynamic> nlu) {
  final details = nlu['action_details'] as Map<String, dynamic>?;
  final target = details?['target'] as String? ?? nlu['category'] as String?;
  if (target == null) return null;
  if (CategoryTheme.styles.containsKey(target)) return target;
  return null;
}

int? _amountFromNlu(Map<String, dynamic> nlu) {
  final details = nlu['action_details'] as Map<String, dynamic>?;
  final raw = nlu['amount'] ?? nlu['action_param'] ?? details?['value'];
  if (raw is num) return raw.toInt();
  return null;
}

String _actionSummary(String actionType, {int? amount, String? categoryCode}) {
  final t = actionType.toUpperCase();
  final amt = amount != null ? formatVnd(amount) : null;
  final catLabel = categoryCode != null ? CategoryTheme.of(categoryCode).label : null;
  if (t.contains('LIMIT')) return 'Đặt hạn mức${catLabel != null ? ' $catLabel' : ''}${amt != null ? ': $amt' : ''}';
  if (t.contains('DELETE')) return 'Xóa giao dịch gần nhất';
  if (t.contains('GOAL')) return 'Tạo mục tiêu tiết kiệm${amt != null ? ' $amt' : ''}';
  if (t.contains('TONE')) return 'Đổi giọng nói Mimo';
  if (t.contains('SEARCH')) return 'Tìm kiếm giao dịch';
  if (t.contains('SETTING')) return 'Mở cài đặt ứng dụng';
  return actionType;
}

_ActionPreview _actionPreviewFromNlu(Map<String, dynamic> nlu, String userText, {String? aiLine}) {
  final actionType = nlu['action_type'] as String? ?? 'Unknown';
  final amount = _amountFromNlu(nlu);
  final categoryCode = _categoryFromNlu(nlu);
  return _ActionPreview(
    actionType: actionType,
    signature: _actionSignatureFromNlu(nlu),
    originalText: userText,
    amount: amount,
    categoryCode: categoryCode,
    summary: _actionSummary(actionType, amount: amount, categoryCode: categoryCode),
    actionDetails: nlu['action_details'] as Map<String, dynamic>?,
    aiLine: aiLine,
  );
}

Map<String, dynamic> _executeBodyFromPreview(_ActionPreview preview) {
  return {
    'actionType': preview.actionType,
    if (preview.amount != null) 'amount': preview.amount,
    if (preview.categoryCode != null) 'categoryCode': preview.categoryCode,
    'text': preview.originalText,
    if (preview.actionDetails != null) 'actionDetails': preview.actionDetails,
  };
}

_SearchResultPreview? _searchPreviewFromResult(Map<String, dynamic> result) {
  if (result['kind'] != 'search') return null;
  final items = (result['items'] as List<dynamic>? ?? []).map((e) {
    final m = e as Map<String, dynamic>;
    return _SearchResultItem(
      amount: (m['amount'] as num?)?.toInt() ?? 0,
      note: m['note'] as String? ?? '',
      categoryCode: m['categoryCode'] as String? ?? 'Others',
    );
  }).toList();
  if (items.isEmpty) return null;
  return _SearchResultPreview(items: items);
}

bool _actionNeedsConfirm(String actionType) {
  final t = actionType.toUpperCase();
  if (t.contains('REPORT')) return false;
  if (t == 'SETTING' || t == 'SYSTEM_SETTING') return false;
  return t.contains('LIMIT') ||
      t.contains('DELETE') ||
      t.contains('GOAL') ||
      t.contains('TONE') ||
      t.contains('SEARCH');
}

_ReportStoryPreview? _reportPreviewFromNlu(Map<String, dynamic> nlu) {
  final ar = nlu['action_result'] as Map<String, dynamic>?;
  if (ar == null) return null;
  final cats = (ar['by_category'] as List<dynamic>? ?? []).map((c) {
    final m = c as Map<String, dynamic>;
    return _ReportCategoryRow(
      categoryCode: m['categoryCode'] as String? ?? 'Others',
      total: (m['total'] as num?)?.toInt() ?? 0,
      percent: (m['percent'] as num?)?.toInt() ?? 0,
    );
  }).toList();
  final kind = nluString(ar['report_kind']) ?? nluString(nlu['action_type']);
  return _ReportStoryPreview(
    periodLabel: ar['period_label'] as String? ??
        (nlu['time_range'] as Map?)?['period_label'] as String? ??
        'Báo cáo',
    totalExpense: (ar['total_expense'] as num?)?.toInt() ?? 0,
    totalIncome: (ar['total_income'] as num?)?.toInt() ?? 0,
    reportKind: kind,
    transactionCount: (ar['transaction_count'] as num?)?.toInt() ?? 0,
    categories: cats,
  );
}

class ChatScreen extends StatefulWidget {
  /// Optional sessionId passed from ChatHistoryScreen (CHH-02)
  final String? sessionId;
  final String? walletId;
  const ChatScreen({super.key, this.sessionId, this.walletId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiClient();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _messages = [];

  bool _aiThinking = false;
  bool _voiceListening = false;
  bool _voiceAvailable = false;
  bool _loadingOlder = false;
  bool _hasMoreHistory = false;
  /// Tránh gọi load-more khi ListView reverse vừa layout (chưa ổn scroll).
  bool _readyForOlderLoad = false;
  String _verbalStyle = 'funny';
  String? _sessionId;
  String? _oldestMessageId;
  final _voice = VoiceInputService.instance;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScrollLoadOlder);
    _initSession();
    _loadAiPersonality();
    _voice.checkAvailability().then((ok) {
      if (mounted) setState(() => _voiceAvailable = ok);
    });
  }

  Future<void> _loadAiPersonality() async {
    try {
      final settings = await _api.getSettings();
      if (!mounted) return;
      setState(() => _verbalStyle = normalizeVerbalStyle(settings['verbal_style'] as String?));
    } catch (_) {}
  }

  @override
  void activate() {
    super.activate();
    _loadAiPersonality();
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScrollLoadOlder);
    _voice.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScrollLoadOlder() {
    if (!_readyForOlderLoad ||
        !_scrollCtrl.hasClients ||
        _loadingOlder ||
        !_hasMoreHistory ||
        _sessionId == null) {
      return;
    }
    final pos = _scrollCtrl.position;
    // reverse: true — cuộn lên (tin cũ) → pixels gần maxScrollExtent
    if (pos.maxScrollExtent - pos.pixels < 120) {
      _loadOlderMessages();
    }
  }

  List<_ChatMsg> _parseMessagesFromApi(List<dynamic> msgs) {
    final out = <_ChatMsg>[];
    for (final m in msgs) {
      final map = m as Map<String, dynamic>;
      final role = map['role'] as String? ?? 'user';
      final metadata = (map['intent_action'] ?? map['intentAction'] ?? map['metadata']) as Map<String, dynamic>?;

      _TxPreview? txPreview;
      _ActionPreview? actionPreview;
      _ReportStoryPreview? reportPreview;
      List<_TxPreview>? multiRecords;
      String? chatEmotion;
      var displayText = map['content'] as String? ?? '';

      if (metadata != null && role != 'user') {
        final llmMeta = llmReplyFromChatMetadata(metadata, fallbackText: displayText);
        chatEmotion = llmMeta?.emotionAsset;

        final rawMulti = metadata['multi_records'] ?? metadata['multiRecords'];
        if (rawMulti is List && rawMulti.length >= 2) {
          multiRecords = rawMulti.map((r) {
            final rMap = r as Map<String, dynamic>;
            return _TxPreview(
              category: rMap['category'] as String? ?? 'Other',
              amount: (rMap['amount'] is num) ? (rMap['amount'] as num).toInt() : 0,
              note: rMap['text'] as String? ?? rMap['note'] as String? ?? '',
              recordType: rMap['record_type'] as String? ?? 'Expense',
            );
          }).toList();
        }

        final nlu = nluMap(metadata['nlu']);
        if (nlu != null) {
          final intent = nluString(metadata['intent']);
          if (intent == 'Record' && multiRecords == null) {
            final amount = metadata['amount'] ?? nlu['amount_spent'] ?? nlu['amount'];
            final amountInt = (amount is num) ? amount.toInt() : 0;
            final reply = llmMeta ?? LlmMimoReply.fromNlu(nlu, intent: intent);
            final llmText = reply.text.trim();
            if (llmText.isNotEmpty) displayText = llmText;
            txPreview = _TxPreview(
              category: nluString(metadata['category']) ?? 'Other',
              amount: amountInt,
              note: nluString(nlu['clean_content']) ?? '',
              recordType: nluString(nlu['record_type']) ?? 'Expense',
              emotionAsset: reply.emotionAsset,
              aiComment: llmText.isNotEmpty ? llmText : null,
              nlu: nlu,
            );
          } else if (intent == 'Action') {
            final report = _reportPreviewFromNlu(nlu);
            if (report != null) {
              reportPreview = report;
              if (llmMeta != null && llmMeta.text.isNotEmpty) {
                displayText = llmMeta.text;
              }
            } else {
              final llmText = (llmMeta?.text ?? displayText).trim();
              final originalUser =
                  nluString(nlu['text']) ?? nluString(nlu['clean_content']) ?? '';
              actionPreview = _actionPreviewFromNlu(
                nlu,
                originalUser,
                aiLine: llmText.isNotEmpty ? llmText : null,
              );
              displayText = '';
            }
          }
        }
      }

      // Đọc trạng thái saved từ metadata thay vì mặc định true
      final savedFlag = metadata?['saved'] == true;
      out.add(_ChatMsg(
        text: role == 'user' ? displayText : displayText,
        isUser: role == 'user',
        time: _formatMsgTime(map['created_at'] as String?),
        chatEmotion: chatEmotion,
        txPreview: txPreview,
        actionPreview: actionPreview,
        reportPreview: reportPreview,
        multiRecords: multiRecords,
        isSaved: (txPreview != null || multiRecords != null) && savedFlag,
      ));
    }
    return out;
  }

  Future<void> _loadMessagesPage({String? before, bool loadOlder = false}) async {
    if (_sessionId == null) return;
    final page = await _api.getChatMessagesPage(_sessionId!, limit: 30, before: before);
    if (!mounted) return;
    final parsed = _parseMessagesFromApi(page['messages'] as List<dynamic>? ?? []);
    // API: chronological cũ→mới; ListView reverse: index 0 = tin mới nhất (đáy màn hình)
    final batchNewestFirst = parsed.reversed.toList();
    setState(() {
      if (loadOlder) {
        _messages.addAll(batchNewestFirst);
      } else {
        _readyForOlderLoad = false;
        _messages
          ..clear()
          ..addAll(batchNewestFirst);
      }
      _hasMoreHistory = page['hasMore'] == true;
      final oldest = page['oldestId'] as String?;
      if (oldest != null && oldest.isNotEmpty) {
        _oldestMessageId = oldest;
      }
    });

    for (final msg in batchNewestFirst) {
      if (msg.actionPreview != null) {
        _api.aiIsActionConfirmed(msg.actionPreview!.signature).then((confirmed) {
          if (confirmed && mounted) {
            setState(() {
              msg.isConfirmed = true;
            });
          }
        });
      }
    }

    if (!loadOlder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollCtrl.hasClients) return;
        _scrollCtrl.jumpTo(0);
        _readyForOlderLoad = true;
      });
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_loadingOlder || !_hasMoreHistory || _oldestMessageId == null) return;
    setState(() => _loadingOlder = true);
    try {
      await _loadMessagesPage(before: _oldestMessageId, loadOlder: true);
    } catch (_) {}
    if (mounted) setState(() => _loadingOlder = false);
  }

  Future<void> _toggleVoiceInput() async {
    if (_voiceListening) {
      await _voice.stop();
      if (mounted) setState(() => _voiceListening = false);
      return;
    }
    if (!_voiceAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thiết bị/emulator không hỗ trợ nhận diện giọng nói. Hãy gõ tin nhắn hoặc dùng máy thật.'),
          ),
        );
      }
      return;
    }
    final ready = await _voice.ensureReady();
    if (!ready && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cần quyền micro để dùng giọng nói')),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _voiceListening = true);
    try {
      await _voice.startListening(
        onPartial: (text) {
          if (!mounted) return;
          _inputCtrl.text = text;
          _inputCtrl.selection = TextSelection.collapsed(offset: text.length);
        },
        onFinal: (text) async {
          await _voice.stop();
          if (!mounted) return;
          setState(() => _voiceListening = false);
          if (text.isNotEmpty) await _sendMessage(text);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _voiceListening = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không bật được micro: $e')),
        );
      }
    }
  }

  Future<void> _initSession() async {
    // If sessionId passed from history, reuse it and load messages
    if (widget.sessionId != null) {
      _sessionId = widget.sessionId;
      try {
        await _loadMessagesPage();
      } catch (_) {}
      return;
    }
    // Check if we are opening chat for a shared wallet (widget.walletId is not null)
    if (widget.walletId != null) {
      try {
        String walletName = 'Ví chung';
        try {
          final wallet = await _api.getWallet(widget.walletId!);
          walletName = wallet['name'] as String? ?? 'Ví chung';
        } catch (_) {}
        final session = await _api.createChatSession(title: 'Chat $walletName');
        _sessionId = session['id'] as String?;
        return;
      } catch (_) {}
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
        if (mounted) await _loadMessagesPage();
      } else {
        final session = await _api.createChatSession(title: 'Chat ${today.day}/${today.month}');
        _sessionId = session['id'] as String?;
      }
    } catch (_) {}
  }

  String _formatMsgTime(String? iso) => VnTime.formatHmFromIso(iso);

  void _scrollToBottom() {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.jumpTo(0);
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final userText = text.trim();
    _inputCtrl.clear();

    setState(() {
      _messages.insert(0, _ChatMsg(text: userText, isUser: true, time: _now()));
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
      final intent = nluString(nlu['intent']) ?? 'Chitchat';
      final amount = nlu['amount'] ?? nlu['amount_spent'];
      final category = nluString(nlu['category']);
      final intentConfidence = nluDouble(nlu['intent_confidence']) ?? nluDouble(nlu['confidence']) ?? 0;

      String replyText;

      final llm = LlmMimoReply.fromNlu(nlu, intent: intent);

      _ChatMsg? textMsg;
      _ChatMsg? confirmMsg;
      String aiText = '';

      final rawMulti = nlu['multi_records'] ?? nlu['multiRecords'];
      List<_TxPreview>? multiRecords;
      if (rawMulti is List && rawMulti.length >= 2) {
        multiRecords = rawMulti.map((r) {
          final map = r as Map<String, dynamic>;
          return _TxPreview(
            category: map['category'] as String? ?? 'Other',
            amount: (map['amount'] is num) ? (map['amount'] as num).toInt() : 0,
            note: map['text'] as String? ?? map['note'] as String? ?? '',
            recordType: map['record_type'] as String? ?? 'Expense',
          );
        }).toList();
      }

      if (multiRecords != null) {
        final count = multiRecords.length;
        replyText = _llmDisplayText(llm.text, '📝 Mimo nhận dạng được $count giao dịch:');
        confirmMsg = _ChatMsg(
          text: replyText,
          isUser: false,
          time: _now(),
          chatEmotion: llm.emotionAsset,
          multiRecords: multiRecords,
        );
      } else if (intent == 'Record' && amount != null) {
        final amountInt = (amount is num) ? amount.toInt() : 0;
        final recordType = nluString(nlu['record_type']) ?? 'Expense';
        final defaultLabel = recordType == 'Income' ? '📝 Mimo hiểu bạn muốn ghi nhận thu nhập:' : '📝 Mimo hiểu bạn muốn ghi nhận chi tiêu:';
        replyText = _llmDisplayText(llm.text, defaultLabel);
        aiText = canonicalAiReplyText(llm, displayFallback: replyText);
        confirmMsg = _ChatMsg(
          text: replyText,
          isUser: false,
          time: _now(),
          chatEmotion: llm.emotionAsset,
          txPreview: _TxPreview(
            category: category ?? 'Other',
            amount: amountInt,
            note: nluString(nlu['clean_content']) ?? userText,
            recordType: recordType,
            emotionAsset: llm.emotionAsset,
            aiComment: aiText,
            nlu: nlu,
          ),
        );
      } else if (intent == 'Action') {
        final actionType = nluString(nlu['action_type']) ?? 'Unknown';
        final aiLine = _llmDisplayText(
          llm.text,
          '⚡ Mimo đã xử lý: ${_actionSummary(actionType)}',
        );
        aiText = canonicalAiReplyText(llm, displayFallback: aiLine);
        final reportPreview = _reportPreviewFromNlu(nlu);

        if (reportPreview != null) {
          // Báo cáo: chỉ 1 card (BE đã thực thi), không bubble + không overlay trùng.
          confirmMsg = _ChatMsg(
            text: aiLine,
            isUser: false,
            time: _now(),
            chatEmotion: llm.emotionAsset,
            reportPreview: reportPreview,
          );
        } else if (_actionNeedsConfirm(actionType)) {
          final preview = _actionPreviewFromNlu(nlu, userText, aiLine: aiLine);
          final alreadyConfirmed = await _api.aiIsActionConfirmed(preview.signature);
          if (alreadyConfirmed) {
            // Đã confirm trước đó → chạy action + hiện kết quả text thay vì card
            await _runConfirmedAction(preview);
            replyText = aiLine;
            aiText = canonicalAiReplyText(llm, displayFallback: aiLine);
          } else {
            confirmMsg = _ChatMsg(
              text: '',
              isUser: false,
              time: _now(),
              chatEmotion: llm.emotionAsset,
              actionPreview: preview,
            );
          }
        } else {
          final preview = _actionPreviewFromNlu(nlu, userText, aiLine: aiLine);
          await _runConfirmedAction(preview);
        }
        replyText = aiLine;
        aiText = canonicalAiReplyText(llm, displayFallback: aiLine);
      } else {
        replyText = _llmDisplayText(llm.text, 'Mimo đây! Bạn cần gì nào? 😊');
        aiText = canonicalAiReplyText(llm, displayFallback: replyText);
        textMsg = _ChatMsg(
          text: replyText,
          isUser: false,
          time: _now(),
          chatEmotion: llm.emotionAsset,
        );
      }

      if (!mounted) return;
      setState(() {
        _aiThinking = false;
        if (confirmMsg != null) _messages.insert(0, confirmMsg);
        if (textMsg != null) _messages.insert(0, textMsg);
      });
      _scrollToBottom();

      if (confirmMsg?.txPreview != null && intentConfidence >= 0.9) {
        await _saveTransaction(confirmMsg!);
      } else if (confirmMsg?.multiRecords != null && intentConfidence >= 0.9) {
        await _saveMultiTransactions(confirmMsg!);
      }

      // Save AI reply to backend chat
      if (_sessionId != null) {
        try {
          final fullText = aiText.isNotEmpty ? aiText : canonicalAiReplyText(llm, displayFallback: replyText);
          final payload = {
            'content': fullText,
            'role': 'assistant',
            'intentAction': {
              'mood': llm.emotionAsset,
              'intent': intent,
              'amount': amount,
              'category': category,
              'aiComment': fullText,
              'nlu': nlu,
              if (multiRecords != null)
                'multi_records': multiRecords.map((r) => {
                  'category': r.category,
                  'amount': r.amount,
                  'text': r.note,
                  'record_type': r.recordType,
                }).toList(),
            }
          };
          await _api.sendChatMessageRaw(_sessionId!, payload);
        } catch (_) {}
      }

      // M4-02: Show mascot mood from API response
      await StreakCelebration.instance.afterActivity(context);
      // Không gọi mimoController ở chat — tránh trùng bubble; mascot/comment chỉ ở story feed.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _aiThinking = false;
        _messages.insert(0, _ChatMsg(text: e.localizedMessage, isUser: false, time: _now()));
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Chat NLU error: $e');
      if (!mounted) return;
      setState(() {
        _aiThinking = false;
        _messages.insert(0, _ChatMsg(text: 'Mimo gặp lỗi rồi 😅 Thử lại sau nhé!', isUser: false, time: _now()));
      });
      _scrollToBottom();
    }
  }

  String _now() => VnTime.formatHmNow();

  Future<void> _runConfirmedAction(_ActionPreview action) async {
    try {
      if (action.navOnly) {
        await _api.aiConfirmAction(action.signature, actionType: action.actionType);
        if (!mounted) return;
        context.go(AppRoutes.settings);
        return;
      }

      final result = await _api.aiExecuteAction(_executeBodyFromPreview(action));
      await _api.aiConfirmAction(action.signature, actionType: action.actionType);
      if (!mounted) return;

      final message = result['message'] as String? ?? '✅ Đã thực hiện hành động!';
      final searchPreview = _searchPreviewFromResult(result);
      final kind = result['kind'] as String?;

      if (kind == 'delete') notifyTransactionChanged();

      setState(() {
        _messages.insert(0, _ChatMsg(
          text: message,
          isUser: false,
          time: _now(),
          searchPreview: searchPreview,
        ));
      });
      _scrollToBottom();

      final navigate = result['navigate'] as String?;
      if (navigate == 'settings') context.go(AppRoutes.settings);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.insert(0, _ChatMsg(text: '❌ Không thực hiện được hành động.', isUser: false, time: _now()));
      });
      _scrollToBottom();
    }
  }

  Future<void> _handleActionConfirm(_ChatMsg msg) async {
    if (msg.isConfirmed) return;
    final action = msg.actionPreview;
    if (action == null) return;
    setState(() {
      msg.isConfirmed = true;
    });
    try {
      await _runConfirmedAction(action);
    } catch (_) {
      // Keep it as confirmed in UI to avoid showing buttons again
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: Column(
          children: [
            _ChatHeader(
              verbalStyle: _verbalStyle,
              personalityLabel: personalityLabelFromStyle(_verbalStyle),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: AppSpacing.lg),
                itemCount: _messages.length + (_aiThinking ? 1 : 0) + (_loadingOlder ? 1 : 0),
                itemBuilder: (context, index) {
                  final extraThinking = _aiThinking ? 1 : 0;

                  if (_aiThinking && index == 0) {
                    return const _TypingIndicator();
                  }

                  var msgIndex = index - extraThinking;
                  final loadingSlot = _messages.length;
                  if (_loadingOlder && msgIndex == loadingSlot) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                        child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                    );
                  }

                  return _ChatBubble(
                    message: _messages[msgIndex],
                    onSaveTx: _saveTransaction,
                    onSaveMultiTx: _saveMultiTransactions,
                    onConfirmAction: _handleActionConfirm,
                    onRejectAction: _handleActionReject,
                    onEditTxCategory: _showEditTxSheet,
                    onEditTxPreview: _showEditTxPreviewSheet,
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
              voiceAvailable: _voiceAvailable,
              voiceListening: _voiceListening,
              onVoice: _toggleVoiceInput,
              onSend: () {
                final t = _inputCtrl.text.trim();
                if (t.isEmpty) return;
                _sendMessage(t);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleActionReject(_ChatMsg msg) async {
    if (msg.isRejected) return;
    final action = msg.actionPreview;
    if (action == null) return;
    setState(() {
      msg.isRejected = true;
    });
    try {
      await _api.aiRejectAction(text: action.originalText);
      if (!mounted) return;
      setState(() {
        _messages.insert(0, _ChatMsg(text: '❌ Đã bỏ qua. Mimo sẽ cải thiện sau!', isUser: false, time: _now()));
      });
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _saveTransaction(_ChatMsg msg) async {
    if (msg.isSaved) return;
    final preview = msg.txPreview;
    if (preview == null) return;
    setState(() {
      msg.isSaved = true;
    });
    try {
      final wallets = await _api.getWallets();
      if (wallets.isEmpty) {
        setState(() {
          msg.isSaved = false;
        });
        return;
      }
      final aiText = (preview.aiComment ?? msg.text).trim();
      await _api.createTransaction({
        'walletId': widget.walletId ?? wallets[0]['id'],
        'amount': preview.amount,
        'type': preview.recordType == 'Income' ? 'income' : 'expense',
        'categoryCode': preview.category,
        'note': preview.note,
        'source': 'text',
        ...LlmMimoReply(
          text: aiText,
          emotionAsset: preview.emotionAsset ?? 'Success',
        ).toStoryPersistFields(),
        if (preview.nlu != null) 'aiMeta': {'nlu': preview.nlu},
      });
      if (!mounted) return;
      notifyTransactionChanged();
      await StreakCelebration.instance.afterActivity(context);
      // Cập nhật trạng thái saved lên backend chat metadata
      if (_sessionId != null) {
        try {
          await _api.sendChatMessageRaw(_sessionId!, {
            'content': '💾 Đã lưu giao dịch',
            'role': 'assistant',
            'intentAction': {
              'saved': true,
              'category': preview.category,
              'amount': preview.amount,
            },
          });
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          msg.isSaved = false;
          _messages.insert(0, _ChatMsg(text: '❌ Không thể lưu giao dịch', isUser: false, time: _now()));
        });
      }
    }
  }

  void _showEditTxSheet(_ChatMsg msg) {
    if (msg.txPreview == null) return;
    _showEditTxPreviewSheet(msg, msg.txPreview!);
  }

  void _showEditTxPreviewSheet(_ChatMsg msg, _TxPreview preview) {
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

  Future<void> _saveMultiTransactions(_ChatMsg msg) async {
    if (msg.isSaved) return;
    final records = msg.multiRecords;
    if (records == null || records.isEmpty) return;
    setState(() {
      msg.isSaved = true;
    });
    try {
      final wallets = await _api.getWallets();
      if (wallets.isEmpty) {
        setState(() {
          msg.isSaved = false;
        });
        return;
      }
      for (final preview in records) {
        await _api.createTransaction({
          'walletId': widget.walletId ?? wallets[0]['id'],
          'amount': preview.amount,
          'type': preview.recordType == 'Income' ? 'income' : 'expense',
          'categoryCode': preview.category,
          'note': preview.note,
          'source': 'text',
          ...LlmMimoReply(
            text: 'Ghi nhận giao dịch tự động',
            emotionAsset: 'Success',
          ).toStoryPersistFields(),
        });
      }
      if (!mounted) return;
      notifyTransactionChanged();
      await StreakCelebration.instance.afterActivity(context);
      // Cập nhật trạng thái saved lên backend chat metadata
      if (_sessionId != null) {
        try {
          await _api.sendChatMessageRaw(_sessionId!, {
            'content': '💾 Đã lưu tất cả giao dịch',
            'role': 'assistant',
            'intentAction': {
              'saved': true,
              'multi_records': records.map((r) => {
                'category': r.category,
                'amount': r.amount,
              }).toList(),
            },
          });
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          msg.isSaved = false;
          _messages.insert(0, _ChatMsg(text: '❌ Không thể lưu giao dịch', isUser: false, time: _now()));
        });
      }
    }
  }
}

// ─── Models ──────────────────────────────────────────────────────────

class _ReportCategoryRow {
  final String categoryCode;
  final int total;
  final int percent;
  const _ReportCategoryRow({required this.categoryCode, required this.total, required this.percent});
}

class _ReportStoryPreview {
  final String periodLabel;
  final int totalExpense;
  final int totalIncome;
  final String? reportKind;
  final int transactionCount;
  final List<_ReportCategoryRow> categories;
  const _ReportStoryPreview({
    required this.periodLabel,
    required this.totalExpense,
    this.totalIncome = 0,
    this.reportKind,
    required this.transactionCount,
    required this.categories,
  });
}

class _TxPreview {
  String category;
  int amount;
  String note;
  String recordType;
  /// Cùng LLM reply — khi lưu story: [aiComment] + [emotionAsset] (avatar).
  String? emotionAsset;
  String? aiComment;
  final Map<String, dynamic>? nlu;
  _TxPreview({
    required this.category,
    required this.amount,
    required this.note,
    this.recordType = 'Expense',
    this.emotionAsset,
    this.aiComment,
    this.nlu,
  });
}

class _ChatMsg {
  final String text;
  final bool isUser;
  final String time;
  final _TxPreview? txPreview;
  final _ActionPreview? actionPreview;
  final _ReportStoryPreview? reportPreview;
  final _SearchResultPreview? searchPreview;
  final List<_TxPreview>? multiRecords;
  /// Emoji chat (cùng emotion LLM, khác tên với avatar story).
  final String? chatEmotion;
  bool isSaved;
  bool isConfirmed = false;
  bool isRejected = false;

  _ChatMsg({
    required this.text,
    required this.isUser,
    required this.time,
    this.txPreview,
    this.actionPreview,
    this.reportPreview,
    this.searchPreview,
    this.multiRecords,
    this.chatEmotion,
    this.isSaved = false,
  });
}

// ─── Widgets ─────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final String verbalStyle;
  final String personalityLabel;
  const _ChatHeader({required this.verbalStyle, required this.personalityLabel});

  @override
  Widget build(BuildContext ctx) {
    final mascotAsset = personalityMascotAsset(verbalStyle);
    final fallbackEmoji = verbalStyle == 'strict' ? '🔥' : '😎';

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
          child: ClipOval(
            child: Image.asset(
              mascotAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, e, s) => Center(child: Text(fallbackEmoji)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Chat với Mimo', style: Theme.of(ctx).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          Text(
            'Phong cách $personalityLabel · ghi nhận chi tiêu',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
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

/// Emoji phản hồi LLM trong bubble chat (không phải avatar story).
class _ChatEmotionSticker extends StatelessWidget {
  final String emotionAsset;
  const _ChatEmotionSticker({required this.emotionAsset});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        'assets/MiMo/emotions/$emotionAsset.png',
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
  final String summary;
  final String? aiLine;
  final int? amount;
  final String? categoryCode;
  final Map<String, dynamic>? actionDetails;
  final bool navOnly;
  const _ActionPreview({
    required this.actionType,
    required this.signature,
    required this.originalText,
    required this.summary,
    this.aiLine,
    this.amount,
    this.categoryCode,
    this.actionDetails,
    this.navOnly = false,
  });

  _ActionPreview copyWith({bool? navOnly}) => _ActionPreview(
        actionType: actionType,
        signature: signature,
        originalText: originalText,
        summary: summary,
        aiLine: aiLine,
        amount: amount,
        categoryCode: categoryCode,
        actionDetails: actionDetails,
        navOnly: navOnly ?? this.navOnly,
      );
}

class _SearchResultItem {
  final int amount;
  final String note;
  final String categoryCode;
  const _SearchResultItem({required this.amount, required this.note, required this.categoryCode});
}

class _SearchResultPreview {
  final List<_SearchResultItem> items;
  const _SearchResultPreview({required this.items});
}

class _ReportStoryCard extends StatelessWidget {
  final _ReportStoryPreview preview;
  const _ReportStoryCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    final topCats = preview.categories.take(5).toList();
    final maxCat = topCats.isEmpty ? 1 : topCats.map((c) => c.total).reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        gradient: LinearGradient(
          colors: [AppColors.teal.withValues(alpha: 0.08), context.palette.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
        boxShadow: context.palette.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: AppColors.teal.withValues(alpha: 0.12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.bar_chart_rounded, color: AppColors.teal, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                preview.periodLabel,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              preview.reportKind != null && preview.reportKind!.toUpperCase().contains('INCOME')
                  ? formatVnd(preview.totalIncome)
                  : formatVnd(preview.totalExpense),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.palette.textPrimary,
                    height: 1.1,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              preview.reportKind != null && preview.reportKind!.toUpperCase().contains('INCOME')
                  ? 'Tổng thu nhập'
                  : 'Tổng chi tiêu',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            if (preview.reportKind != null && preview.reportKind!.toUpperCase().contains('SAVING')) ...[
              const SizedBox(height: 4),
              Text(
                'Thu ${formatVnd(preview.totalIncome)} · Chi ${formatVnd(preview.totalExpense)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.teal),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              '${preview.transactionCount} khoản chi trong kỳ',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            if (topCats.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Theo danh mục', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...topCats.map((c) {
                final style = CategoryTheme.of(c.categoryCode);
                final barW = maxCat > 0 ? (c.total / maxCat).clamp(0.05, 1.0) : 0.05;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    SizedBox(width: 22, child: Text(style.emoji, style: const TextStyle(fontSize: 14))),
                    Expanded(
                      flex: 3,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(style.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text('${c.percent}%', style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ]),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: barW,
                            minHeight: 5,
                            backgroundColor: context.palette.surfaceAlt,
                            color: style.color,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Text(formatVnd(c.total), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ]),
                );
              }),
            ],
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => context.go(AppRoutes.report),
                icon: const Icon(Icons.arrow_forward_ios, size: 12),
                label: const Text('Xem chi tiết', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(foregroundColor: AppColors.teal, padding: EdgeInsets.zero),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _ActionConfirmCard extends StatelessWidget {
  final _ActionPreview preview;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;
  final bool isConfirmed;
  final bool isRejected;

  const _ActionConfirmCard({
    required this.preview,
    this.onConfirm,
    this.onReject,
    this.isConfirmed = false,
    this.isRejected = false,
  });

  IconData get _icon {
    final t = preview.actionType.toUpperCase();
    if (t.contains('DELETE')) return Icons.delete_outline;
    if (t.contains('LIMIT')) return Icons.speed;
    if (t.contains('GOAL')) return Icons.flag_outlined;
    if (t.contains('SEARCH')) return Icons.search;
    if (t.contains('TONE')) return Icons.record_voice_over_outlined;
    return Icons.settings_outlined;
  }

  Color get _accent {
    final t = preview.actionType.toUpperCase();
    if (t.contains('DELETE')) return AppColors.danger;
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(_icon, color: accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              preview.summary,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: accent),
            ),
          ),
        ]),
        if (preview.amount != null || preview.categoryCode != null) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (preview.categoryCode != null)
                _ActionChip(
                  icon: CategoryTheme.iconOf(preview.categoryCode!, size: 14),
                  label: CategoryTheme.of(preview.categoryCode!).label,
                ),
              if (preview.amount != null)
                _ActionChip(label: formatVnd(preview.amount!), accent: accent),
            ],
          ),
        ],
        if (preview.aiLine != null && preview.aiLine!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            preview.aiLine!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 10),
        if (isConfirmed)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: accent, size: 16),
              const SizedBox(width: 6),
              Text(
                preview.navOnly ? 'Đã mở' : 'Đã xác nhận',
                style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          )
        else if (isRejected)
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel, color: Colors.grey, size: 16),
              const SizedBox(width: 6),
              Text(
                'Đã bỏ qua',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          )
        else
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onReject,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  side: BorderSide(color: accent.withValues(alpha: 0.5)),
                ),
                child: Text(preview.navOnly ? 'Để sau' : 'Bỏ qua', style: TextStyle(fontSize: 12, color: accent)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                child: Text(preview.navOnly ? 'Mở' : 'Xác nhận', style: const TextStyle(fontSize: 12)),
              ),
            ),
          ]),
      ]),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final Widget? icon;
  final String label;
  final Color? accent;
  const _ActionChip({this.icon, required this.label, this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (accent ?? AppColors.teal).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[icon!, const SizedBox(width: 4)],
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accent ?? AppColors.teal)),
      ]),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  final _SearchResultPreview preview;
  const _SearchResultCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: preview.items.take(5).map((item) {
          final style = CategoryTheme.of(item.categoryCode);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text(style.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.note.isNotEmpty ? item.note : style.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Text(
                '-${formatVnd(item.amount)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.danger),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMsg message;
  final Future<void> Function(_ChatMsg)? onSaveTx;
  final Future<void> Function(_ChatMsg)? onSaveMultiTx;
  final Future<void> Function(_ChatMsg)? onConfirmAction;
  final Future<void> Function(_ChatMsg)? onRejectAction;
  final void Function(_ChatMsg)? onEditTxCategory;
  final void Function(_ChatMsg, _TxPreview)? onEditTxPreview;

  const _ChatBubble({
    required this.message,
    this.onSaveTx,
    this.onSaveMultiTx,
    this.onConfirmAction,
    this.onRejectAction,
    this.onEditTxCategory,
    this.onEditTxPreview,
  });

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
            if (!message.isUser && message.chatEmotion != null) ...[
              const SizedBox(height: 6),
              _ChatEmotionSticker(emotionAsset: message.chatEmotion!),
            ],
          ] else if (!message.isUser && message.chatEmotion != null) ...[
            _ChatEmotionSticker(emotionAsset: message.chatEmotion!),
          ],
          // Report story card
          if (message.reportPreview != null) ...[
            if (message.text.isNotEmpty || message.chatEmotion != null)
              const SizedBox(height: 8),
            _ReportStoryCard(preview: message.reportPreview!),
          ],
          // Action confirm/reject card
          if (message.actionPreview != null) ...[
            if (message.text.isNotEmpty || message.chatEmotion != null)
              const SizedBox(height: 8),
            _ActionConfirmCard(
              preview: message.actionPreview!,
              isConfirmed: message.isConfirmed,
              isRejected: message.isRejected,
              onConfirm: () => onConfirmAction?.call(message),
              onReject: () => onRejectAction?.call(message),
            ),
          ],
          if (message.searchPreview != null) ...[
            _SearchResultCard(preview: message.searchPreview!),
          ],
          // Transaction preview card
          if (message.txPreview != null) ...[
            if (message.text.isNotEmpty || message.chatEmotion != null)
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
          // Multi-transaction preview card
          if (message.multiRecords != null && message.multiRecords!.isNotEmpty) ...[
            if (message.text.isNotEmpty || message.chatEmotion != null)
              const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDFB),
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.playlist_add_check_rounded, color: AppColors.teal, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${message.multiRecords!.length} giao dịch được nhận dạng',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.teal)
                  ),
                ]),
                const SizedBox(height: 8),
                ...message.multiRecords!.map((record) {
                  final style = CategoryTheme.of(record.category);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(children: [
                      Text(style.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              style.label,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                            if (record.note.isNotEmpty)
                              Text(
                                record.note,
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '${record.recordType == 'Income' ? '+' : '-'}${formatVnd(record.amount)}',
                        style: TextStyle(
                          color: record.recordType == 'Income' ? const Color(0xFF22C55E) : AppColors.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      if (!message.isSaved) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => onEditTxPreview?.call(message, record),
                          child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.teal),
                        ),
                      ],
                    ]),
                  );
                }),
                const SizedBox(height: 4),
                message.isSaved
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, color: AppColors.teal, size: 16),
                          SizedBox(width: 6),
                          Text('Đã lưu tất cả giao dịch', style: TextStyle(color: AppColors.teal, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () => onSaveMultiTx?.call(message),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              child: const Text('💾 Lưu tất cả'),
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
  final VoidCallback onVoice;
  final bool voiceListening;
  final bool voiceAvailable;
  const _ChatComposer({
    required this.controller,
    required this.onSend,
    required this.onVoice,
    this.voiceListening = false,
    this.voiceAvailable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: context.palette.card,
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, -4))],
      ),
      child: Row(children: [
        if (voiceAvailable)
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: voiceListening ? AppColors.danger.withValues(alpha: 0.15) : context.palette.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: onVoice,
              icon: Icon(
                voiceListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                color: voiceListening ? AppColors.danger : AppColors.muted,
                size: 22,
              ),
            ),
          ),
        if (voiceAvailable) const SizedBox(width: 8),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => onSend(),
            decoration: InputDecoration(
              hintText: voiceListening ? 'Đang nghe...' : 'Nhắn tin cho Mimo...',
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