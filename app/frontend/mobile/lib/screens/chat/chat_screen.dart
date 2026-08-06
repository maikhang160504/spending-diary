import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/chat_llm_notifier.dart';
import '../../services/streak_celebration.dart';
import '../../services/transaction_notifier.dart';
import '../../services/ads_service.dart';
import '../../widgets/interstitial_ad_dialog.dart';
import '../../widgets/premium_upsell_bottom_sheet.dart';
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
import '../../widgets/mimo_snackbar.dart';

String _actionSignatureFromNlu(Map<String, dynamic> nlu, {String? messageId}) {
  final fromApi = nluString(nlu['action_signature']);
  if (fromApi != null && fromApi.isNotEmpty) return fromApi;
  final actionType = (nluString(nlu['action_type']) ?? 'UNKNOWN').toUpperCase();
  final tr = nluMap(nlu['time_range']);
  if (tr != null) {
    return '$actionType|${nluString(tr['granularity']) ?? 'default'}';
  }
  final details = nluMap(nlu['action_details']);
  final amount = nlu['amount'] ?? nlu['action_param'] ?? details?['value'];
  final cat = _categoryFromNlu(nlu);
  final suffix = messageId != null ? '|$messageId' : '';
  if (actionType.contains('LIMIT')) {
    return '$actionType|${cat ?? 'all'}|$amount$suffix';
  }
  if (actionType.contains('DELETE')) return '$actionType|last$suffix';
  if (actionType.contains('GOAL')) return '$actionType|$amount$suffix';
  return '$actionType|default$suffix';
}

String? _categoryFromNlu(Map<String, dynamic> nlu) {
  final details = nluMap(nlu['action_details']);
  final target = nluString(details?['target']) ?? nluString(nlu['category']);
  if (target == null) return null;
  final canonical = CategoryTheme.canonicalCodeOf(target);
  if (CategoryTheme.styles.containsKey(canonical)) return canonical;
  final norm = target
      .toLowerCase()
      .replaceAll('Äƒ', 'a')
      .replaceAll('Ã¢', 'a')
      .replaceAll('Ä‘', 'd')
      .replaceAll('Ãª', 'e')
      .replaceAll('Ã´', 'o')
      .replaceAll('Æ¡', 'o')
      .replaceAll('Æ°', 'u');
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

String _actionSummary(
  String actionType, {
  int? amount,
  String? categoryCode,
  String? verb,
  String? verbalStyle,
  String? theme,
  String? toolType,
}) {
  final t = actionType.toUpperCase();
  final v = (verb ?? '').toUpperCase();
  final amt = amount != null ? formatVnd(amount) : null;
  final catLabel = categoryCode != null
      ? CategoryTheme.of(categoryCode).label
      : null;
  String verbLabel(String base) {
    if (v == 'ADD') return 'TÄƒng $base';
    if (v == 'SUB') return 'Giáº£m $base';
    if (v == 'SET') return 'Äáº·t $base';
    return base;
  }

  if (t.contains('LIMIT') || t == 'SET_LIMIT') {
    return '${verbLabel('háº¡n má»©c')}${catLabel != null ? ' $catLabel' : ''}${amt != null ? ': $amt' : ''}';
  }
  if (t.contains('DELETE')) return 'XÃ³a giao dá»‹ch gáº§n nháº¥t';
  if (t.contains('GOAL') ||
      t == 'SET_GOAL' ||
      t == 'ADD_GOAL' ||
      t.contains('LOAN')) {
    if (toolType == 'challenge') {
      return 'Táº¡o thá»­ thÃ¡ch tiáº¿t kiá»‡m${amt != null ? ' $amt' : ''}';
    }
    if (toolType == 'saving_group') {
      return 'Táº¡o nhÃ³m tiáº¿t kiá»‡m${amt != null ? ' $amt' : ''}';
    }
    if (toolType == 'loan' || t.contains('LOAN')) {
      return 'Táº¡o nháº¯c háº¹n vay mÆ°á»£n${amt != null ? ' $amt' : ''}';
    }
    return '${verbLabel('má»¥c tiÃªu')}${amt != null ? ' $amt' : ''}';
  }
  if (t.contains('TONE') || t == 'SET_VERBAL_STYLE') {
    final styleLabel = verbalStyle == 'dan_doi'
        ? 'Dáº­n Dá»—i'
        : (verbalStyle == 'dui_de'
              ? 'Dui Dáº»'
              : (verbalStyle == 'kho_tinh'
                    ? 'KhÃ³ TÃ­nh'
                    : (verbalStyle == 'ngot_ngao' ? 'Ngá»t NgÃ o' : '')));
    return 'Äá»•i giá»ng nÃ³i Mimo${styleLabel.isNotEmpty ? ' thÃ nh $styleLabel' : ''}';
  }
  if (t.contains('SEARCH')) return 'TÃ¬m kiáº¿m giao dá»‹ch';
  if (t.contains('SETTING') || t.contains('SYSTEM_SETTING')) {
    if (theme == 'dark') return 'Äá»•i sang giao diá»‡n tá»‘i';
    if (theme == 'light') return 'Äá»•i sang giao diá»‡n sÃ¡ng';
    return 'Má»Ÿ cÃ i Ä‘áº·t á»©ng dá»¥ng';
  }
  if (t.contains('SUGGEST')) return 'Gá»£i Ã½ háº¡n má»©c thÃ´ng minh';
  if (t == 'SET_USERNAME') return 'Äá»•i tÃªn Mimo gá»i báº¡n';
  if (t == 'SET_INCOME') {
    return 'CÃ i thu nháº­p hÃ ng thÃ¡ng${amt != null ? ': $amt' : ''}';
  }
  if (t == 'UPDATE_RECORD' || t == 'EDIT') {
    return 'Sá»­a giao dá»‹ch gáº§n nháº¥t${catLabel != null ? ' ($catLabel)' : ''}${amt != null ? ': $amt' : ''}';
  }
  if (t == 'SET_ALERT') {
    return 'CÃ i cáº£nh bÃ¡o chi tiÃªu${catLabel != null ? ' $catLabel' : ''}';
  }
  if (t == 'EXPORT_DATA') return 'Xuáº¥t dá»¯ liá»‡u chi tiÃªu';
  return '$actionType${v.isNotEmpty ? ' ($v)' : ''}';
}

_ActionPreview _actionPreviewFromNlu(
  Map<String, dynamic> nlu,
  String userText, {
  String? aiLine,
  String? messageId,
}) {
  final actionType = nlu['action_type'] as String? ?? 'Unknown';
  final amount = _amountFromNlu(nlu);
  final t = actionType.toUpperCase();
  final needsCategory =
      t.contains('LIMIT') ||
      t.contains('SEARCH') ||
      t == 'UPDATE_RECORD' ||
      t == 'EDIT' ||
      t.contains('REPORT') ||
      t == 'SET_ALERT';
  final categoryCode = needsCategory ? _categoryFromNlu(nlu) : null;
  final details = nluMap(nlu['action_details']);
  final verb = nluString(details?['verb']);
  final verbalStyle =
      nluString(details?['verbal_style']) ??
      nluString(details?['verbalStyle']) ??
      nluString(nlu['verbal_style']) ??
      nluString(nlu['verbalStyle']);
  final theme = nluString(details?['theme']) ?? nluString(nlu['theme']);
  final toolType =
      nluString(details?['tool_type']) ??
      nluString(details?['toolType']) ??
      nluString(nlu['tool_type']) ??
      nluString(nlu['toolType']);
  return _ActionPreview(
    actionType: actionType,
    signature: _actionSignatureFromNlu(nlu, messageId: messageId),
    originalText: userText,
    amount: amount,
    categoryCode: categoryCode,
    summary: _actionSummary(
      actionType,
      amount: amount,
      categoryCode: categoryCode,
      verb: verb,
      verbalStyle: verbalStyle,
      theme: theme,
      toolType: toolType,
    ),
    actionDetails: nlu['action_details'] as Map<String, dynamic>?,
    aiLine: aiLine,
  );
}

Map<String, dynamic> _executeBodyFromPreview(
  _ActionPreview preview,
  String? walletId,
) {
  final details = preview.actionDetails;
  final goalName =
      nluString(details?['goal_name']) ?? nluString(details?['goalName']);
  final toolType =
      nluString(details?['tool_type']) ?? nluString(details?['toolType']);
  final loanType =
      nluString(details?['loan_type']) ?? nluString(details?['loanType']);
  final contactName =
      nluString(details?['contact_name']) ?? nluString(details?['contactName']);
  final dueDate =
      nluString(details?['due_date']) ?? nluString(details?['dueDate']);
  final timeLabel =
      nluString(details?['time']) ?? nluString(details?['time_range']);
  final query = nluString(details?['query']);
  final verbalStyle =
      nluString(details?['verbal_style']) ?? nluString(details?['verbalStyle']);
  return {
    'actionType': preview.actionType,
    if (preview.amount != null) 'amount': preview.amount,
    if (preview.categoryCode != null) 'categoryCode': preview.categoryCode,
    if (goalName != null && goalName.isNotEmpty) 'goalName': goalName,
    if (toolType != null && toolType.isNotEmpty) 'toolType': toolType,
    if (loanType != null && loanType.isNotEmpty) 'loanType': loanType,
    if (contactName != null && contactName.isNotEmpty)
      'contactName': contactName,
    if (dueDate != null && dueDate.isNotEmpty) 'dueDate': dueDate,
    if (query != null && query.isNotEmpty) 'query': query,
    if (verbalStyle != null && verbalStyle.isNotEmpty)
      'verbalStyle': verbalStyle,
    if (walletId != null) 'walletId': walletId,
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
    final dateStr = nluString(m['occurredAt']) ?? nluString(m['occurred_at']);
    return _SearchResultItem(
      id: nluString(m['id']) ?? nluString(m['transactionId']),
      amount: nluInt(m['amount']) ?? 0,
      note: nluString(m['note']) ?? '',
      categoryCode:
          nluString(m['categoryCode']) ??
          nluString(m['category_code']) ??
          'Others',
      recordType:
          nluString(m['type']) ?? nluString(m['recordType']) ?? 'Expense',
      occurredAt: dateStr != null ? DateTime.tryParse(dateStr) : null,
    );
  }).toList();
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
    totalSuggested:
        nluInt(result['totalSuggested']) ??
        items.fold<int>(0, (s, i) => s + i.suggestedAmount),
  );
}

