import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/chat_llm_notifier.dart';
import '../../services/streak_celebration.dart';
import '../../services/transaction_notifier.dart';
import '../../utils/mimo_emotion.dart';
import '../../utils/nlu_parse.dart';
import '../../utils/vn_time.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../theme/theme_controller.dart';
import '../../utils/formatters.dart';
import '../../utils/budget_prompt.dart';

String _actionSignatureFromNlu(Map<String, dynamic> nlu) {
  final fromApi = nluString(nlu['action_signature']);
  if (fromApi != null && fromApi.isNotEmpty) return fromApi;
  final actionType = (nluString(nlu['action_type']) ?? 'UNKNOWN').toUpperCase();
  final tr = nluMap(nlu['time_range']);
  if (tr != null)
    return '$actionType|${nluString(tr['granularity']) ?? 'default'}';
  final details = nluMap(nlu['action_details']);
  final amount = nlu['amount'] ?? nlu['action_param'] ?? details?['value'];
  final cat = _categoryFromNlu(nlu);
  if (actionType.contains('LIMIT')) {
    return '$actionType|${cat ?? 'all'}|$amount';
  }
  if (actionType.contains('DELETE')) return '$actionType|last';
  if (actionType.contains('GOAL')) return '$actionType|$amount';
  return '$actionType|default';
}

String? _categoryFromNlu(Map<String, dynamic> nlu) {
  final details = nluMap(nlu['action_details']);
  final target = nluString(details?['target']) ?? nluString(nlu['category']);
  if (target == null) return null;
  final canonical = CategoryTheme.canonicalCodeOf(target);
  if (CategoryTheme.styles.containsKey(canonical)) return canonical;
  final norm = target
      .toLowerCase()
      .replaceAll('ă', 'a')
      .replaceAll('â', 'a')
      .replaceAll('đ', 'd')
      .replaceAll('ê', 'e')
      .replaceAll('ô', 'o')
      .replaceAll('ơ', 'o')
      .replaceAll('ư', 'u');
  const viMap = {
    'an uong': 'Food',
    'di chuyen': 'Transport',
    'di lai': 'Transport',
    'mua sam': 'Shopping',
    'giai tri': 'Entertainment',
    'suc khoe': 'Health',
    'giao duc': 'Education',
    'lam dep': 'Beauty',
    'nha o': 'Housing',
  };
  for (final entry in viMap.entries) {
    if (norm.contains(entry.key)) return entry.value;
  }
  return null;
}

int? _amountFromNlu(Map<String, dynamic> nlu) {
  final details = nluMap(nlu['action_details']);
  final raw = nlu['amount'] ?? nlu['action_param'] ?? details?['value'];
  return nluInt(raw);
}

String _actionSummary(String actionType, {int? amount, String? categoryCode, String? verb}) {
  final t = actionType.toUpperCase();
  final v = (verb ?? '').toUpperCase();
  final amt = amount != null ? formatVnd(amount) : null;
  final catLabel = categoryCode != null
      ? CategoryTheme.of(categoryCode).label
      : null;
  String verbLabel(String base) {
    if (v == 'ADD') return 'Tăng $base';
    if (v == 'SUB') return 'Giảm $base';
    if (v == 'SET') return 'Đặt $base';
    return base;
  }
  if (t.contains('LIMIT') || t == 'SET_LIMIT') {
    return '${verbLabel('hạn mức')}${catLabel != null ? ' $catLabel' : ''}${amt != null ? ': $amt' : ''}';
  }
  if (t.contains('DELETE')) return 'Xóa giao dịch gần nhất';
  if (t.contains('GOAL') || t == 'SET_GOAL' || t == 'ADD_GOAL') {
    return '${verbLabel('mục tiêu')}${amt != null ? ' $amt' : ''}';
  }
  if (t.contains('TONE')) return 'Đổi giọng nói Mimo';
  if (t.contains('SEARCH')) return 'Tìm kiếm giao dịch';
  if (t.contains('SETTING')) return 'Mở cài đặt ứng dụng';
  if (t.contains('SUGGEST')) return 'Gợi ý hạn mức thông minh';
  if (t == 'SET_USERNAME') return 'Đổi tên Mimo gọi bạn';
  if (t == 'SET_INCOME') {
    return 'Cài thu nhập hàng tháng${amt != null ? ': $amt' : ''}';
  }
  if (t == 'UPDATE_RECORD' || t == 'EDIT') {
    return 'Sửa giao dịch gần nhất${catLabel != null ? ' ($catLabel)' : ''}${amt != null ? ': $amt' : ''}';
  }
  if (t == 'SET_ALERT') {
    return 'Cài cảnh báo chi tiêu${catLabel != null ? ' $catLabel' : ''}';
  }
  if (t == 'EXPORT_DATA') return 'Xuất dữ liệu chi tiêu';
  return '$actionType${v.isNotEmpty ? ' ($v)' : ''}';
}

_ActionPreview _actionPreviewFromNlu(
  Map<String, dynamic> nlu,
  String userText, {
  String? aiLine,
}) {
  final actionType = nlu['action_type'] as String? ?? 'Unknown';
  final amount = _amountFromNlu(nlu);
  final t = actionType.toUpperCase();
  final needsCategory =
      t.contains('LIMIT') ||
      t.contains('SEARCH') ||
      t == 'UPDATE_RECORD' ||
      t == 'EDIT' ||
      t == 'SET_ALERT';
  final categoryCode = needsCategory ? _categoryFromNlu(nlu) : null;
  final details = nluMap(nlu['action_details']);
  final verb = nluString(details?['verb']);
  return _ActionPreview(
    actionType: actionType,
    signature: _actionSignatureFromNlu(nlu),
    originalText: userText,
    amount: amount,
    categoryCode: categoryCode,
    summary: _actionSummary(
      actionType,
      amount: amount,
      categoryCode: categoryCode,
      verb: verb,
    ),
    actionDetails: nlu['action_details'] as Map<String, dynamic>?,
    aiLine: aiLine,
  );
}

Map<String, dynamic> _executeBodyFromPreview(_ActionPreview preview) {
  final details = preview.actionDetails;
  final goalName = nluString(details?['goal_name']) ?? nluString(details?['goalName']);
  final timeLabel = nluString(details?['time']) ?? nluString(details?['time_range']);
  final query = nluString(details?['query']);
  return {
    'actionType': preview.actionType,
    if (preview.amount != null) 'amount': preview.amount,
    if (preview.categoryCode != null) 'categoryCode': preview.categoryCode,
    if (goalName != null && goalName.isNotEmpty) 'goalName': goalName,
    if (query != null && query.isNotEmpty) 'query': query,
    'text': preview.originalText,
    if (preview.actionDetails != null) 'actionDetails': preview.actionDetails,
    if (timeLabel != null && timeLabel.isNotEmpty)
      'timeRange': {'period_label': timeLabel},
  };
}

