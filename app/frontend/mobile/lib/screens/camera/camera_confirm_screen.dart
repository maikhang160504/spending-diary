import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../utils/mimo_emotion.dart';
import '../../widgets/mimo_overlay.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/transaction_notifier.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';
import '../../services/streak_celebration.dart';
import '../../widgets/loading_indicator.dart';
import '../../utils/budget_prompt.dart';

class CameraConfirmScreen extends StatefulWidget {
  /// Extracted expense data passed from CameraInputScreen via GoRouter extra.
  final Map<String, dynamic>? extractedData;

  const CameraConfirmScreen({super.key, this.extractedData});

  @override
  State<CameraConfirmScreen> createState() => _CameraConfirmScreenState();
}

class _CameraConfirmScreenState extends State<CameraConfirmScreen> {
  final _api = ApiClient();
  bool _saving = false;
  String? _saveError;

  List<dynamic> _wallets = [];
  String? _targetWalletId;
  String? _targetWalletName;

  // Async bill flow state
  bool _isPending = false;
  bool _processingDone = false;
  String? _processingError;
  String? _transactionId;
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSub;
  Timer? _wsTimeout;
  Map<String, dynamic>? _wsData;

  // Editable fields
  late int _amount;
  late String _category;
  late String _note;
  late double _confidence;
  late String _recordType;