_ReportStoryPreview? _reportPreviewFromResult(Map<String, dynamic> result) {
  if (result['report_kind'] == null && result['by_category'] == null) {
    return null;
  }
  final cats = (result['by_category'] as List<dynamic>? ?? []).map((c) {
    final m = nluMap(c) ?? {};
    return _ReportCategoryRow(
      categoryCode: nluString(m['categoryCode']) ?? 'Others',
      total: nluInt(m['total']) ?? 0,
      percent: nluInt(m['percent']) ?? 0,
    );
  }).toList();
  final kind = nluString(result['report_kind']) ?? 'expense';
  final comparePercent = nluInt(result['compare_percent']) ?? 0;
  final compareCategoriesRaw = result['compareCategories'] as List<dynamic>?;
  final compareCategories = compareCategoriesRaw
      ?.map((e) => e.toString())
      .toList();
  final byDay = result['by_day'] as List<dynamic>?;
  final prevByDay = result['prev_by_day'] as List<dynamic>?;

  return _ReportStoryPreview(
    periodLabel: nluString(result['period_label']) ?? 'BÃ¡o cÃ¡o',
    totalExpense: nluInt(result['total_expense']) ?? 0,
    totalIncome: nluInt(result['total_income']) ?? 0,
    reportKind: kind,
    transactionCount: nluInt(result['transaction_count']) ?? 0,
    categories: cats,
    comparePercent: comparePercent,
    compareCategories: compareCategories,
    byDay: byDay,
    prevByDay: prevByDay,
  );
}

String _formatTargetMonthLabel(String targetMonth) {
  final parts = targetMonth.split('-');
  if (parts.length != 2) return targetMonth;
  final month = int.tryParse(parts[1]);
  if (month == null) return targetMonth;
  return 'thÃ¡ng $month/${parts[0]}';
}

bool _actionNeedsConfirm(String actionType) {
  final t = actionType.toUpperCase();
  if (t.contains('REPORT')) return false;
  if (t.contains('SUGGEST')) return false;
  if (t.contains('SEARCH')) return false;
  if (t == 'EXPORT_DATA') return false;
  return t.contains('LIMIT') ||
      t.contains('GOAL') ||
      t.contains('SETTING') ||
      t == 'SET_USERNAME' ||
      t == 'SET_ALERT';
}

_SearchResultPreview? _searchPreviewFromNlu(Map<String, dynamic> nlu) {
  final ar = nluMap(nlu['action_result']);
  if (ar == null) return null;
  return _searchPreviewFromResult(ar);
}

_ReportStoryPreview? _reportPreviewFromNlu(Map<String, dynamic> nlu) {
  final ar = nluMap(nlu['action_result']);
  if (ar == null) return null;
  // Only treat as report if it has report_kind or by_category data
  if (ar['report_kind'] == null && ar['by_category'] == null) return null;
  final cats = (ar['by_category'] as List<dynamic>? ?? []).map((c) {
    final m = nluMap(c) ?? {};
    return _ReportCategoryRow(
      categoryCode: nluString(m['categoryCode']) ?? 'Others',
      total: nluInt(m['total']) ?? 0,
      percent: nluInt(m['percent']) ?? 0,
    );
  }).toList();
  final kind = nluString(ar['report_kind']) ?? nluString(nlu['action_type']);
  final comparePercent = nluInt(ar['compare_percent']) ?? 0;
  final compareCategoriesRaw = ar['compareCategories'] as List<dynamic>?;
  final compareCategories = compareCategoriesRaw
      ?.map((e) => e.toString())
      .toList();
  final byDay = ar['by_day'] as List<dynamic>?;
  final prevByDay = ar['prev_by_day'] as List<dynamic>?;

  return _ReportStoryPreview(
    periodLabel:
        nluString(ar['period_label']) ??
        nluString(nluMap(nlu['time_range'])?['period_label']) ??
        'BÃ¡o cÃ¡o',
    totalExpense: nluInt(ar['total_expense']) ?? 0,
    totalIncome: nluInt(ar['total_income']) ?? 0,
    reportKind: kind,
    transactionCount: nluInt(ar['transaction_count']) ?? 0,
    categories: cats,
    comparePercent: comparePercent,
    compareCategories: compareCategories,
    byDay: byDay,
    prevByDay: prevByDay,
  );
}

class ChatScreen extends StatefulWidget {
  final String? sessionId;
  final String? walletId;
  final bool forceNew;
  final String? initialMessage;
  static bool isActive = false;