_SearchResultPreview? _searchPreviewFromResult(Map<String, dynamic> result) {
  if (result['kind'] != 'search') return null;
  final items = (result['items'] as List<dynamic>? ?? []).map((e) {
    final m = nluMap(e) ?? {};
    return _SearchResultItem(
      amount: nluInt(m['amount']) ?? 0,
      note: nluString(m['note']) ?? '',
      categoryCode: nluString(m['categoryCode']) ?? 'Others',
    );
  }).toList();
  if (items.isEmpty) return null;
  return _SearchResultPreview(items: items);
}

_BudgetSuggestionPreview? _budgetSuggestionFromResult(
  Map<String, dynamic> result,
) {
  if (result['kind'] != 'budget_suggestion') return null;
  final targetMonth = nluString(result['targetMonth']) ?? '';
  if (targetMonth.isEmpty) return null;
  final items = (result['suggestions'] as List<dynamic>? ?? []).map((e) {
    final m = nluMap(e) ?? {};
    return _BudgetSuggestionItem(
      categoryCode: nluString(m['categoryCode']) ?? 'Other',
      suggestedAmount: nluInt(m['suggestedAmount']) ?? 0,
      baseSpending: nluInt(m['baseSpending']) ?? 0,
      reason: nluString(m['reason']) ?? '',
    );
  }).toList();
  if (items.isEmpty) return null;
  return _BudgetSuggestionPreview(
    targetMonth: targetMonth,
    items: items,
    totalSuggested: nluInt(result['totalSuggested']) ??
        items.fold<int>(0, (s, i) => s + i.suggestedAmount),
  );
}

String _formatTargetMonthLabel(String targetMonth) {
  final parts = targetMonth.split('-');
  if (parts.length != 2) return targetMonth;
  final month = int.tryParse(parts[1]);
  if (month == null) return targetMonth;
  return 'tháng $month/${parts[0]}';
}

bool _actionNeedsConfirm(String actionType) {
  final t = actionType.toUpperCase();
  if (t.contains('REPORT')) return false;
  if (t.contains('SUGGEST')) return false;
  if (t == 'SETTING' || t == 'SYSTEM_SETTING') return false;
  if (t == 'EXPORT_DATA') return false;
  return t.contains('LIMIT') ||
      t.contains('GOAL') ||
      t.contains('TONE') ||
      t.contains('SEARCH') ||
      t == 'SET_USERNAME' ||
      t == 'SET_ALERT';
}

_ReportStoryPreview? _reportPreviewFromNlu(Map<String, dynamic> nlu) {
  final ar = nluMap(nlu['action_result']);
  if (ar == null) return null;
  final cats = (ar['by_category'] as List<dynamic>? ?? []).map((c) {
    final m = nluMap(c) ?? {};
    return _ReportCategoryRow(
      categoryCode: nluString(m['categoryCode']) ?? 'Others',
      total: nluInt(m['total']) ?? 0,
      percent: nluInt(m['percent']) ?? 0,
    );
  }).toList();
  final kind = nluString(ar['report_kind']) ?? nluString(nlu['action_type']);
  return _ReportStoryPreview(
    periodLabel:
        nluString(ar['period_label']) ??
        nluString(nluMap(nlu['time_range'])?['period_label']) ??
        'Báo cáo',
    totalExpense: nluInt(ar['total_expense']) ?? 0,
    totalIncome: nluInt(ar['total_income']) ?? 0,
    reportKind: kind,
    transactionCount: nluInt(ar['transaction_count']) ?? 0,
    categories: cats,
  );
}