  @override
  void initState() {
    super.initState();
    _loadWallets();
    final data = widget.extractedData;
    if (data?['status'] == 'pending') {
      _isPending = true;
      _transactionId = data!['transactionId'] as String?;
      _amount = 0;
      _category = 'Others';
      _note = '';
      _confidence = 0.0;
      _recordType = 'Expense';
      _connectWebSocket();
    } else {
      final extracted = data?['extracted'] as Map<String, dynamic>?;
      _amount = extracted != null && extracted['amount'] is num ? (extracted['amount'] as num).toInt() : 0;
      _category = extracted?['category'] as String? ?? 'Others';
      _note = extracted?['note'] as String? ?? '';
      _confidence = extracted != null && extracted['confidence'] is num ? (extracted['confidence'] as num).toDouble() : 0.0;
      _recordType = extracted?['record_type'] as String? ?? 'Expense';
      if (!_isPending && _confidence >= 0.9 && _amount > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _onConfirm());
      }
    }
  }

  Future<void> _loadWallets() async {
    try {
      final wallets = await _api.getWallets();
      wallets.sort((a, b) {
        final aType = a['type'] as String? ?? 'personal';
        final bType = b['type'] as String? ?? 'personal';
        if (aType == 'personal' && bType != 'personal') return -1;
        if (aType != 'personal' && bType == 'personal') return 1;
        return 0;
      });
      if (mounted) {
        setState(() {
          _wallets = wallets;
          _targetWalletId = widget.extractedData?['walletId'] as String? ?? ApiClient.lastSelectedWalletId ?? (wallets.isNotEmpty ? wallets[0]['id'] as String : '');
          final targetWallet = _wallets.firstWhere((w) => w['id'] == _targetWalletId, orElse: () => null);
          if (targetWallet != null) {
            final isGroup = targetWallet['type'] == 'group';
            final name = targetWallet['name'] as String?;
            if (name != null) {
              _targetWalletName = isGroup ? '$name (Ví chung)' : name;
            }
          }
        });
      }
    } catch (_) {}
  }

  String? get _localImagePath =>
      widget.extractedData?['imagePath'] as String? ?? widget.extractedData?['localImagePath'] as String?;

  String? get _remoteImageUrl =>
      widget.extractedData?['imageUrl'] as String? ??
      _wsData?['imageUrl'] as String? ??
      _wsData?['image_url'] as String?;

  Widget _buildBackground() {
    final path = _localImagePath;
    if (path != null && File(path).existsSync()) {
      return Image.file(File(path), fit: BoxFit.cover);
    }
    final url = _remoteImageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        memCacheWidth: 1080,
        errorWidget: (_, u, e) => Container(color: Colors.black87),
      );
    }
    return Container(color: Colors.black87);
  }

  Future<void> _connectWebSocket() async {
    final token = await _api.accessToken;
    if (token == null || !mounted) return;
    final wsUrl = Uri.parse(
      '${_api.baseUrl.replaceFirst(RegExp(r'^http'), 'ws').replaceFirst('/api/v1', '')}/ws?token=$token',
    );
    _wsChannel = WebSocketChannel.connect(wsUrl);
    // Phòng khi server không phản hồi: dừng trạng thái "đang xử lý" sau 45s.
    _wsTimeout = Timer(const Duration(seconds: 45), () {
      if (mounted && !_processingDone && _processingError == null) {
        setState(() => _processingError = 'Xử lý quá lâu, vui lòng thử lại');
      }
      _wsSub?.cancel();
      _wsChannel?.sink.close();
    });
    _wsSub = _wsChannel!.stream.listen(
      (msg) {
        if (!mounted) return;
        try {
          final json = jsonDecode(msg as String) as Map<String, dynamic>;
          if (json['type'] == 'transaction_done' && json['transactionId'] == _transactionId) {
            final d = json['data'] as Map<String, dynamic>? ?? {};
            setState(() {
              _processingDone = true;
              _wsData = d;
              _amount = ((d['amount'] ?? 0) is num) ? (d['amount'] as num).toInt() : 0;
              _category = d['category'] as String? ?? 'Others';
              _note = d['note'] as String? ?? '';
              _confidence = 0.85;
              _recordType = d['record_type'] as String? ?? 'Expense';
            });
            _wsTimeout?.cancel();
            _wsSub?.cancel();
            _wsChannel?.sink.close();
            final mood = d['mascot_mood'] as String?;
            final story = d['story'] as String?;
            Future.delayed(const Duration(milliseconds: 300), () {
              if (!mounted) return;
              mimoController.show(MiMoResponse(
                emotionAsset: normalizeMimoAssetName(mood, fallback: 'Success'),
                message: story?.substring(0, story.length.clamp(0, 80)) ?? '✅ Bill đã được xử lý xong!',
              ));
            });
          } else if (json['type'] == 'transaction_failed' && json['transactionId'] == _transactionId) {
            setState(() => _processingError = json['error']?.toString() ?? 'Xử lý thất bại');
          }
        } catch (_) {}
      },
      onError: (_) {
        if (mounted && !_processingDone) setState(() => _processingError = 'Mất kết nối WebSocket');
      },
      onDone: () {
        // Server đóng kết nối trước khi có kết quả → coi như thất bại.
        if (mounted && !_processingDone && _processingError == null) {
          setState(() => _processingError = 'Mất kết nối khi đang xử lý, vui lòng thử lại');
        }
      },
    );
  }

  @override
  void dispose() {
    _wsTimeout?.cancel();
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    super.dispose();
  }

  Future<void> _onConfirm() async {
    final wallets = _wallets.isNotEmpty ? _wallets : await _api.getWallets();
    if (!mounted) return;
    final targetWalletId = _targetWalletId ?? widget.extractedData?['walletId'] as String? ?? ApiClient.lastSelectedWalletId ?? (wallets.isNotEmpty ? wallets[0]['id'] as String : '');
    final targetWallet = wallets.firstWhere((w) => w['id'] == targetWalletId, orElse: () => null);
    final isGroupWallet = targetWallet != null && targetWallet['type'] == 'group';

    if (_isPending && _processingDone) {
      if (isGroupWallet) {
        context.go(AppRoutes.shareWallet, extra: {'walletId': targetWalletId});
      } else {
        context.go(AppRoutes.home);
      }
      Future.delayed(const Duration(milliseconds: 400), () {
        final moodAsset = normalizeMimoAssetName(_wsData?['mascot_mood'] as String?, fallback: 'Success');
        final llmStory = _wsData?['story'] as String?;
        const msgs = ['✅ Bill đã lưu!', '🎉 MiMo ghi nhận rồi nhé!'];
        final fallbackMsg = msgs[Random().nextInt(msgs.length)];
        mimoController.show(MiMoResponse(emotionAsset: moodAsset, message: llmStory ?? fallbackMsg));
      });
      return;
    }
    setState(() { _saving = true; _saveError = null; });
    try {
      if (wallets.isEmpty) throw Exception('Không có ví nào');
      
      String? imageUrl;
      final imagePath = widget.extractedData?['imagePath'] as String?;
      if (imagePath != null) {
        try {
          final uploadRes = await _api.uploadFile(imagePath);
          imageUrl = uploadRes['publicUrl'] as String?;
        } catch (_) {}
      }

      final nluMeta = widget.extractedData?['nlu'] as Map<String, dynamic>?;
      final llm = nluMeta != null
          ? LlmMimoReply.fromNlu(nluMeta, intent: 'Record')
          : const LlmMimoReply(text: '', emotionAsset: 'Success');
      await _api.createTransaction({
        'walletId': targetWalletId,
        'amount': _amount,
        'type': _recordType == 'Income' ? 'income' : 'expense',
        'categoryCode': _category,
        'note': _note,
        'source': imageUrl != null ? 'story' : 'text',
        'imageUrl': imageUrl,
        'aiConfidence': _confidence,
        'aiExtracted': true,
        ...llm.toStoryPersistFields(),
        if (nluMeta != null) 'aiMeta': {'nlu': nluMeta},
      });
      if (!mounted) return;
      setState(() => _saving = false);
      notifyTransactionChanged();
      if (mounted) await StreakCelebration.instance.afterActivity(context);
      if (mounted) {
        checkCategoryLimitAndSuggest(context, _category);
      }
      if (!mounted) return;

      if (isGroupWallet) {
        context.go(AppRoutes.shareWallet, extra: {'walletId': targetWalletId});
      } else {
        context.go(AppRoutes.home);
      }

      final mimoMsg = llm.text.isNotEmpty ? llm.text : '✅ Đã lưu! Mimo ghi nhận rồi nhé 😊';
      Future.delayed(const Duration(milliseconds: 400), () {
        mimoController.show(MiMoResponse(
          emotionAsset: llm.emotionAsset,
          message: mimoMsg,
        ));
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _saveError = e.localizedMessage; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _saving = false; _saveError = 'Không thể lưu giao dịch'; });
    }
  }

  void _showEditSheet() {
    final amountCtrl = TextEditingController(text: _amount.toString());
    final noteCtrl = TextEditingController(text: _note);
    String editCategory = _category;
    String? editWalletId = _targetWalletId;

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
                initialValue: CategoryTheme.styles.containsKey(editCategory) ? editCategory : 'Other',
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
                  if (val != null) {
                    setSheetState(() {
                      editCategory = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Text('Ví lưu', style: Theme.of(ctx).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _wallets.any((w) => w['id'] == editWalletId) ? editWalletId : null,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                ),
                items: _wallets
                    .map((w) => DropdownMenuItem<String>(
                          value: w['id'] as String,
                          child: Text(w['name'] as String? ?? 'Ví'),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setSheetState(() {
                      editWalletId = val;
                    });
                  }
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
                      _amount = int.tryParse(amountCtrl.text) ?? _amount;
                      _note = noteCtrl.text;
                      _category = editCategory;
                      _targetWalletId = editWalletId;
                      final targetWallet = _wallets.firstWhere((w) => w['id'] == _targetWalletId, orElse: () => null);
                      if (targetWallet != null) {
                        final isGroup = targetWallet['type'] == 'group';
                        final name = targetWallet['name'] as String?;
                        if (name != null) {
                          _targetWalletName = isGroup ? '$name (Ví chung)' : name;
                        }
                      }
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
  Color get _confidenceColor {
    if (_confidence >= 0.8) return AppColors.teal;
    if (_confidence >= 0.6) return const Color(0xFFF59E0B);
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    if (_isPending && !_processingDone && _processingError == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const LoadingIndicator(size: 120),
            const SizedBox(height: 16),
            Text('MiMo đang đọc bill...', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text('AI đang phân tích hóa đơn, vui lòng chờ', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54)),
            if (_wsData != null) ...[
              const SizedBox(height: 8),
              Text('Đã nhận: ${_wsData!['category'] ?? ''}', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ]),
        ),
      );
    }

    if (_processingError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 56),
              const SizedBox(height: 16),
              Text('Xử lý bill thất bại', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text(_processingError!, style: const TextStyle(color: Colors.white54, fontSize: 13), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.pop(),
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                child: const Text('Quay lại'),
              ),
            ]),
          ),
        ),
      );
    }

    final confidencePct = (_confidence * 100).toStringAsFixed(0);
    final needsUserConfirm = _confidence < 0.9;
    final isLowConfidence = _confidence < 0.9;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _buildBackground()),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xAA000000), Color(0xFF000000)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      Text('AI xác nhận', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 40),
                    ],
                  ),
                  // Confidence badge
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _confidenceColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _confidenceColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.auto_awesome, color: _confidenceColor, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'AI nhận dạng với độ chính xác $confidencePct%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: _confidenceColor, fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                  // Low confidence warning
                  if (isLowConfidence) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.warning_amber, color: AppColors.danger, size: 14),
                        const SizedBox(width: 6),
                        Text('Độ chính xác thấp — hãy kiểm tra lại', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.danger)),
                      ]),
                    ),
                  ],
                  const Spacer(),
                  // Error banner
                  if (_saveError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Text(_saveError!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  // Transaction card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: AppColors.teal.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadii.md)),
                          child: Center(child: CategoryTheme.iconOf(_category, size: 32)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Giao dịch mới', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
                          const SizedBox(height: 4),
                          Text(_note.isNotEmpty ? _note : CategoryTheme.of(_category).label,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ])),
                        Text(formatVnd(_amount), style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white24, height: 1),
                      const SizedBox(height: 16),
                      _DetailRow(label: 'Danh mục', value: CategoryTheme.of(_category).label),
                      _DetailRow(label: 'Số tiền', value: formatVnd(_amount)),
                      if (_note.isNotEmpty) _DetailRow(label: 'Ghi chú', value: _note),
                      if (_targetWalletName != null) _DetailRow(label: 'Ví lưu', value: _targetWalletName!),
                      _DetailRow(label: 'Thời gian', value: _formatNow()),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  if (!needsUserConfirm && _saving)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Độ chính xác cao — đang lưu tự động...', style: TextStyle(color: Colors.white70)),
                    ),
                  if (needsUserConfirm)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : _showEditSheet,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white54),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                            ),
                            child: const Text('Chỉnh sửa'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _onConfirm,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                            ),
                            child: _saving
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text('Xác nhận ✓', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNow() {
    final dt = DateTime.now();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} - ${dt.day}/${dt.month}/${dt.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70))),
        Expanded(child: Text(value, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}