  const ChatScreen({
    super.key,
    this.sessionId,
    this.walletId,
    this.forceNew = false,
    this.initialMessage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _api = ApiClient();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _messages = [];
  final Set<String> _executedActionMessageIds = {};

  bool _aiThinking = false;
  bool _loadingOlder = false;
  bool _hasMoreHistory = false;
  bool _showConfetti = false;
  String? _llmPendingMessageId;

  /// TrÃ¡nh gá»i load-more khi ListView reverse vá»«a layout (chÆ°a á»•n scroll).
  bool _readyForOlderLoad = false;
  String _verbalStyle = 'funny';
  String? _sessionId;
  String? _walletId;
  String? _oldestMessageId;

  static const List<String> _candidateSuggestions = [
    'Thá»‘ng kÃª chi tiÃªu tuáº§n nÃ y',
    'Tá»•ng chi tiÃªu thÃ¡ng nÃ y',
    'ThÃ¡ng trÆ°á»›c chi háº¿t bao nhiÃªu?',
    'HÃ´m nay tiÃªu gÃ¬ rá»“i?',
    'Ä‚n sÃ¡ng 35k',
    'Mua trÃ  sá»¯a 45k',
    'Äá»• xÄƒng 50k',
    'Äáº·t háº¡n má»©c Ä‚n uá»‘ng 3 triá»‡u',
    'TÃ¬m cÃ¡c giao dá»‹ch Äƒn uá»‘ng',
    'Äáº·t má»¥c tiÃªu tiáº¿t kiá»‡m 10 triá»‡u',
    'Äá»•i giá»ng nÃ³i cá»§a Mimo sang dui dáº»',
    'Chuyá»ƒn sang giao diá»‡n tá»‘i',
    'Gá»£i Ã½ háº¡n má»©c thÃ¡ng má»›i',
    'Xem bÃ¡o cÃ¡o chi tiÃªu hÃ´m qua',
    'So sÃ¡nh chi tiÃªu tuáº§n nÃ y vá»›i tuáº§n trÆ°á»›c',
    'Gá»£i Ã½ chi tiÃªu thÃ¡ng sau',
    'ÄÃ£ nháº­n lÆ°Æ¡ng thÃ¡ng nÃ y 12 triá»‡u',
    'TÄƒng háº¡n má»©c Ä‘i láº¡i lÃªn 2 triá»‡u',
    'Máº¹ cho 500k Äƒn sÃ¡ng',
    'Báº­t cáº£nh bÃ¡o vÆ°á»£t háº¡n má»©c mua sáº¯m',
    'Giáº£m giá»›i háº¡n giáº£i trÃ­ Ä‘i 100k',
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
    ChatScreen.isActive = true;
    WidgetsBinding.instance.addObserver(this);
    _generateRandomSuggestions();
    _scrollCtrl.addListener(_onScrollLoadOlder);
    chatLlmUpdateNotifier.addListener(_onChatLlmUpdateNotifier);
    _initSession().then((_) {
      if (mounted &&
          widget.initialMessage != null &&
          widget.initialMessage!.isNotEmpty) {
        _sendMessage(widget.initialMessage!);
      }
    });
    _loadAiPersonality();
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialMessage != null &&
        widget.initialMessage != oldWidget.initialMessage &&
        widget.initialMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialMessage!);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_sessionId != null) {
        _loadMessagesPage();
      }
    }
  }

  void _onChatLlmUpdateNotifier() {
    final update = chatLlmUpdateNotifier.value;
    if (update == null || !mounted) return;
    if (update.sessionId != _sessionId) return;
    setState(() {
      if (_llmPendingMessageId == update.messageId) {
        _llmPendingMessageId = null;
      }

      if (update.content != null && update.content!.isNotEmpty) {
        bool found = false;
        for (final msg in _messages) {
          if (msg.backendMessageId == update.messageId) {
            if (update.intentAction != null &&
                update.intentAction!['action_executed'] == true) {
              final actionResult = update.intentAction!['action_result'];
              final resultText = actionResult != null
                  ? actionResult['message']
                  : null;
              if (update.isRag) {
                // For RAG flow, we want 3 bubbles:
                // 1. Original msg text (already set by chat_llm_update)
                // 2. The Card (added by _updateMessagePreviews below)
                // 3. A NEW message for the RAG narrative
              } else {
                if (resultText != null &&
                    resultText.toString().isNotEmpty &&
                    update.content! != resultText) {
                  msg.text = '$resultText\n\n${update.content!}';
                } else {
                  msg.text = update.content!;
                }
              }
            } else {
              if (!update.isRag) {
                msg.text = update.content!;
              }
            }
            if (update.mood != null && update.mood!.isNotEmpty) {
              msg.chatEmotion = update.mood!;
            }
            if (update.intentAction != null) {
              _updateMessagePreviews(msg, update.intentAction!);
            }
            found = true;

            if (update.isRag &&
                update.content != null &&
                update.content!.isNotEmpty) {
              final ragMsg = _ChatMsg(
                text: update.content!,
                isUser: false,
                time: _now(),
                chatEmotion: update.mood ?? 'Happy',
                backendMessageId: '${update.messageId}_rag',
              );
              _messages.insert(0, ragMsg);
            }

            break;
          }
        }
        if (!found) {
          final confirmMsg = _ChatMsg(
            text: update.content!,
            isUser: false,
            time: _now(),
            chatEmotion: (update.mood != null && update.mood!.isNotEmpty)
                ? update.mood
                : 'Happy',
            backendMessageId: update.messageId,
          );
          if (update.intentAction != null) {
            _updateMessagePreviews(confirmMsg, update.intentAction!);
          }
          _messages.insert(0, confirmMsg);

          if (update.isRag &&
              update.content != null &&
              update.content!.isNotEmpty) {
            final ragMsg = _ChatMsg(
              text: update.content!,
              isUser: false,
              time: _now(),
              chatEmotion: update.mood ?? 'Happy',
              backendMessageId: '${update.messageId}_rag',
            );
            _messages.insert(0, ragMsg);
          }
        }
      }

      for (final msg in _messages) {
        if (msg.backendMessageId == update.messageId) {
          msg.llmPending = false;
          if (update.intentAction != null) {
            _updateMessagePreviews(msg, update.intentAction!);
            if (msg.actionPreview != null &&
                !_actionNeedsConfirm(msg.actionPreview!.actionType) &&
                !msg.isConfirmed) {
              msg.isConfirmed = true;
              if (update.messageId != null &&
                  !_executedActionMessageIds.contains(update.messageId!)) {
                _executedActionMessageIds.add(update.messageId!);
                _runConfirmedAction(msg);
              }
            }
          }
        }
      }
    });
    _scrollToBottom();
  }

  void _updateMessagePreviews(_ChatMsg msg, Map<String, dynamic> metadata) {
    final nlu = nluMap(metadata['nlu']);
    if (nlu == null) return;
    final intent = nluString(metadata['intent']);

    List<_TxPreview>? multiRecords;
    final rawMulti = metadata['multi_records'] ?? metadata['multiRecords'];
    if (rawMulti is List) {
      multiRecords = rawMulti.map((r) {
        final rMap = nluMap(r) ?? {};
        return _TxPreview(
          category: nluString(rMap['category']) ?? 'Other',
          amount: nluInt(rMap['amount']) ?? 0,
          note: nluString(rMap['text']) ?? '',
          recordType: nluString(rMap['record_type']) ?? 'Expense',
          transactionId: nluString(
            rMap['transaction_id'] ?? rMap['transactionId'],
          ),
        );
      }).toList();
    }

    if (intent == 'Record' && multiRecords == null) {
      final amount = metadata['amount'] ?? nlu['amount_spent'] ?? nlu['amount'];
      final amountInt = nluInt(amount) ?? 0;
      msg.txPreview = _TxPreview(
        category: nluString(metadata['category']) ?? 'Other',
        amount: amountInt,
        note: nluString(nlu['clean_content']) ?? '',
        recordType: nluString(nlu['record_type']) ?? 'Expense',
        emotionAsset: msg.chatEmotion ?? 'Happy',
        aiComment: msg.text,
        nlu: nlu,
        transactionId: nluString(
          metadata['transaction_id'] ?? metadata['transactionId'],
        ),
      );
    } else if (intent == 'Action') {
      final actionResult = nluMap(metadata['action_result']);
      final isExecuted =
          metadata['action_executed'] == true || actionResult != null;
      if (actionResult != null) {
        msg.searchPreview = _searchPreviewFromResult(actionResult);
        msg.reportPreview = _reportPreviewFromResult(actionResult);
        msg.budgetSuggestionPreview = _budgetSuggestionFromResult(actionResult);
      }
      final report = _reportPreviewFromNlu(nlu);
      if (report != null && msg.reportPreview == null) {
        msg.reportPreview = report;
      } else {
        final originalUser =
            nluString(nlu['text']) ?? nluString(nlu['clean_content']) ?? '';
        final preview = _actionPreviewFromNlu(
          nlu,
          originalUser,
          aiLine: msg.text,
          messageId: msg.backendMessageId,
        );
        if (preview != null) {
          msg.actionPreview = preview;
          if (isExecuted) {
            msg.isConfirmed = true;
          }
        }
      }
    }

    if (multiRecords != null) {
      msg.multiRecords = multiRecords;
    }

    final savedFlag = (metadata['saved'] == true);
    msg.isSaved =
        (msg.txPreview != null || msg.multiRecords != null) && savedFlag;
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
    ChatScreen.isActive = false;
    WidgetsBinding.instance.removeObserver(this);
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
    // reverse: true â€” cuá»™n lÃªn (tin cÅ©) â†’ pixels gáº§n maxScrollExtent
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
      bool isPremiumLocked = false;
      bool isBudgetApplied = false;
      bool isBudgetDismissed = false;

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

        final llmMeta = llmReplyFromChatMetadata(
          metadata,
          fallbackText: displayText,
        );
        chatEmotion = llmMeta?.emotionAsset;

        final actionResult = nluMap(metadata['action_result']);
        if (actionResult != null) {
          isPremiumLocked = actionResult['isPremiumLocked'] == true;
        }

        if (metadata['action_executed'] == true && actionResult != null) {
          budgetSuggestionPreview = _budgetSuggestionFromResult(actionResult);
          searchPreview = _searchPreviewFromResult(actionResult);
          final resultText = nluString(actionResult['message']);
          final llmText = llmMeta?.text ?? '';
          if (llmText.isNotEmpty) {
            displayText = llmText;
          } else if (resultText != null && resultText.isNotEmpty) {
            displayText = resultText;
          }
        }

        final budgetSuggestion = nluMap(metadata['budget_suggestion']);
        if (budgetSuggestion != null) {
          budgetSuggestionPreview = _budgetSuggestionFromResult(
            budgetSuggestion,
          );
        }

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
          } else if (intent == 'Action') {
            final report = _reportPreviewFromNlu(nlu);
            final search = _searchPreviewFromNlu(nlu);
            if (report != null) {
              reportPreview = report;
              if (llmMeta != null && llmMeta.text.isNotEmpty) {
                displayText = llmMeta.text;
              }
            } else if (search != null) {
              searchPreview = search;
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
                messageId: nluString(map['id']),
              );
              if (llmText.isNotEmpty) {
                displayText = llmText;
              }
            }
          }
        }
      }

      // Äá»c tráº¡ng thÃ¡i saved tá»« metadata thay vÃ¬ máº·c Ä‘á»‹nh true
      final nlu = metadata != null ? nluMap(metadata['nlu']) : null;
      final savedFlag = (metadata?['saved'] == true);

      List<String>? suggestedActions;
      if (nlu != null) {
        if (nlu['suggested_actions'] is List) {
          suggestedActions = (nlu['suggested_actions'] as List)
              .map((e) => e.toString())
              .toList();
        }
      }

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
        downloadUrl: metadata != null
            ? nluString(metadata['downloadUrl'])
            : null,
        suggestedActions: suggestedActions,
        isPremiumLocked: isPremiumLocked,
      );
      if (metadata != null) {
        final createdAt = DateTime.tryParse(
          nluString(map['created_at']) ?? nluString(map['createdAt']) ?? '',
        );
        final isStale =
            createdAt != null &&
            DateTime.now().difference(createdAt).inMinutes > 2;
        newMsg.llmPending =
            metadata['llmPending'] == true &&
            metadata['llmUpdated'] != true &&
            !isStale;
        if (metadata['action_executed'] == true) {
          newMsg.isConfirmed = true;
        }
      }

      // Náº¿u tin nháº¯n hiá»‡n táº¡i lÃ  tin xÃ¡c nháº­n Ä‘Ã£ lÆ°u ("saved": true)
      if (metadata != null && metadata['saved'] == true && role != 'user') {
        // TÃ¬m ngÆ°á»£c trong danh sÃ¡ch 'out' Ä‘á»ƒ Ä‘Ã¡nh dáº¥u tin nháº¯n gá»‘c lÃ  Ä‘Ã£ lÆ°u
        for (int i = out.length - 1; i >= 0; i--) {
          final prevMsg = out[i];
          if (prevMsg.txPreview != null || prevMsg.multiRecords != null) {
            if (!prevMsg.isSaved) {
              prevMsg.isSaved = true;
              // Chuyá»ƒn transactionId(s) sang parent preview
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
        // KhÃ´ng hiá»ƒn thá»‹ tin nháº¯n xÃ¡c nháº­n "Ä‘Ã£ lÆ°u" â€” chá»‰ Ä‘Ã¡nh dáº¥u parent
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
    // API: chronological cÅ©â†’má»›i; ListView reverse: index 0 = tin má»›i nháº¥t (Ä‘Ã¡y mÃ n hÃ¬nh)
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
      String walletName = 'VÃ­ cÃ¡ nhÃ¢n';
      if (_walletId != null) {
        try {
          final wallet = await _api.getWallet(_walletId!);
          walletName = wallet['name'] as String? ?? 'VÃ­';
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

    _checkOngoingGeneration();
  }

  void _checkOngoingGeneration() {
    final update = chatLlmUpdateNotifier.value;
    if (update != null && update.sessionId == _sessionId && !update.failed) {
      // If we have an active update that hasn't failed and isn't finished (no complete message saved)
      bool hasMsg = _messages.any(
        (m) => m.backendMessageId == update.messageId,
      );
      if (!hasMsg) {
        if (mounted) {
          setState(() {
            _aiThinking = true;
          });
          _scrollToBottom();
        }
      }
    }
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
                  'Mimo chÆ°a káº¿t ná»‘i Ä‘Æ°á»£c. Vui lÃ²ng kiá»ƒm tra máº¡ng vÃ  thá»­ láº¡i nhÃ©! ðŸŒ',
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
      final now = DateTime.now();
      final contextMeta = {
        'local_hour': now.hour,
        'local_day_of_month': now.day,
      };
      final chatRes = await _api.aiChat(
        _sessionId!,
        userText,
        contextMeta: contextMeta,
      );
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
        if (intentAction['llmPending'] == true) {
          confirmMsg.llmPending = true;
          _llmPendingMessageId = chatRes['messageId'] as String?;
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

        // Run non-confirm actions directly, or automatically run confirmed ones (only if NOT already executed by backend)
        final isAlreadyExecuted =
            (intentAction['action_executed'] == true) ||
            (intentAction['action_result'] != null);
        if (confirmMsg.actionPreview != null && !isAlreadyExecuted) {
          final action = confirmMsg.actionPreview!;
          if (!_actionNeedsConfirm(action.actionType) ||
              confirmMsg.isConfirmed) {
            confirmMsg.isConfirmed = true;
            if (confirmMsg.backendMessageId != null) {
              _executedActionMessageIds.add(confirmMsg.backendMessageId!);
            }
            await _runConfirmedAction(confirmMsg);
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
            text: 'Mimo gáº·p lá»—i rá»“i ðŸ˜… Thá»­ láº¡i sau nhÃ©!',
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
          'budget_status_event': {'targetMonth': targetMonth, 'status': status},
        },
      });
    } catch (_) {}
  }

  Future<void> _runConfirmedAction(_ChatMsg msg) async {
    final action = msg.actionPreview;
    if (action == null) return;
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
        _executeBodyFromPreview(
          action,
          _walletId ?? widget.walletId ?? ApiClient.lastSelectedWalletId,
        ),
      );
      await _api.aiConfirmAction(
        action.signature,
        actionType: action.actionType,
      );
      if (!mounted) return;

      final message =
          result['message'] as String? ?? 'âœ… ÄÃ£ thá»±c hiá»‡n hÃ nh Ä‘á»™ng!';
      final searchPreview = _searchPreviewFromResult(result);
      final budgetPreview = _budgetSuggestionFromResult(result);
      final reportPreview = _reportPreviewFromResult(result);
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
        msg.isConfirmed = true;
        // Chá»‰ ghi Ä‘Ã¨ text LLM náº¿u action cÃ³ card xÃ¡c nháº­n phá»©c táº¡p
        // CÃ¡c action settings Ä‘Æ¡n giáº£n (set_alert, tone, theme, set_username, budget_suggestion)
        // giá»¯ nguyÃªn text LLM gá»‘c â€” khÃ´ng táº¡o ra cáº£m giÃ¡c "bubble má»›i"
        final simpleKinds = {
          'tone',
          'set_alert',
          'theme',
          'set_username',
          'budget_suggestion',
        };
        final isSimpleAction = simpleKinds.contains(kind);
        if (!isSimpleAction) {
          msg.text = message;
        }

        final dynamic geminiJson = result['gemini_json'] ?? {};
        final String? newEmotion =
            geminiJson['mimo_emotion'] ??
            geminiJson['emotion'] ??
            result['mimo_emotion'] ??
            result['emotion'];
        if (newEmotion != null && newEmotion.isNotEmpty) {
          msg.chatEmotion = newEmotion;
        }

        if (searchPreview != null) msg.searchPreview = searchPreview;
        if (budgetPreview != null) msg.budgetSuggestionPreview = budgetPreview;
        if (reportPreview != null) msg.reportPreview = reportPreview;
      });
      _scrollToBottom();

      if (searchPreview != null ||
          budgetPreview != null ||
          reportPreview != null) {
        await _persistActionResultMessage(message, result);
      }

      final navigate = result['navigate'] as String?;
      if (navigate == 'settings') {
        if (!mounted) return;
        context.go(AppRoutes.settings);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        msg.text = 'âŒ KhÃ´ng thá»±c hiá»‡n Ä‘Æ°á»£c hÃ nh Ä‘á»™ng.';
      });
      _scrollToBottom();
    }
  }

  Future<void> _handleBudgetApply(
    _ChatMsg msg,
    Map<String, num> overrides,
  ) async {
    if (msg.isBudgetApplied || msg.budgetSuggestionPreview == null) return;
    final preview = msg.budgetSuggestionPreview!;
    setState(() => msg.isBudgetApplied = true);
    try {
      final res = await _api.applyBudgetSuggestions(
        month: preview.targetMonth,
        overrides: overrides,
      );
      if (!mounted) return;
      _scrollToBottom();
      await _persistBudgetStatusEvent(preview.targetMonth, 'applied');
    } catch (_) {
      if (!mounted) return;
      setState(() => msg.isBudgetApplied = false);
      setState(() {
        _messages.insert(
          0,
          _ChatMsg(
            text: 'âŒ KhÃ´ng Ã¡p dá»¥ng Ä‘Æ°á»£c gá»£i Ã½. Thá»­ láº¡i sau nhÃ©!',
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
      final message = await _api.dismissBudgetSuggestions(
        month: preview.targetMonth,
      );
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
      await _runConfirmedAction(msg);
    } catch (_) {
      // Keep it as confirmed in UI to avoid showing buttons again
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    if (!(MediaQuery.of(context).viewInsets.bottom > 0 &&
                        MediaQuery.of(context).size.height < 500))
                      _ChatHeader(
                        verbalStyle: _verbalStyle,
                        personalityLabel: personalityLabelFromStyle(
                          _verbalStyle,
                        ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }

                          return _ChatBubble(
                            key: ObjectKey(_messages[msgIndex]),
                            message: _messages[msgIndex],
                            onSaveTx: _saveTransaction,
                            onSaveMultiTx: _saveMultiTransactions,
                            onConfirmAction: _handleActionConfirm,
                            onRejectAction: _handleActionReject,
                            onApplyBudgetSuggestion: _handleBudgetApply,
                            onDismissBudgetSuggestion: _handleBudgetDismiss,
                            onEditTxCategory: _showEditTxSheet,
                            onEditTxPreview: _showEditTxPreviewSheet,
                            onDownloadUrl: _handleDownloadFile,
                            onSendMessage: _sendMessage,
                          );
                        },
                      ),
                    ),
                    // Quick action chips
                    if (_suggestions.isNotEmpty && !_aiThinking)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.black,
                                Colors.black,
                                Colors.transparent,
                              ],
                              stops: [0.0, 0.90, 1.0],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                for (
                                  int i = 0;
                                  i < _suggestions.length;
                                  i++
                                ) ...[
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
                      ),
                    _ChatComposer(
                      controller: _inputCtrl,
                      isSending: _aiThinking,
                      onSend: () {
                        final t = _inputCtrl.text.trim();
                        if (t.isEmpty) return;
                        _sendMessage(t);
                      },
                    ),
                  ],
                ),
              ),
              if (_showConfetti)
                Positioned.fill(
                  child: ConfettiOverlay(
                    onFinished: () {
                      setState(() {
                        _showConfetti = false;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDownloadFile(String downloadPath) async {
    try {
      final dir = await getTemporaryDirectory();
      final uri = Uri.parse(downloadPath);
      final filename = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'transactions_export.csv';
      final savePath = '${dir.path}/$filename';

      final token = await _api.accessToken;
      final fullUrl =
          '${_api.baseUrl}$downloadPath${downloadPath.contains('?') ? '&' : '?'}token=$token';

      if (!mounted) return;
      MimoSnackBar.showInfo(
        context,
        message: 'â³ Äang táº£i xuá»‘ng bÃ¡o cÃ¡o Excel/CSV...',
      );

      final dio = Dio();
      await dio.download(fullUrl, savePath);

      if (!mounted) return;
      MimoSnackBar.showSuccess(
        context,
        message: 'âœ… ÄÃ£ táº£i xuá»‘ng bÃ¡o cÃ¡o chi tiÃªu: $filename',
      );
    } catch (e) {
      debugPrint('Download file error: $e');
      if (!mounted) return;
      MimoSnackBar.showError(
        context,
        message: 'âŒ Lá»—i táº£i tá»‡p: ${e.toString()}',
      );
    }
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
        predicted: {'action_type': action.actionType, 'intent': 'Action'},
      );
      if (!mounted) return;
      setState(() {
        _messages.insert(
          0,
          _ChatMsg(
            text: 'âŒ ÄÃ£ bá» qua. Mimo sáº½ cáº£i thiá»‡n sau!',
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
      setState(() {
        _showConfetti = true;
      });
      await StreakCelebration.instance.afterActivity(context);
      if (mounted) {
        await checkCategoryLimitAndSuggest(
          context,
          preview.category,
          walletId: _walletId ?? widget.walletId,
        );
        final showAd = AdsService.instance.incrementAndCheckIfNotPremium();
        if (showAd) {
          showInterstitialAdDialog(
            context,
            onDismissed: () => showPremiumUpsellSheet(context),
          );
        }
      }
      // Cáº­p nháº­t tráº¡ng thÃ¡i saved lÃªn backend chat metadata
      if (_sessionId != null && !wasSavedBefore) {
        try {
          await _api.sendChatMessageRaw(_sessionId!, {
            'content': 'ðŸ’¾ ÄÃ£ lÆ°u giao dá»‹ch',
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
              text: 'âŒ KhÃ´ng thá»ƒ lÆ°u giao dá»‹ch',
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
    // Chuáº©n hÃ³a category code Ä‘á»ƒ trÃ¡nh crash DropdownButton khi value lÃ  alias
    String editCategory = CategoryTheme.canonicalCodeOf(preview.category);
    if (!CategoryTheme.primaryCodes.contains(editCategory)) {
      editCategory = 'Other';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
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
                  'Chá»‰nh sá»­a giao dá»‹ch',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sá»‘ tiá»n',
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Nháº­p sá»‘ tiá»n',
                    suffixText: 'Ä‘',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Danh má»¥c',
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
                  'Ghi chÃº',
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Ghi chÃº cho giao dá»‹ch',
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

                          // Ghi nháº­n correction cho NLU learning khi Ä‘á»•i category
                          // Chá»‰ gá»­i náº¿u nguá»“n lÃ  'chat' (khÃ´ng ghi bill/OCR)
                          if (oldCategory != updatedCategory &&
                              preview.source == 'chat') {
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
                    child: const Text('LÆ°u chá»‰nh sá»­a'),
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
            text: 'Ghi nháº­n giao dá»‹ch tá»± Ä‘á»™ng',
            emotionAsset: 'Success',
          ).toStoryPersistFields(),
        });
        preview.transactionId = tx['id'] as String?;
      }
      if (!mounted) return;
      notifyTransactionChanged();
      setState(() {
        _showConfetti = true;
      });
      await StreakCelebration.instance.afterActivity(context);
      if (mounted && records.isNotEmpty) {
        await checkCategoryLimitAndSuggest(
          context,
          records.first.category,
          walletId: _walletId ?? widget.walletId,
        );
        final showAd = AdsService.instance.incrementAndCheckIfNotPremium();
        if (showAd) {
          showInterstitialAdDialog(
            context,
            onDismissed: () => showPremiumUpsellSheet(context),
          );
        }
      }
      // Cáº­p nháº­t tráº¡ng thÃ¡i saved lÃªn backend chat metadata
      if (_sessionId != null && !wasSavedBefore) {
        try {
          await _api.sendChatMessageRaw(_sessionId!, {
            'content': 'ðŸ’¾ ÄÃ£ lÆ°u táº¥t cáº£ giao dá»‹ch',
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
              text: 'âŒ KhÃ´ng thá»ƒ lÆ°u giao dá»‹ch',
              isUser: false,
              time: _now(),
            ),
          );
        });
      }
    }
  }
}

// â”€â”€â”€ Models â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
  final int comparePercent;
  final List<String>? compareCategories;
  final List<dynamic>? byDay;
  final List<dynamic>? prevByDay;

  const _ReportStoryPreview({
    required this.periodLabel,
    required this.totalExpense,
    this.totalIncome = 0,
    this.reportKind,
    required this.transactionCount,
    required this.categories,
    this.comparePercent = 0,
    this.compareCategories,
    this.byDay,
    this.prevByDay,
  });
}

class _TxPreview {
  String category;
  int amount;
  String note;
  String recordType;
  String? transactionId;

  /// Nguá»“n táº¡o giao dá»‹ch: 'chat' (NLU text), 'bill' (OCR camera), 'manual' (nháº­p tay)
  final String source;

  /// CÃ¹ng LLM reply â€” khi lÆ°u story: [aiComment] + [emotionAsset] (avatar).
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
    this.source = 'chat', // máº·c Ä‘á»‹nh lÃ  chat
  });

  /// Factory dÃ¹ng cho giao dá»‹ch tá»« OCR/Camera scan (khÃ´ng gá»­i NLU correction).
  // ignore: unused_element
  factory _TxPreview.fromBill({
    required String category,
    required int amount,
    required String note,
    String recordType = 'Expense',
    String? transactionId,
  }) {
    return _TxPreview(
      category: category,
      amount: amount,
      note: note,
      recordType: recordType,
      transactionId: transactionId,
      source: 'bill',
    );
  }
}

class _ChatMsg {
  String text;
  final bool isUser;
  final String time;
  String? backendMessageId;
  bool llmPending = false;
  _TxPreview? txPreview;
  _ActionPreview? actionPreview;
  _ReportStoryPreview? reportPreview;
  _SearchResultPreview? searchPreview;
  _BudgetSuggestionPreview? budgetSuggestionPreview;
  List<_TxPreview>? multiRecords;
  final String? downloadUrl;
  List<String>? suggestedActions;

  /// Emoji chat (cÃ¹ng emotion LLM, khÃ¡c tÃªn vá»›i avatar story).
  String? chatEmotion;
  bool isSaved;
  bool isConfirmed = false;
  bool isRejected = false;
  bool isBudgetApplied = false;
  bool isBudgetDismissed = false;
  bool isPremiumLocked = false;

  _ChatMsg({
    required this.text,
    required this.isUser,
    required this.time,
    this.backendMessageId,
    this.txPreview,
    this.actionPreview,
    this.reportPreview,
    this.searchPreview,
    this.budgetSuggestionPreview,
    this.multiRecords,
    this.chatEmotion,
    this.isSaved = false,
    this.downloadUrl,
    this.suggestedActions,
    this.isPremiumLocked = false,
  });
}

// â”€â”€â”€ Widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
    final fallbackEmoji = verbalStyle == 'strict' ? 'ðŸ”¥' : 'ðŸ˜Ž';

    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.xl),
          bottomRight: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => ctx.pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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
          const SizedBox(width: 16), // Khoáº£ng cÃ¡ch 16px cÃ¡ch nÃºt Back
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chat vá»›i Mimo',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Phong cÃ¡ch $personalityLabel Â· ghi nháº­n chi tiÃªu',
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
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

/// Emoji pháº£n há»“i LLM trong bubble chat (khÃ´ng pháº£i avatar story).
class _ChatEmotionSticker extends StatelessWidget {
  final String emotionAsset;
  const _ChatEmotionSticker({required this.emotionAsset});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Image.asset(
        'assets/MiMo/emotions/$emotionAsset.png',
        width: 80.0,
        height: 80.0,
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
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.palette.textPrimary,
          ),
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
                    const Text('ðŸ¤”', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Text(
                'Mimo Ä‘ang nghÄ©',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(width: 4),
              const _TypingBubbleIndicator(),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypingBubbleIndicator extends StatefulWidget {
  final bool showBackground;
  const _TypingBubbleIndicator({this.showBackground = true});

  @override
  State<_TypingBubbleIndicator> createState() => _TypingBubbleIndicatorState();
}

class _TypingBubbleIndicatorState extends State<_TypingBubbleIndicator>
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : const Color(0xFFF1F5F9);
    final dotColor = isDark ? Colors.white54 : AppColors.muted;

    Widget content = AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final phase = _ctrl.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Bouncing math
            final delay = i * 0.2;
            final relativePhase = (phase - delay) % 1.0;
            final yOffset = relativePhase < 0.0 || relativePhase > 0.4
                ? 0.0
                : math.sin((relativePhase / 0.4) * math.pi) * -4.0;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, yOffset),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: dotColor.withValues(
                      alpha: 0.4 + (yOffset.abs() / 4.0) * 0.6,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );

    if (widget.showBackground) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: content,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: content,
    );
  }
}

// â”€â”€â”€ Action Preview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
  final String? id;
  final int amount;
  final String note;
  final String categoryCode;
  final String recordType;
  final DateTime? occurredAt;

  const _SearchResultItem({
    this.id,
    required this.amount,
    required this.note,
    required this.categoryCode,
    this.recordType = 'Expense',
    this.occurredAt,
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
  final void Function(String)? onSendMessage;
  const _ReportStoryCard({required this.preview, this.onSendMessage});

  @override
  Widget build(BuildContext context) {
    final topCats = preview.categories.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppColors.teal.withValues(alpha: 0.05),
            context.palette.card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: AppColors.teal.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: context.palette.softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppColors.teal.withValues(alpha: 0.08),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: AppColors.teal,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    preview.periodLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.teal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount & Compare Badge Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        preview.reportKind != null &&
                                preview.reportKind!.toUpperCase().contains(
                                  'INCOME',
                                )
                            ? formatVnd(preview.totalIncome)
                            : formatVnd(preview.totalExpense),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: context.palette.textPrimary,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ),
                    if (preview.comparePercent != 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color:
                              (preview.comparePercent > 0
                                      ? AppColors.danger
                                      : AppColors.success)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              preview.comparePercent > 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: preview.comparePercent > 0
                                  ? AppColors.danger
                                  : AppColors.success,
                              size: 12,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${preview.comparePercent > 0 ? '+' : ''}${preview.comparePercent}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: preview.comparePercent > 0
                                    ? AppColors.danger
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Kind text
                Text(
                  preview.reportKind != null &&
                          preview.reportKind!.toUpperCase().contains('INCOME')
                      ? 'Tá»•ng thu nháº­p'
                      : 'Tá»•ng chi tiÃªu',
                  style: TextStyle(
                    color: context.palette.textPrimary.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if (preview.reportKind != null &&
                    preview.reportKind!.toUpperCase().contains('SAVING')) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Thu ${formatVnd(preview.totalIncome)} Â· Chi ${formatVnd(preview.totalExpense)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                // Transaction count
                Text(
                  preview.reportKind != null &&
                          preview.reportKind!.toUpperCase().contains('INCOME')
                      ? '${preview.transactionCount} khoáº£n thu trong ká»³'
                      : (preview.reportKind != null &&
                                preview.reportKind!.toUpperCase().contains(
                                  'SAVING',
                                )
                            ? '${preview.transactionCount} khoáº£n tÃ­ch lÅ©y trong ká»³'
                            : '${preview.transactionCount} khoáº£n chi trong ká»³'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (preview.byDay != null && preview.prevByDay != null) ...[
                  const SizedBox(height: 16),
                  _DailyCompareChart(
                    byDay: preview.byDay,
                    prevByDay: preview.prevByDay,
                  ),
                ],
                if (topCats.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Theo danh má»¥c',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.palette.textPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...topCats.map((c) {
                    final style = CategoryTheme.of(c.categoryCode);
                    final barW = (c.percent / 100.0).clamp(0.02, 1.0);
                    return InkWell(
                      onTap: () {
                        if (onSendMessage != null) {
                          onSendMessage!(
                            'TÃ¬m cÃ¡c khoáº£n chi cá»§a má»¥c ${style.label}',
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            // Circular Category Icon
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: style.color.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: CategoryTheme.iconOf(
                                  c.categoryCode,
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          style.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 13,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        formatVnd(c.total),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: barW,
                                            minHeight: 8,
                                            backgroundColor:
                                                context.palette.surfaceAlt,
                                            color: style.color,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${c.percent}%',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: style.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.go(AppRoutes.report),
                    icon: const Icon(Icons.arrow_forward_ios, size: 10),
                    label: const Text(
                      'Xem chi tiáº¿t',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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

class _BudgetSuggestionModal extends StatefulWidget {
  final _BudgetSuggestionPreview preview;
  final void Function(Map<String, num> overrides)? onApply;
  final VoidCallback? onDismiss;

  const _BudgetSuggestionModal({
    required this.preview,
    this.onApply,
    this.onDismiss,
  });

  @override
  State<_BudgetSuggestionModal> createState() => _BudgetSuggestionModalState();
}

class _BudgetSuggestionModalState extends State<_BudgetSuggestionModal> {
  final Map<String, bool> _selected = {};
  final Map<String, int> _amounts = {};

  @override
  void initState() {
    super.initState();
    for (final item in widget.preview.items) {
      _selected[item.categoryCode] = true;
      final raw = item.suggestedAmount;
      _amounts[item.categoryCode] = ((raw / 1000).round() * 1000);
    }
  }

  void _showEditDialog(String categoryCode, String label, int currentAmount) {
    final controller = TextEditingController(text: currentAmount.toString());
    final presets = [
      ('+10%', (currentAmount * 1.1).round()),
      ('+20%', (currentAmount * 1.2).round()),
      ('Ã—1.5', (currentAmount * 1.5).round()),
      ('-10%', (currentAmount * 0.9).round()),
      ('-20%', (currentAmount * 0.8).round()),
    ];
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: ctx.palette.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            title: Text(
              'Sá»­a háº¡n má»©c: $label',
              style: TextStyle(
                color: ctx.palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: TextStyle(color: ctx.palette.textPrimary),
                  decoration: InputDecoration(
                    suffixText: 'Ä‘',
                    suffixStyle: TextStyle(color: ctx.palette.textSecondary),
                    hintText: 'Nháº­p sá»‘ tiá»n...',
                    hintStyle: TextStyle(
                      color: ctx.palette.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Nháº­p nhanh',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ctx.palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: presets.map((p) {
                    return ActionChip(
                      label: Text(
                        p.$1,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: AppColors.teal.withValues(alpha: 0.08),
                      side: BorderSide(
                        color: AppColors.teal.withValues(alpha: 0.25),
                      ),
                      onPressed: () {
                        setDialogState(() {
                          controller.text = p.$2.toString();
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Há»§y', style: TextStyle(color: Colors.grey)),
              ),
              FilledButton(
                onPressed: () {
                  final val = int.tryParse(controller.text);
                  if (val != null && val >= 0) {
                    setState(() {
                      _amounts[categoryCode] = val;
                    });
                  }
                  Navigator.pop(ctx);
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                child: const Text('LÆ°u'),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTargetMonthLabel(String yyyyMM) {
    try {
      final parts = yyyyMM.split('-');
      if (parts.length == 2) {
        return '${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
    return yyyyMM;
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.teal;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Háº¡n má»©c ${_formatTargetMonthLabel(widget.preview.targetMonth)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: accent,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: widget.preview.items.length,
              separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) {
                final item = widget.preview.items[idx];
                final style = CategoryTheme.of(item.categoryCode);
                final isSel = _selected[item.categoryCode] ?? true;
                final currentAmt =
                    _amounts[item.categoryCode] ?? item.suggestedAmount;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selected[item.categoryCode] = !isSel;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 4,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isSel ? accent : Colors.transparent,
                            border: Border.all(
                              color: isSel
                                  ? accent
                                  : context.palette.textSecondary.withValues(
                                      alpha: 0.5,
                                    ),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.check,
                            color: isSel ? Colors.white : Colors.transparent,
                            size: 12,
                          ),
                        ),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: style.color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: CategoryTheme.iconOf(
                              item.categoryCode,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Opacity(
                            opacity: isSel ? 1.0 : 0.45,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  style.label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: context.palette.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (item.reason.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.reason,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.palette.textSecondary,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Opacity(
                          opacity: isSel ? 1.0 : 0.45,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${formatVnd(currentAmt)}Ä‘',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: accent,
                                    ),
                                  ),
                                  Opacity(
                                    opacity: isSel ? 1.0 : 0.0,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: accent,
                                      ),
                                      padding: const EdgeInsets.only(left: 4),
                                      constraints: const BoxConstraints(),
                                      onPressed: isSel
                                          ? () => _showEditDialog(
                                              item.categoryCode,
                                              style.label,
                                              currentAmt,
                                            )
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              if (item.baseSpending > 0 &&
                                  currentAmt != item.baseSpending)
                                Text(
                                  '${formatVnd(item.baseSpending)}Ä‘',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.palette.textSecondary
                                        .withValues(alpha: 0.6),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onDismiss?.call();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: context.palette.textSecondary.withValues(
                        alpha: 0.3,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Bá» qua',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.palette.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final overrides = <String, num>{};
                    for (final item in widget.preview.items) {
                      final isSel = _selected[item.categoryCode] ?? true;
                      if (!isSel) {
                        overrides[item.categoryCode] = -1;
                      } else {
                        overrides[item.categoryCode] =
                            _amounts[item.categoryCode] ?? item.suggestedAmount;
                      }
                    }
                    Navigator.pop(context);
                    widget.onApply?.call(overrides);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Ãp dá»¥ng',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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

class _BudgetSuggestionCard extends StatelessWidget {
  final _BudgetSuggestionPreview preview;
  final bool isApplied;
  final bool isDismissed;
  final void Function(Map<String, num> overrides)? onApply;
  final VoidCallback? onDismiss;

  const _BudgetSuggestionCard({
    required this.preview,
    this.isApplied = false,
    this.isDismissed = false,
    this.onApply,
    this.onDismiss,
  });

  String _formatTargetMonthLabel(String yyyyMM) {
    try {
      final parts = yyyyMM.split('-');
      if (parts.length == 2) {
        return '${parts[1]}/${parts[0]}';
      }
    } catch (_) {}
    return yyyyMM;
  }

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.teal;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.15), width: 1.5),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: accent, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Háº¡n má»©c ${_formatTargetMonthLabel(preview.targetMonth)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Mimo Ä‘Ã£ phÃ¢n tÃ­ch chi tiÃªu vÃ  cÃ³ má»™t sá»‘ gá»£i Ã½ háº¡n má»©c má»›i cho báº¡n.',
            style: TextStyle(
              fontSize: 12,
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          if (isApplied)
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: accent, size: 16),
                SizedBox(width: 6),
                Text(
                  'ÄÃ£ Ã¡p dá»¥ng háº¡n má»©c',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          else if (isDismissed)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel, color: Colors.grey, size: 16),
                const SizedBox(width: 6),
                const Text(
                  'ÄÃ£ bá» qua gá»£i Ã½',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => _BudgetSuggestionModal(
                      preview: preview,
                      onApply: onApply,
                      onDismiss: onDismiss,
                    ),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Xem gá»£i Ã½'),
              ),
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
    if (t.contains('LIMIT')) return const Color(0xFFF97316); // Cam tÆ°Æ¡i
    if (t.contains('GOAL')) return const Color(0xFF10B981); // Xanh Mint
    if (t.contains('USERNAME')) return const Color(0xFF64748B); // XÃ¡m nháº¹/Slate
    if (t.contains('TONE') || t.contains('VERBAL')) {
      return const Color(0xFF8B5CF6); // TÃ­m
    }
    if (t.contains('ALERT')) return const Color(0xFF3B82F6); // Xanh dÆ°Æ¡ng
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final isDone = isConfirmed || isRejected;

    return Opacity(
      opacity: isDone ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDone ? Colors.transparent : context.palette.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDone
                ? context.palette.textSecondary.withValues(alpha: 0.2)
                : accent.withValues(alpha: 0.15),
            width: isDone ? 1.0 : 1.5,
          ),
          boxShadow: isDone ? [] : context.palette.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Circular Icon Badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Icon(_icon, color: accent, size: 16)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    preview.summary,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: context.palette.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (preview.actionType.toUpperCase().contains('LIMIT') &&
                preview.categoryCode != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: CategoryTheme.of(
                          preview.categoryCode!,
                        ).color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: CategoryTheme.iconOf(
                          preview.categoryCode!,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            CategoryTheme.of(preview.categoryCode!).label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.palette.textPrimary,
                            ),
                          ),
                          Text(
                            'Háº¡n má»©c má»›i',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (preview.amount != null)
                      Text(
                        formatVnd(preview.amount!),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                  ],
                ),
              ),
            ] else if (preview.actionType.toUpperCase().contains('GOAL')) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.flag_rounded,
                          color: accent,
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nluString(
                                  preview.actionDetails?['goal_name'] ??
                                      preview.actionDetails?['goalName'],
                                ) ??
                                'Má»¥c tiÃªu má»›i',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: context.palette.textPrimary,
                            ),
                          ),
                          Text(
                            preview.actionType.toUpperCase() == 'ADD_GOAL'
                                ? 'ThÃªm tiá»n vÃ o má»¥c tiÃªu'
                                : 'Äáº·t má»¥c tiÃªu má»›i',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.palette.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (preview.amount != null)
                      Text(
                        formatVnd(preview.amount!),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                  ],
                ),
              ),
            ] else if (preview.actionType.toUpperCase().contains(
              'USERNAME',
            )) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'TÃªn má»›i: ',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.palette.textSecondary,
                      ),
                    ),
                    Text(
                      nluString(preview.actionDetails?['username']) ?? '...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (preview.amount != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _ActionChip(
                    label: formatVnd(preview.amount!),
                    accent: accent,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            if (isConfirmed)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: accent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    preview.navOnly ? 'ÄÃ£ má»Ÿ' : 'ÄÃ£ xÃ¡c nháº­n',
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            else if (isRejected)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cancel_rounded,
                    color: context.palette.textSecondary.withValues(alpha: 0.6),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ÄÃ£ bá» qua',
                    style: TextStyle(
                      color: context.palette.textSecondary.withValues(
                        alpha: 0.6,
                      ),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        side: BorderSide(
                          color: context.palette.textSecondary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        preview.navOnly ? 'Äá»ƒ sau' : 'Bá» qua',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.palette.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        preview.navOnly ? 'Má»Ÿ' : 'XÃ¡c nháº­n',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color? accent;
  const _ActionChip({required this.label, this.accent});

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

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (preview.items.length == 1) {
      final item = preview.items.first;
      final style = CategoryTheme.of(item.categoryCode);
      final isIncome = item.recordType.toLowerCase() == 'income';
      final color = isIncome ? AppColors.success : AppColors.danger;
      final prefix = isIncome ? '+' : '-';

      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.teal.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: context.palette.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Circular Category Icon Badge
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: CategoryTheme.iconOf(item.categoryCode, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.note.isNotEmpty ? item.note : style.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              style.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: style.color,
                              ),
                            ),
                          ),
                          if (item.occurredAt != null) ...[
                            Text(
                              ' â€¢ ',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                            Text(
                              _formatDate(item.occurredAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: context.palette.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$prefix${formatVnd(item.amount)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Multiple items case
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.teal.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: context.palette.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_rounded,
                  color: AppColors.teal,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Káº¿t quáº£ tÃ¬m kiáº¿m (${preview.items.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (preview.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 4.0,
              ),
              child: Text(
                'KhÃ´ng tÃ¬m tháº¥y giao dá»‹ch nÃ o.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.palette.textSecondary,
                ),
              ),
            ),
          ...preview.items.take(4).map((item) {
            final style = CategoryTheme.of(item.categoryCode);
            final isIncome = item.recordType.toLowerCase() == 'income';
            final color = isIncome ? AppColors.success : AppColors.danger;
            final prefix = isIncome ? '+' : '-';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  // Circular Category Icon Badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: style.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CategoryTheme.iconOf(item.categoryCode, size: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.note.isNotEmpty ? item.note : style.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.palette.textPrimary,
                          ),
                        ),
                        if (item.occurredAt != null)
                          Text(
                            _formatDate(item.occurredAt),
                            style: TextStyle(
                              fontSize: 9,
                              color: context.palette.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$prefix${formatVnd(item.amount)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (preview.items.length > 4) ...[
            const Divider(height: 16),
            InkWell(
              onTap: () => context.go(AppRoutes.report),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Xem táº¥t cáº£ káº¿t quáº£',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teal,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: AppColors.teal,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
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
  final Future<void> Function(_ChatMsg, Map<String, num>)?
  onApplyBudgetSuggestion;
  final Future<void> Function(_ChatMsg)? onDismissBudgetSuggestion;
  final void Function(_ChatMsg)? onEditTxCategory;
  final void Function(_ChatMsg, _TxPreview)? onEditTxPreview;
  final Future<void> Function(String)? onDownloadUrl;
  final void Function(String)? onSendMessage;

  const _ChatBubble({
    super.key,
    required this.message,
    this.onSaveTx,
    this.onSaveMultiTx,
    this.onConfirmAction,
    this.onRejectAction,
    this.onApplyBudgetSuggestion,
    this.onDismissBudgetSuggestion,
    this.onEditTxCategory,
    this.onEditTxPreview,
    this.onDownloadUrl,
    this.onSendMessage,
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
                    'âœï¸ Chá»‰nh sá»­a',
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
                          'âœ“ ÄÃ£ lÆ°u',
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
                        child: const Text('ðŸ’¾ LÆ°u'),
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
                '${message.multiRecords!.length} giao dá»‹ch Ä‘Æ°á»£c nháº­n dáº¡ng',
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
                          'âœ“ ÄÃ£ lÆ°u',
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
                        child: const Text('ðŸ’¾ LÆ°u'),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadExcelCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF), // light blue background
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.file_download_outlined,
                color: Colors.blue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Táº£i BÃ¡o CÃ¡o Excel/CSV',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tá»‡p dá»¯ liá»‡u chi tiÃªu Ä‘Ã£ Ä‘Æ°á»£c táº¡o thÃ nh cÃ´ng. Vui lÃ²ng báº¥m vÃ o nÃºt bÃªn dÆ°á»›i Ä‘á»ƒ lÆ°u vá» thiáº¿t bá»‹.',
            style: TextStyle(fontSize: 11, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                if (message.downloadUrl != null) {
                  onDownloadUrl?.call(message.downloadUrl!);
                }
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Báº¥m táº£i xuá»‘ng'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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

    final suppressText =
        !message.isUser &&
        message.actionPreview != null &&
        {
          'SET_ALERT',
          'SUGGEST_BUDGET',
        }.contains(message.actionPreview!.actionType);
    final hasText = message.text.isNotEmpty && !suppressText;
    final hasEmotion = !message.isUser && message.chatEmotion != null;
    final hasSpecialCard =
        !message.isUser &&
        (message.reportPreview != null ||
            (message.actionPreview != null &&
                _actionNeedsConfirm(message.actionPreview!.actionType)) ||
            message.searchPreview != null ||
            message.budgetSuggestionPreview != null ||
            message.txPreview != null ||
            message.downloadUrl != null ||
            (message.multiRecords != null && message.multiRecords!.isNotEmpty));

    return Column(
      crossAxisAlignment: alignment,
      children: [
        // Sticker xuáº¥t hiá»‡n TRÆ¯á»šC, Text xuáº¥t hiá»‡n SAU (khÃ´ng viá»n bong bÃ³ng, trong suá»‘t)
        if (hasEmotion)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 12.0),
            child: _ChatEmotionSticker(emotionAsset: message.chatEmotion!),
          ),

        // 1. Text bubble (chá»‰ hiá»ƒn thá»‹ náº¿u cÃ³ text hoáº·c Ä‘ang soáº¡n thÃªm)
        if (hasText || (!message.isUser && message.llmPending))
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.min(MediaQuery.of(context).size.width * 0.75, 400),
            ),
            child: Container(
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
                  bottomRight: Radius.circular(
                    message.isUser ? 4 : AppRadii.lg,
                  ),
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
                    const _TypingBubbleIndicator(showBackground: false),
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
          ),

        // 2. Special Component Card bubble
        if (hasSpecialCard)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: math.min(MediaQuery.of(context).size.width * 0.85, 460),
            ),
            child: Container(
              margin: const EdgeInsets.only(
                bottom: AppSpacing.md,
                left: 0,
                right: 60,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.reportPreview != null)
                    _ReportStoryCard(
                      preview: message.reportPreview!,
                      onSendMessage: onSendMessage,
                    ),
                  if (message.downloadUrl != null)
                    _buildDownloadExcelCard(context),
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
                      onApply: (overrides) =>
                          onApplyBudgetSuggestion?.call(message, overrides),
                      onDismiss: () => onDismissBudgetSuggestion?.call(message),
                    ),
                  if (message.searchPreview != null)
                    _SearchResultCard(preview: message.searchPreview!),
                  if (message.txPreview != null) _buildSingleTxCard(context),
                  if (message.multiRecords != null &&
                      message.multiRecords!.isNotEmpty)
                    _buildMultiTxCard(context),
                  if (message.isPremiumLocked) ...[
                    const SizedBox(height: 12),
                    ValueListenableBuilder<bool>(
                      valueListenable: AdsService.instance.premiumNotifier,
                      builder: (context, isPremium, child) {
                        if (isPremium) return const SizedBox.shrink();
                        return child!;
                      },
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => showPremiumUpsellSheet(context),
                          icon: const Icon(
                            Icons.workspace_premium_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            'NÃ¢ng cáº¥p Premium',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB347),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    message.time,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.palette.textSecondary.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 3. Suggested Actions Chips
        if (!message.isUser &&
            message.suggestedActions != null &&
            message.suggestedActions!.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(
              top: 4,
              bottom: AppSpacing.md,
              left: 0,
              right: 40,
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: message.suggestedActions!.map((action) {
                return ActionChip(
                  label: Text(
                    action,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal,
                    ),
                  ),
                  backgroundColor: AppColors.teal.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: AppColors.teal.withValues(alpha: 0.2),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 0,
                  ),
                  onPressed: () {
                    if (onSendMessage != null) {
                      onSendMessage!(action);
                    }
                  },
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  const _ChatComposer({
    required this.controller,
    required this.onSend,
    this.isSending = false,
  });

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
              enabled: !isSending,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => isSending ? null : onSend(),
              decoration: InputDecoration(
                hintText: isSending
                    ? 'Mimo Ä‘ang tráº£ lá»i...'
                    : 'Nháº¯n tin cho Mimo...',
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
              color: isSending
                  ? Colors.grey.withValues(alpha: 0.1)
                  : AppColors.teal.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: isSending ? null : onSend,
              icon: Icon(
                Icons.send,
                color: isSending ? Colors.grey : AppColors.teal,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConfettiOverlay extends StatefulWidget {
  final VoidCallback onFinished;
  const ConfettiOverlay({super.key, required this.onFinished});

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  final List<_Particle> _particles = [];
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _ctrl.forward().then((_) => widget.onFinished());

    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.pink,
      Colors.orange,
      Colors.purple,
      Colors.teal,
    ];
    for (int i = 0; i < 60; i++) {
      _particles.add(
        _Particle(
          x: _random.nextDouble(),
          y: -0.1 - _random.nextDouble() * 0.5,
          speedX: (_random.nextDouble() - 0.5) * 0.05,
          speedY: 0.05 + _random.nextDouble() * 0.1,
          color: colors[_random.nextInt(colors.length)],
          size: 5.0 + _random.nextDouble() * 8.0,
          rotation: _random.nextDouble() * 2 * math.pi,
          rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
        ),
      );
    }
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
      builder: (context, _) {
        return CustomPaint(
          painter: _ConfettiPainter(
            particles: _particles,
            progress: _ctrl.value,
          ),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _Particle {
  double x;
  double y;
  final double speedX;
  final double speedY;
  final Color color;
  final double size;
  double rotation;
  final double rotationSpeed;

  _Particle({
    required this.x,
    required this.y,
    required this.speedX,
    required this.speedY,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
  });

  void update() {
    x += speedX;
    y += speedY;
    rotation += rotationSpeed;
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      p.update();
      final screenX = p.x * size.width;
      final screenY = p.y * size.height;

      if (screenY > size.height || screenX < 0 || screenX > size.width) {
        continue;
      }

      canvas.save();
      canvas.translate(screenX, screenY);
      canvas.rotate(p.rotation);

      paint.color = p.color;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.6,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DailyCompareChart extends StatelessWidget {
  final List<dynamic>? byDay;
  final List<dynamic>? prevByDay;

  const _DailyCompareChart({this.byDay, this.prevByDay});

  @override
  Widget build(BuildContext context) {
    if (byDay == null ||
        byDay!.isEmpty ||
        prevByDay == null ||
        prevByDay!.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxLen = math.max(byDay!.length, prevByDay!.length);
    if (maxLen == 0) return const SizedBox.shrink();

    final int chunkSize = maxLen > 14 ? 7 : (maxLen > 10 ? 3 : 1);
    final List<double> currVals = [];
    final List<double> prevVals = [];

    for (int i = 0; i < maxLen; i += chunkSize) {
      double cSum = 0;
      double pSum = 0;
      for (int j = i; j < i + chunkSize && j < maxLen; j++) {
        cSum += j < byDay!.length
            ? (nluInt(nluMap(byDay![j])?['expense']) ?? 0).toDouble()
            : 0.0;
        pSum += j < prevByDay!.length
            ? (nluInt(nluMap(prevByDay![j])?['expense']) ?? 0).toDouble()
            : 0.0;
      }
      currVals.add(cSum);
      prevVals.add(pSum);
    }

    double maxY = 0;
    for (int i = 0; i < currVals.length; i++) {
      if (currVals[i] > maxY) maxY = currVals[i];
      if (prevVals[i] > maxY) maxY = prevVals[i];
    }
    if (maxY == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Ká»³ nÃ y',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 16),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: const Color(0xFF94A3B8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'Ká»³ trÆ°á»›c',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: MediaQuery.of(context).orientation == Orientation.landscape
              ? 120
              : 160,
          child: LineChart(
            LineChartData(
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  maxContentWidth: 180,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final isCurr = spot.barIndex == 0;
                      return LineTooltipItem(
                        '${isCurr ? "Ká»³ nÃ y" : "Ká»³ trÆ°á»›c"}: ${formatVnd(spot.y.toInt())}',
                        TextStyle(
                          color: isCurr ? AppColors.teal : AppColors.muted,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: AppColors.muted.withValues(alpha: 0.1),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (val, meta) {
                      final idx = val.toInt();
                      if (idx < 0 || idx >= currVals.length) {
                        return const SizedBox();
                      }
                      if (currVals.length > 8 && idx % 2 != 0) {
                        return const SizedBox();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          chunkSize > 1 ? 'T${idx + 1}' : '${idx + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: (currVals.length - 1).toDouble(),
              minY: 0,
              maxY: maxY * 1.15,
              lineBarsData: [
                LineChartBarData(
                  spots: List.generate(
                    currVals.length,
                    (i) => FlSpot(i.toDouble(), currVals[i]),
                  ),
                  isCurved: true,
                  color: AppColors.teal,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.teal.withValues(alpha: 0.25),
                        AppColors.teal.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                LineChartBarData(
                  spots: List.generate(
                    prevVals.length,
                    (i) => FlSpot(i.toDouble(), prevVals[i]),
                  ),
                  isCurved: true,
                  color: const Color(0xFF94A3B8).withValues(alpha: 0.6),
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  dashArray: [5, 5],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