class ChatScreen extends StatefulWidget {
  /// Optional sessionId passed from ChatHistoryScreen (CHH-02)
  final String? sessionId;
  final String? walletId;
  final bool forceNew;
  const ChatScreen({
    super.key,
    this.sessionId,
    this.walletId,
    this.forceNew = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiClient();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _messages = [];

  bool _aiThinking = false;
  bool _loadingOlder = false;
  bool _hasMoreHistory = false;

  /// Tránh gọi load-more khi ListView reverse vừa layout (chưa ổn scroll).
  bool _readyForOlderLoad = false;
  String _verbalStyle = 'funny';
  String? _sessionId;
  String? _walletId;
  String? _oldestMessageId;

  static const List<String> _candidateSuggestions = [
    'Thống kê chi tiêu tuần này',
    'Tổng chi tiêu tháng này',
    'Tháng trước chi hết bao nhiêu?',
    'Hôm nay tiêu gì rồi?',
    'Ăn sáng 35k',
    'Mua trà sữa 45k',
    'Đổ xăng 50k',
    'Đặt hạn mức Ăn uống 3 triệu',
    'Xem hạn mức tháng này',
    'Tìm các giao dịch ăn uống',
    'Đặt mục tiêu tiết kiệm 10 triệu',
    'Đổi giọng nói của Mimo sang dui dẻ',
    'Chuyển sang giao diện tối',
    'Gợi ý hạn mức tháng mới',
    'Xem báo cáo chi tiêu hôm qua',
    'So sánh chi tiêu tuần này với tuần trước',
    'Gợi ý chi tiêu tháng sau',
    'Đã nhận lương tháng này 12 triệu',
    'Tìm các giao dịch trên 1 triệu',
    'Tăng hạn mức đi lại lên 2 triệu',
    'Mẹ cho 500k ăn sáng',
    'Bù 200k vào mục tiêu mua điện thoại',
    'Bật cảnh báo vượt hạn mức mua sắm',
    'Giảm giới hạn giải trí đi 100k',
  ];

  final List<String> _suggestions = [];

  void _generateRandomSuggestions() {
    final list = List<String>.from(_candidateSuggestions);
    list.shuffle();
    _suggestions
      ..clear()
      ..addAll(list.take(4));
  }

  @override
  void initState() {
    super.initState();
    _generateRandomSuggestions();
    _scrollCtrl.addListener(_onScrollLoadOlder);
    chatLlmUpdateNotifier.addListener(_onChatLlmUpdateNotifier);
    _initSession();
    _loadAiPersonality();
  }

  void _onChatLlmUpdateNotifier() {
    final update = chatLlmUpdateNotifier.value;
    if (update == null || !mounted) return;
    if (update.sessionId != _sessionId) return;
    setState(() {
      for (final msg in _messages) {
        if (msg.backendMessageId != update.messageId) continue;
        msg.llmPending = false;
        if (update.failed || update.content == null) return;
        msg.text = update.content!;
        if (update.mood != null && update.mood!.isNotEmpty) {
          msg.chatEmotion = update.mood;
        }
        if (msg.txPreview != null) {
          msg.txPreview!.aiComment = update.content;
          if (update.mood != null) {
            msg.txPreview!.emotionAsset = update.mood;
          }
        }
        if (msg.actionPreview != null) {
          msg.actionPreview = msg.actionPreview!.copyWith(aiLine: update.content);
        }
        break;
      }
    });
  }

  Future<void> _loadAiPersonality() async {
    try {
      final settings = await _api.getSettings();
      if (!mounted) return;
      setState(
        () => _verbalStyle = normalizeVerbalStyle(
          settings['verbal_style'] as String?,
        ),
      );
    } catch (_) {}
  }

  @override
  void activate() {
    super.activate();
    _loadAiPersonality();
  }

  @override
  void dispose() {
    chatLlmUpdateNotifier.removeListener(_onChatLlmUpdateNotifier);
    _scrollCtrl.removeListener(_onScrollLoadOlder);
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
      final map = nluMap(m);
      if (map == null) continue;
      final role = nluString(map['role']) ?? 'user';
      final metadata = nluMap(
        map['intent_action'] ?? map['intentAction'] ?? map['metadata'],
      );

      _TxPreview? txPreview;
      _ActionPreview? actionPreview;
      _ReportStoryPreview? reportPreview;
      _SearchResultPreview? searchPreview;
      _BudgetSuggestionPreview? budgetSuggestionPreview;
      List<_TxPreview>? multiRecords;
      String? chatEmotion;
      var displayText = nluString(map['content']) ?? '';

      if (metadata != null && role != 'user') {
        final statusEvent = nluMap(metadata['budget_status_event']);
        if (statusEvent != null) {
          final targetMonth = nluString(statusEvent['targetMonth']);
          final status = nluString(statusEvent['status']);
          for (int i = out.length - 1; i >= 0; i--) {
            final prevMsg = out[i];
            if (prevMsg.budgetSuggestionPreview?.targetMonth == targetMonth) {
              if (status == 'applied') prevMsg.isBudgetApplied = true;
              if (status == 'dismissed') prevMsg.isBudgetDismissed = true;
              break;
            }
          }
          continue;
        }

        final actionResult = nluMap(metadata['action_result']);
        if (metadata['action_executed'] == true && actionResult != null) {
          budgetSuggestionPreview = _budgetSuggestionFromResult(actionResult);
          searchPreview = _searchPreviewFromResult(actionResult);
          final resultText = nluString(actionResult['message']);
          if (resultText != null && resultText.isNotEmpty) {
            displayText = resultText;
          }
        }

        final llmMeta = llmReplyFromChatMetadata(
          metadata,
          fallbackText: displayText,
        );
        chatEmotion = llmMeta?.emotionAsset;

        final rawMulti = metadata['multi_records'] ?? metadata['multiRecords'];
        if (rawMulti is List && rawMulti.length >= 2) {
          multiRecords = rawMulti.map((r) {
            final rMap = nluMap(r) ?? {};
            return _TxPreview(
              category: nluString(rMap['category']) ?? 'Other',
              amount: nluInt(rMap['amount']) ?? 0,
              note: nluString(rMap['text']) ?? nluString(rMap['note']) ?? '',
              recordType: nluString(rMap['record_type']) ?? 'Expense',
              transactionId: nluString(
                rMap['transaction_id'] ?? rMap['transactionId'],
              ),
            );
          }).toList();
        }

        final nlu = nluMap(metadata['nlu']);
        if (nlu != null) {
          final intent = nluString(metadata['intent']);
          if (intent == 'Record' && multiRecords == null) {
            final amount =
                metadata['amount'] ?? nlu['amount_spent'] ?? nlu['amount'];
            final amountInt = nluInt(amount) ?? 0;
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
              transactionId: nluString(
                metadata['transaction_id'] ?? metadata['transactionId'],
              ),
            );
          } else if (intent == 'Action' && metadata['action_executed'] != true) {
            final report = _reportPreviewFromNlu(nlu);
            if (report != null) {
              reportPreview = report;
              if (llmMeta != null && llmMeta.text.isNotEmpty) {
                displayText = llmMeta.text;
              }
            } else {
              final llmText = (llmMeta?.text ?? displayText).trim();
              final originalUser =
                  nluString(nlu['text']) ??
                  nluString(nlu['clean_content']) ??
                  '';
              actionPreview = _actionPreviewFromNlu(
                nlu,
                originalUser,
                aiLine: llmText.isNotEmpty ? llmText : null,
              );
              if (llmText.isNotEmpty) {
                displayText = llmText;
              }
            }
          }
        }
      }

      // Đọc trạng thái saved từ metadata thay vì mặc định true
      final nlu = metadata != null ? nluMap(metadata['nlu']) : null;
      final intentConfidence =
          nluDouble(nlu?['intent_confidence']) ??
          nluDouble(nlu?['confidence']) ??
          0.0;
      final autoSaved =
          intentConfidence >= 0.9 &&
          (txPreview != null || multiRecords != null);
      final savedFlag = (metadata?['saved'] == true) || autoSaved;

      final newMsg = _ChatMsg(
        text: displayText,
        isUser: role == 'user',
        time: _formatMsgTime(nluString(map['created_at'])),
        chatEmotion: chatEmotion,
        backendMessageId: nluString(map['id']),
        txPreview: txPreview,
        actionPreview: actionPreview,
        reportPreview: reportPreview,
        searchPreview: searchPreview,
        budgetSuggestionPreview: budgetSuggestionPreview,
        multiRecords: multiRecords,
        isSaved: (txPreview != null || multiRecords != null) && savedFlag,
      );

      // Nếu tin nhắn hiện tại là tin xác nhận đã lưu ("saved": true)
      if (metadata != null && metadata['saved'] == true && role != 'user') {
        // Tìm ngược trong danh sách 'out' để đánh dấu tin nhắn gốc là đã lưu
        for (int i = out.length - 1; i >= 0; i--) {
          final prevMsg = out[i];
          if (prevMsg.txPreview != null || prevMsg.multiRecords != null) {
            if (!prevMsg.isSaved) {
              prevMsg.isSaved = true;
              // Chuyển transactionId(s) sang parent preview
              if (prevMsg.txPreview != null) {
                prevMsg.txPreview!.transactionId = nluString(
                  metadata['transaction_id'] ?? metadata['transactionId'],
                );
              } else if (prevMsg.multiRecords != null &&
                  metadata['multi_records'] is List) {
                final list = metadata['multi_records'] as List;
                for (
                  int j = 0;
                  j < prevMsg.multiRecords!.length && j < list.length;
                  j++
                ) {
                  final item = list[j];
                  final itemMap = nluMap(item);
                  if (itemMap != null) {
                    prevMsg.multiRecords![j].transactionId = nluString(
                      itemMap['transaction_id'] ?? itemMap['transactionId'],
                    );
                  }
                }
              }
              break;
            }
          }
        }
        // Không hiển thị tin nhắn xác nhận "đã lưu" — chỉ đánh dấu parent
        continue;
      }

      out.add(newMsg);
    }
    return out;
  }

  Future<void> _loadMessagesPage({
    String? before,
    bool loadOlder = false,
  }) async {
    if (_sessionId == null) return;
    final page = await _api.getChatMessagesPage(
      _sessionId!,
      limit: 30,
      before: before,
    );
    if (!mounted) return;
    final parsed = _parseMessagesFromApi(
      page['messages'] as List<dynamic>? ?? [],
    );
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
        _api.aiIsActionConfirmed(msg.actionPreview!.signature).then((
          confirmed,
        ) {
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

  Future<void> _initSession() async {
    _walletId = widget.walletId ?? ApiClient.lastSelectedWalletId;
    // If sessionId passed from history, reuse it and load messages
    if (widget.sessionId != null) {
      _sessionId = widget.sessionId;
      try {
        await _loadMessagesPage();
      } catch (_) {}

      // Robust fallback: if _walletId is null, fetch sessions and resolve it
      if (_walletId == null) {
        try {
          final sessions = await _api.getChatSessions();
          final matched = sessions.firstWhere(
            (s) => s['id'] == _sessionId,
            orElse: () => null,
          );
          if (matched != null) {
            setState(() {
              _walletId =
                  matched['wallet_id'] as String? ??
                  matched['walletId'] as String?;
            });
          }
        } catch (_) {}
      }
      return;
    }

    try {
      // 1. Resolve target wallet ID
      if (_walletId == null) {
        final wallets = await _api.getWallets();
        if (wallets.isNotEmpty) {
          _walletId = wallets[0]['id'] as String?;
        }
      }

      // 2. Try to find existing session if not forced to create a new one
      if (!widget.forceNew) {
        final sessions = await _api.getChatSessions();
        final matched = sessions.firstWhere(
          (s) => s['wallet_id'] == _walletId || s['walletId'] == _walletId,
          orElse: () => null,
        );
        if (matched != null) {
          _sessionId = matched['id'] as String?;
          if (mounted) {
            await _loadMessagesPage();
          }
          return;
        }
      }

      // 3. Create a new session
      String walletName = 'Ví cá nhân';
      if (_walletId != null) {
        try {
          final wallet = await _api.getWallet(_walletId!);
          walletName = wallet['name'] as String? ?? 'Ví';
        } catch (_) {}
      }

      final session = await _api.createChatSession(
        title: 'Chat $walletName',
        walletId: _walletId,
      );
      _sessionId = session['id'] as String?;
      if (mounted) {
        await _loadMessagesPage();
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
      _generateRandomSuggestions();
    });
    _scrollToBottom();

    if (_sessionId == null) {
      try {
        await _initSession();
      } catch (e) {
        debugPrint('Failed to initialize session: $e');
      }
      if (_sessionId == null) {
        if (!mounted) return;
        setState(() {
          _aiThinking = false;
          _messages.insert(
            0,
            _ChatMsg(
              text:
                  'Mimo chưa kết nối được. Vui lòng kiểm tra mạng và thử lại nhé! 🌐',
              isUser: false,
              time: _now(),
            ),
          );
        });
        _scrollToBottom();
        return;
      }
    }

    // Save to backend chat
    if (_sessionId != null) {
      try {
        await _api.sendChatMessage(_sessionId!, userText);
      } catch (_) {}
    }

    try {
      final chatRes = await _api.aiChat(_sessionId!, userText);
      final intentAction =
          chatRes['intentAction'] as Map<String, dynamic>? ?? {};
      final assistantMsgMap = {
        'role': 'assistant',
        'content': chatRes['response'] as String? ?? '',
        'intent_action': intentAction,
        'id': chatRes['messageId'],
        'created_at': DateTime.now().toIso8601String(),
      };

      final parsed = _parseMessagesFromApi([assistantMsgMap]);
      if (parsed.isNotEmpty) {
        final confirmMsg = parsed.first;
        if (chatRes['llmPending'] == true) {
          confirmMsg.llmPending = true;
        }
        if (chatRes['messageId'] != null) {
          confirmMsg.backendMessageId = chatRes['messageId'] as String?;
        }

        // Handle confirm status for actions if already confirmed
        if (confirmMsg.actionPreview != null) {
          final alreadyConfirmed = await _api.aiIsActionConfirmed(
            confirmMsg.actionPreview!.signature,
          );
          if (alreadyConfirmed) {
            confirmMsg.isConfirmed = true;
          }
        }

        if (!mounted) return;
        setState(() {
          _aiThinking = false;
          _messages.insert(0, confirmMsg);
        });
        _scrollToBottom();

        // Run non-confirm actions directly, or automatically run confirmed ones
        if (confirmMsg.actionPreview != null) {
          final action = confirmMsg.actionPreview!;
          if (!_actionNeedsConfirm(action.actionType) ||
              confirmMsg.isConfirmed) {
            await _runConfirmedAction(action);
          }
        }

        // Auto save transactions if confidence is high
        final nlu = intentAction['nlu'] as Map<String, dynamic>? ?? {};
        final intentConfidence =
            nluDouble(nlu['intent_confidence']) ??
            nluDouble(nlu['confidence']) ??
            0;
        final willAutoSave =
            intentConfidence >= 0.9 &&
            (confirmMsg.txPreview != null || confirmMsg.multiRecords != null);
        if (willAutoSave) {
          confirmMsg.isSaved = true;
        }
        if (confirmMsg.txPreview != null && intentConfidence >= 0.9) {
          await _saveTransaction(confirmMsg, force: true);
        } else if (confirmMsg.multiRecords != null && intentConfidence >= 0.9) {
          await _saveMultiTransactions(confirmMsg, force: true);
        }
      }

      if (mounted) {
        await StreakCelebration.instance.afterActivity(context);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _aiThinking = false;
        _messages.insert(
          0,
          _ChatMsg(text: e.localizedMessage, isUser: false, time: _now()),
        );
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Chat NLU error: $e');
      if (!mounted) return;
      setState(() {
        _aiThinking = false;
        _messages.insert(
          0,
          _ChatMsg(
            text: 'Mimo gặp lỗi rồi 😅 Thử lại sau nhé!',
            isUser: false,
            time: _now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  String _now() => VnTime.formatHmNow();

  Future<void> _persistActionResultMessage(
    String content,
    Map<String, dynamic> result,
  ) async {
    if (_sessionId == null) return;
    try {
      await _api.sendChatMessageRaw(_sessionId!, {
        'content': content,
        'role': 'assistant',
        'intentAction': {
          'intent': 'Action',
          'action_executed': true,
          'action_result': result,
        },
      });
    } catch (_) {}
  }

  Future<void> _persistBudgetStatusEvent(
    String targetMonth,
    String status,
  ) async {
    if (_sessionId == null) return;
    try {
      await _api.sendChatMessageRaw(_sessionId!, {
        'content': '.',
        'role': 'assistant',
        'intentAction': {
          'budget_status_event': {
            'targetMonth': targetMonth,
            'status': status,
          },
        },
      });
    } catch (_) {}
  }

  Future<void> _runConfirmedAction(_ActionPreview action) async {
    try {
      if (action.navOnly) {
        await _api.aiConfirmAction(
          action.signature,
          actionType: action.actionType,
        );
        if (!mounted) return;
        context.go(AppRoutes.settings);
        return;
      }

      final result = await _api.aiExecuteAction(
        _executeBodyFromPreview(action),
      );
      await _api.aiConfirmAction(
        action.signature,
        actionType: action.actionType,
      );
      if (!mounted) return;

      final message =
          result['message'] as String? ?? '✅ Đã thực hiện hành động!';
      final searchPreview = _searchPreviewFromResult(result);
      final budgetPreview = _budgetSuggestionFromResult(result);
      final kind = result['kind'] as String?;

      if (kind == 'delete') notifyTransactionChanged();
      if (kind == 'theme') {
        final themeModeVal = result['themeMode'] as bool?;
        if (themeModeVal != null) {
          ThemeController.instance.setMode(
            themeModeVal ? ThemeMode.dark : ThemeMode.light,
          );
        }
      }

      setState(() {
        _messages.insert(
          0,
          _ChatMsg(
            text: message,
            isUser: false,
            time: _now(),
            searchPreview: searchPreview,
            budgetSuggestionPreview: budgetPreview,
          ),
        );
      });
      _scrollToBottom();

      if (searchPreview != null || budgetPreview != null) {
        await _persistActionResultMessage(message, result);
      }

      final navigate = result['navigate'] as String?;
      if (navigate == 'settings') context.go(AppRoutes.settings);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.insert(
          0,
          _ChatMsg(
            text: '❌ Không thực hiện được hành động.',
            isUser: false,
            time: _now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  Future<void> _handleBudgetApply(_ChatMsg msg) async {
    if (msg.isBudgetApplied || msg.budgetSuggestionPreview == null) return;
    final preview = msg.budgetSuggestionPreview!;
    setState(() => msg.isBudgetApplied = true);
    try {
      final res = await _api.applyBudgetSuggestions(month: preview.targetMonth);
      if (!mounted) return;
      setState(() {
        _messages.insert(
          0,
          _ChatMsg(
            text:
                res['message'] as String? ??
                '✅ Đã áp dụng hạn mức thông minh!',
            isUser: false,
            time: _now(),
          ),
        );
      });
      _scrollToBottom();
      await _persistBudgetStatusEvent(preview.targetMonth, 'applied');
    } catch (_) {
      if (!mounted) return;
      setState(() => msg.isBudgetApplied = false);
      setState(() {
        _messages.insert(
          0,
          _ChatMsg(
            text: '❌ Không áp dụng được gợi ý. Thử lại sau nhé!',
            isUser: false,
            time: _now(),
          ),
        );
      });
      _scrollToBottom();
    }
  }

  Future<void> _handleBudgetDismiss(_ChatMsg msg) async {
    if (msg.isBudgetDismissed || msg.budgetSuggestionPreview == null) return;
    final preview = msg.budgetSuggestionPreview!;
    setState(() => msg.isBudgetDismissed = true);
    try {
      final message =
          await _api.dismissBudgetSuggestions(month: preview.targetMonth);
      if (!mounted) return;
      setState(() {
        _messages.insert(
          0,
          _ChatMsg(text: message, isUser: false, time: _now()),
        );
      });
      _scrollToBottom();
      await _persistBudgetStatusEvent(preview.targetMonth, 'dismissed');
    } catch (_) {
      if (!mounted) return;
      setState(() => msg.isBudgetDismissed = false);
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
              walletId: _walletId,
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xxl,
                  vertical: AppSpacing.lg,
                ),
                itemCount:
                    _messages.length +
                    (_aiThinking ? 1 : 0) +
                    (_loadingOlder ? 1 : 0),
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
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  return _ChatBubble(
                    message: _messages[msgIndex],
                    onSaveTx: _saveTransaction,
                    onSaveMultiTx: _saveMultiTransactions,
                    onConfirmAction: _handleActionConfirm,
                    onRejectAction: _handleActionReject,
                    onApplyBudgetSuggestion: _handleBudgetApply,
                    onDismissBudgetSuggestion: _handleBudgetDismiss,
                    onEditTxCategory: _showEditTxSheet,
                    onEditTxPreview: _showEditTxPreviewSheet,
                  );
                },
              ),
            ),
            // Quick action chips
            if (_suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (int i = 0; i < _suggestions.length; i++) ...[
                        _QuickChip(
                          label: _suggestions[i],
                          onTap: () => _sendMessage(_suggestions[i]),
                        ),
                        if (i < _suggestions.length - 1)
                          const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
            _ChatComposer(
              controller: _inputCtrl,
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
      await _api.aiRejectAction(
        text: action.originalText,
        predicted: {
          'action_type': action.actionType,
          'intent': 'Action',
        },
      );
      if (!mounted) return;
      setState(() {
        _messages.insert(
          0,
          _ChatMsg(
            text: '❌ Đã bỏ qua. Mimo sẽ cải thiện sau!',
            isUser: false,
            time: _now(),
          ),
        );
      });
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _saveTransaction(_ChatMsg msg, {bool force = false}) async {
    if (msg.isSaved && !force) return;
    final preview = msg.txPreview;
    if (preview == null) return;
    final wasSavedBefore = msg.isSaved;
    if (!msg.isSaved) {
      setState(() {
        msg.isSaved = true;
      });
    }
    try {
      final wallets = await _api.getWallets();
      if (wallets.isEmpty) {
        setState(() {
          msg.isSaved = false;
        });
        return;
      }
      final aiText = (preview.aiComment ?? msg.text).trim();
      final originalUserText = preview.nlu?['text'] as String? ?? preview.note;
      final tx = await _api.createTransaction({
        'walletId': _walletId ?? widget.walletId ?? wallets[0]['id'],
        'amount': preview.amount,
        'type': preview.recordType == 'Income' ? 'income' : 'expense',
        'categoryCode': preview.category,
        'note': preview.note,
        'originalText': originalUserText,
        'source': 'text',
        ...LlmMimoReply(
          text: aiText,
          emotionAsset: preview.emotionAsset ?? 'Success',
        ).toStoryPersistFields(),
        if (preview.nlu != null) 'aiMeta': {'nlu': preview.nlu},
      });
      preview.transactionId = tx['id'] as String?;

      if (!mounted) return;
      notifyTransactionChanged();
      await StreakCelebration.instance.afterActivity(context);
      if (mounted) {
        checkCategoryLimitAndSuggest(context, preview.category);
      }
      // Cập nhật trạng thái saved lên backend chat metadata
      if (_sessionId != null && !wasSavedBefore) {
        try {
          await _api.sendChatMessageRaw(_sessionId!, {
            'content': '💾 Đã lưu giao dịch',
            'role': 'assistant',
            'intentAction': {
              'saved': true,
              'category': preview.category,
              'amount': preview.amount,
              'transactionId': preview.transactionId,
            },
          });
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          msg.isSaved = false;
          _messages.insert(
            0,
            _ChatMsg(
              text: '❌ Không thể lưu giao dịch',
              isUser: false,
              time: _now(),
            ),
          );
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
    // Chuẩn hóa category code để tránh crash DropdownButton khi value là alias
    String editCategory = CategoryTheme.canonicalCodeOf(preview.category);
    if (!CategoryTheme.primaryCodes.contains(editCategory)) {
      editCategory = 'Other';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: ctx.palette.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.xl),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Chỉnh sửa giao dịch',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Số tiền',
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Nhập số tiền',
                    suffixText: 'đ',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Danh mục',
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: editCategory,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  items: CategoryTheme.styles.entries
                      .where((e) => CategoryTheme.primaryCodes.contains(e.key))
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Row(
                            children: [
                              CategoryTheme.iconOf(e.key, size: 22),
                              const SizedBox(width: 8),
                              Text(e.value.label),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => editCategory = val);
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Ghi chú',
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ghi chú cho giao dịch',
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final parsedAmount =
                          int.tryParse(amountCtrl.text) ?? preview.amount;
                      final updatedNote = noteCtrl.text;
                      final updatedCategory = editCategory;
                      final oldCategory = preview.category;

                      setState(() {
                        preview.amount = parsedAmount;
                        preview.note = updatedNote;
                        preview.category = updatedCategory;
                      });

                      if (msg.isSaved && preview.transactionId != null) {
                        try {
                          await _api.updateTransaction(preview.transactionId!, {
                            'amount': parsedAmount,
                            'note': updatedNote,
                            'categoryCode': updatedCategory,
                          });
                          notifyTransactionChanged();

                          // Ghi nhận correction cho NLU learning khi đổi category
                          if (oldCategory != updatedCategory) {
                            try {
                              await _api.aiCorrection({
                                'text': preview.note,
                                'correctedCategory': updatedCategory,
                                'originalCategory': oldCategory,
                                'source': 'chat_edit',
                              });
                            } catch (_) {}
                          }
                        } catch (_) {}
                      }
                      if (ctx.mounted) {
                        ctx.pop();
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Lưu chỉnh sửa'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveMultiTransactions(
    _ChatMsg msg, {
    bool force = false,
  }) async {
    if (msg.isSaved && !force) return;
    final records = msg.multiRecords;
    if (records == null || records.isEmpty) return;
    final wasSavedBefore = msg.isSaved;
    if (!msg.isSaved) {
      setState(() {
        msg.isSaved = true;
      });
    }
    try {
      final wallets = await _api.getWallets();
      if (wallets.isEmpty) {
        setState(() {
          msg.isSaved = false;
        });
        return;
      }
      for (final preview in records) {
        final tx = await _api.createTransaction({
          'walletId': _walletId ?? widget.walletId ?? wallets[0]['id'],
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
        preview.transactionId = tx['id'] as String?;
      }
      if (!mounted) return;
      notifyTransactionChanged();
      await StreakCelebration.instance.afterActivity(context);
      if (mounted && records.isNotEmpty) {
        checkCategoryLimitAndSuggest(context, records.first.category);
      }
      // Cập nhật trạng thái saved lên backend chat metadata
      if (_sessionId != null && !wasSavedBefore) {
        try {
          await _api.sendChatMessageRaw(_sessionId!, {
            'content': '💾 Đã lưu tất cả giao dịch',
            'role': 'assistant',
            'intentAction': {
              'saved': true,
              'multi_records': records
                  .map(
                    (r) => {
                      'category': r.category,
                      'amount': r.amount,
                      'transactionId': r.transactionId,
                    },
                  )
                  .toList(),
            },
          });
        } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          msg.isSaved = false;
          _messages.insert(
            0,
            _ChatMsg(
              text: '❌ Không thể lưu giao dịch',
              isUser: false,
              time: _now(),
            ),
          );
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
  const _ReportCategoryRow({
    required this.categoryCode,
    required this.total,
    required this.percent,
  });
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
  String? transactionId;

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
    this.transactionId,
  });
}

class _ChatMsg {
  String text;
  final bool isUser;
  final String time;
  String? backendMessageId;
  bool llmPending;
  final _TxPreview? txPreview;
  _ActionPreview? actionPreview;
  final _ReportStoryPreview? reportPreview;
  final _SearchResultPreview? searchPreview;
  final _BudgetSuggestionPreview? budgetSuggestionPreview;
  final List<_TxPreview>? multiRecords;

  /// Emoji chat (cùng emotion LLM, khác tên với avatar story).
  String? chatEmotion;
  bool isSaved;
  bool isConfirmed = false;
  bool isRejected = false;
  bool isBudgetApplied = false;
  bool isBudgetDismissed = false;

  _ChatMsg({
    required this.text,
    required this.isUser,
    required this.time,
    this.backendMessageId,
    this.llmPending = false,
    this.txPreview,
    this.actionPreview,
    this.reportPreview,
    this.searchPreview,
    this.budgetSuggestionPreview,
    this.multiRecords,
    this.chatEmotion,
    this.isSaved = false,
  });
}

// ─── Widgets ─────────────────────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final String verbalStyle;
  final String personalityLabel;
  final String? walletId;
  const _ChatHeader({
    required this.verbalStyle,
    required this.personalityLabel,
    this.walletId,
  });

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
      child: Row(
        children: [
          IconButton(
            onPressed: () => ctx.pop(),
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: Image.asset(
                mascotAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, e, s) => Center(child: Text(fallbackEmoji)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chat với Mimo',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Phong cách $personalityLabel · ghi nhận chi tiêu',
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () =>
                ctx.push(AppRoutes.chatHistory, extra: {'walletId': walletId}),
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.access_time,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Emoji phản hồi LLM trong bubble chat (không phải avatar story).
class _ChatEmotionSticker extends StatelessWidget {
  final String emotionAsset;
  final double size;
  const _ChatEmotionSticker({required this.emotionAsset, this.size = 80.0});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        'assets/MiMo/emotions/$emotionAsset.png',
        width: size,
        height: size,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/MiMo/emotions/Thinking.png',
                width: 22,
                height: 22,
                errorBuilder: (_, _, _) =>
                    const Text('🤔', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Text(
                'Mimo đang nghĩ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 4),
              const _DotsAnimation(),
            ],
          ),
        ),
      ],
    );
  }
}

class _DotsAnimation extends StatefulWidget {
  const _DotsAnimation();

  @override
  State<_DotsAnimation> createState() => _DotsAnimationState();
}

class _DotsAnimationState extends State<_DotsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
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
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = ((phase * 3 - i) % 3).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Opacity(
                opacity: 0.3 + 0.7 * (1 - offset),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: AppColors.muted,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
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

  _ActionPreview copyWith({bool? navOnly, String? aiLine}) => _ActionPreview(
    actionType: actionType,
    signature: signature,
    originalText: originalText,
    summary: summary,
    aiLine: aiLine ?? this.aiLine,
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
  const _SearchResultItem({
    required this.amount,
    required this.note,
    required this.categoryCode,
  });
}

class _SearchResultPreview {
  final List<_SearchResultItem> items;
  const _SearchResultPreview({required this.items});
}

class _BudgetSuggestionItem {
  final String categoryCode;
  final int suggestedAmount;
  final int baseSpending;
  final String reason;
  const _BudgetSuggestionItem({
    required this.categoryCode,
    required this.suggestedAmount,
    required this.baseSpending,
    required this.reason,
  });
}

class _BudgetSuggestionPreview {
  final String targetMonth;
  final List<_BudgetSuggestionItem> items;
  final int totalSuggested;
  const _BudgetSuggestionPreview({
    required this.targetMonth,
    required this.items,
    required this.totalSuggested,
  });
}

class _ReportStoryCard extends StatelessWidget {
  final _ReportStoryPreview preview;
  const _ReportStoryCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    final topCats = preview.categories.take(5).toList();
    final maxCat = topCats.isEmpty
        ? 1
        : topCats.map((c) => c.total).reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        gradient: LinearGradient(
          colors: [
            AppColors.teal.withValues(alpha: 0.08),
            context.palette.card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
        boxShadow: context.palette.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: AppColors.teal.withValues(alpha: 0.12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bar_chart_rounded,
                    color: AppColors.teal,
                    size: 16,
                  ),
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
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.reportKind != null &&
                          preview.reportKind!.toUpperCase().contains('INCOME')
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
                  preview.reportKind != null &&
                          preview.reportKind!.toUpperCase().contains('INCOME')
                      ? 'Tổng thu nhập'
                      : 'Tổng chi tiêu',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
                if (preview.reportKind != null &&
                    preview.reportKind!.toUpperCase().contains('SAVING')) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Thu ${formatVnd(preview.totalIncome)} · Chi ${formatVnd(preview.totalExpense)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.teal),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${preview.transactionCount} khoản chi trong kỳ',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
                if (topCats.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Theo danh mục',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...topCats.map((c) {
                    final style = CategoryTheme.of(c.categoryCode);
                    final barW = maxCat > 0
                        ? (c.total / maxCat).clamp(0.05, 1.0)
                        : 0.05;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text(
                              style.emoji,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        style.label,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${c.percent}%',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
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
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatVnd(c.total),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.go(AppRoutes.report),
                    icon: const Icon(Icons.arrow_forward_ios, size: 12),
                    label: const Text(
                      'Xem chi tiết',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.teal,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetSuggestionCard extends StatelessWidget {
  final _BudgetSuggestionPreview preview;
  final bool isApplied;
  final bool isDismissed;
  final VoidCallback? onApply;
  final VoidCallback? onDismiss;

  const _BudgetSuggestionCard({
    required this.preview,
    this.isApplied = false,
    this.isDismissed = false,
    this.onApply,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.teal;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Hạn mức ${_formatTargetMonthLabel(preview.targetMonth)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tổng gợi ý: ${formatVnd(preview.totalSuggested)}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ...preview.items.take(5).map((item) {
            final style = CategoryTheme.of(item.categoryCode);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(style.emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style.label,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.reason.isNotEmpty)
                          Text(
                            item.reason,
                            style: TextStyle(
                              fontSize: 10,
                              color: context.palette.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    formatVnd(item.suggestedAmount),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),
          if (isApplied)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: accent, size: 16),
                SizedBox(width: 6),
                Text(
                  'Đã áp dụng hạn mức',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else if (isDismissed)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel, color: Colors.grey, size: 16),
                SizedBox(width: 6),
                Text(
                  'Đã bỏ qua gợi ý',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: accent.withValues(alpha: 0.5)),
                    ),
                    child: const Text(
                      'Bỏ qua',
                      style: TextStyle(fontSize: 12, color: accent),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: onApply,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Áp dụng ngay',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  preview.summary,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          if (preview.amount != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _ActionChip(label: formatVnd(preview.amount!), accent: accent),
              ],
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
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else if (isRejected)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel, color: Colors.grey, size: 16),
                SizedBox(width: 6),
                Text(
                  'Đã bỏ qua',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      side: BorderSide(color: accent.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      preview.navOnly ? 'Để sau' : 'Bỏ qua',
                      style: TextStyle(fontSize: 12, color: accent),
                    ),
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
                    child: Text(
                      preview.navOnly ? 'Mở' : 'Xác nhận',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 4)],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accent ?? AppColors.teal,
            ),
          ),
        ],
      ),
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
            child: Row(
              children: [
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
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
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
  final Future<void> Function(_ChatMsg)? onApplyBudgetSuggestion;
  final Future<void> Function(_ChatMsg)? onDismissBudgetSuggestion;
  final void Function(_ChatMsg)? onEditTxCategory;
  final void Function(_ChatMsg, _TxPreview)? onEditTxPreview;

  const _ChatBubble({
    required this.message,
    this.onSaveTx,
    this.onSaveMultiTx,
    this.onConfirmAction,
    this.onRejectAction,
    this.onApplyBudgetSuggestion,
    this.onDismissBudgetSuggestion,
    this.onEditTxCategory,
    this.onEditTxPreview,
  });

  Widget _buildSingleTxCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFB),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: AppColors.teal, size: 16),
              const SizedBox(width: 6),
              Text(
                message.txPreview!.category,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '${message.txPreview!.recordType == 'Income' ? '+' : '-'}${formatVnd(message.txPreview!.amount)}',
                style: TextStyle(
                  color: message.txPreview!.recordType == 'Income'
                      ? const Color(0xFF22C55E)
                      : AppColors.danger,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          if (message.txPreview!.note.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              message.txPreview!.note,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onEditTxCategory?.call(message),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: AppColors.teal),
                  ),
                  child: const Text(
                    '✏️ Chỉnh sửa',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: message.isSaved
                    ? OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(
                            color: AppColors.muted.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          '✓ Đã lưu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      )
                    : FilledButton(
                        onPressed: () => onSaveTx?.call(message),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('💾 Lưu'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMultiTxCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFB),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.playlist_add_check_rounded,
                color: AppColors.teal,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '${message.multiRecords!.length} giao dịch được nhận dạng',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
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
              child: Row(
                children: [
                  Text(style.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        if (record.note.isNotEmpty)
                          Text(
                            record.note,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${record.recordType == 'Income' ? '+' : '-'}${formatVnd(record.amount)}',
                    style: TextStyle(
                      color: record.recordType == 'Income'
                          ? const Color(0xFF22C55E)
                          : AppColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => onEditTxPreview?.call(message, record),
                    child: const Icon(
                      Icons.edit_outlined,
                      size: 16,
                      color: AppColors.teal,
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: message.isSaved
                    ? OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(
                            color: AppColors.muted.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          '✓ Đã lưu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.muted,
                          ),
                        ),
                      )
                    : FilledButton(
                        onPressed: () => onSaveMultiTx?.call(message),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: const Text('💾 Lưu'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = message.isUser ? AppColors.teal : context.palette.card;
    final textColor = message.isUser
        ? Colors.white
        : context.palette.textPrimary;
    final alignment = message.isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    final hasTextOrEmotion =
        message.text.isNotEmpty ||
        (!message.isUser && message.chatEmotion != null);
    final hasSpecialCard =
        !message.isUser &&
        (message.reportPreview != null ||
            (message.actionPreview != null &&
                _actionNeedsConfirm(message.actionPreview!.actionType)) ||
            message.searchPreview != null ||
            message.budgetSuggestionPreview != null ||
            message.txPreview != null ||
            (message.multiRecords != null && message.multiRecords!.isNotEmpty));

    return Column(
      crossAxisAlignment: alignment,
      children: [
        // 1. Text & Emotion Sticker bubble
        if (hasTextOrEmotion)
          Container(
            margin: EdgeInsets.only(
              bottom: hasSpecialCard ? AppSpacing.sm : AppSpacing.md,
              left: message.isUser ? 60 : 0,
              right: message.isUser ? 0 : 60,
            ),
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
                if (message.text.isNotEmpty)
                  Text(
                    message.text,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: textColor),
                  ),
                if (!message.isUser && message.llmPending) ...[
                  if (message.text.isNotEmpty) const SizedBox(height: 6),
                  Text(
                    'Mimo đang soạn thêm…',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textColor.withValues(alpha: 0.65),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (!message.isUser && message.chatEmotion != null) ...[
                  if (message.text.isNotEmpty) const SizedBox(height: 8),
                  _ChatEmotionSticker(emotionAsset: message.chatEmotion!),
                ],
                if (!hasSpecialCard) ...[
                  const SizedBox(height: 6),
                  Text(
                    message.time,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),

        // 2. Special Component Card bubble
        if (hasSpecialCard)
          Container(
            margin: const EdgeInsets.only(
              bottom: AppSpacing.md,
              left: 0,
              right: 60,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.reportPreview != null)
                  _ReportStoryCard(preview: message.reportPreview!),
                if (message.actionPreview != null &&
                    _actionNeedsConfirm(message.actionPreview!.actionType))
                  _ActionConfirmCard(
                    preview: message.actionPreview!,
                    isConfirmed: message.isConfirmed,
                    isRejected: message.isRejected,
                    onConfirm: () => onConfirmAction?.call(message),
                    onReject: () => onRejectAction?.call(message),
                  ),
                if (message.budgetSuggestionPreview != null)
                  _BudgetSuggestionCard(
                    preview: message.budgetSuggestionPreview!,
                    isApplied: message.isBudgetApplied,
                    isDismissed: message.isBudgetDismissed,
                    onApply: () => onApplyBudgetSuggestion?.call(message),
                    onDismiss: () => onDismissBudgetSuggestion?.call(message),
                  ),
                if (message.searchPreview != null)
                  _SearchResultCard(preview: message.searchPreview!),
                if (message.txPreview != null) _buildSingleTxCard(context),
                if (message.multiRecords != null &&
                    message.multiRecords!.isNotEmpty)
                  _buildMultiTxCard(context),
                const SizedBox(height: 6),
                Text(
                  message.time,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.palette.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
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
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Nhắn tin cho Mimo...',
                filled: true,
                fillColor: context.palette.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
              onPressed: onSend,
              icon: const Icon(Icons.send, color: AppColors.teal, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
