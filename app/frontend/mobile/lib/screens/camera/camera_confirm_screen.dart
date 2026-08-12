import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../utils/mimo_emotion.dart';
import '../../widgets/mimo_overlay.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/bill_processing_service.dart';
import '../../services/transaction_notifier.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../widgets/responsive_container.dart';
import '../../utils/formatters.dart';
import '../../services/streak_celebration.dart';
import '../../utils/budget_prompt.dart';
import '../../services/ads_service.dart';
import '../../widgets/interstitial_ad_dialog.dart';
import '../../widgets/premium_upsell_bottom_sheet.dart';

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

  int _amount = 0;
  String _category = 'Other';
  String _originalCategory = 'Other';
  String _note = '';
  late double _confidence;
  late String _recordType;

  @override
  void initState() {
    super.initState();
    _loadWallets();
    final data = widget.extractedData;
    if (data?['status'] == 'pending') {
      final txId = data!['transactionId'] as String?;
      final walletId =
          data['walletId'] as String? ?? ApiClient.lastSelectedWalletId ?? '';
      if (txId != null && walletId.isNotEmpty) {
        BillProcessingService.instance.trackExistingJob(
          transactionId: txId,
          walletId: walletId,
          localImagePath:
              data['imagePath'] as String? ?? data['localImagePath'] as String?,
        );
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.go(AppRoutes.home);
      });
      return;
    }
    final extracted = data?['extracted'] as Map<String, dynamic>?;
    _amount = extracted != null && extracted['amount'] is num
        ? (extracted['amount'] as num).toInt()
        : 0;
    _category = CategoryTheme.canonicalCodeOf(
      extracted?['category'] as String? ?? 'Other',
    );
    _originalCategory = _category;
    _note = extracted?['note'] as String? ?? '';
    _confidence = extracted != null && extracted['confidence'] is num
        ? (extracted['confidence'] as num).toDouble()
        : 0.0;
    _recordType = extracted?['record_type'] as String? ?? 'Expense';
    // Auto-confirm logic removed per user request: always show the confirm screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_amount <= 0) {
        _showEditSheet();
      }
    });
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
          _targetWalletId =
              widget.extractedData?['walletId'] as String? ??
              ApiClient.lastSelectedWalletId ??
              (wallets.isNotEmpty ? wallets[0]['id'] as String : '');
          final targetWallet = _wallets.firstWhere(
            (w) => w['id'] == _targetWalletId,
            orElse: () => null,
          );
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
      widget.extractedData?['imagePath'] as String? ??
      widget.extractedData?['localImagePath'] as String?;

  String? get _remoteImageUrl => widget.extractedData?['imageUrl'] as String?;

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

  Future<void> _onConfirm() async {
    if (_saving) return;
    final isGroupBill = widget.extractedData?['isGroupBill'] == true;
    final groupId = widget.extractedData?['groupId'] as String?;
    
    final wallets = _wallets.isNotEmpty ? _wallets : await _api.getWallets();
    if (!mounted) return;
    
    // Wallets logic is ignored if it's a group bill
    final targetWalletId = isGroupBill
        ? groupId!
        : _targetWalletId ??
          widget.extractedData?['walletId'] as String? ??
          ApiClient.lastSelectedWalletId ??
          (wallets.isNotEmpty ? wallets[0]['id'] as String : '');
          
    final targetWallet = isGroupBill
        ? null
        : wallets.firstWhere(
            (w) => w['id'] == targetWalletId,
            orElse: () => null,
          );
          
    final isGroupWallet =
        targetWallet != null && targetWallet['type'] == 'group';
    final reviewTxId = widget.extractedData?['transactionId'] as String?;

    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      if (!isGroupBill && wallets.isEmpty) throw Exception('Không có ví nào');
      if (_amount <= 0) {
        throw Exception(
          'Vui lòng nhập số tiền hợp lệ (lớn hơn 0)',
        );
      }

      final extracted =
          widget.extractedData?['extracted'] as Map<String, dynamic>?;
      final aiComment =
          extracted?['aiComment'] as String? ??
          widget.extractedData?['aiComment'] as String?;
      final mascotMood =
          extracted?['mascotMood'] as String? ??
          widget.extractedData?['mascotMood'] as String?;

      final nluMeta = widget.extractedData?['nlu'] as Map<String, dynamic>?;
      final llmFromNlu = nluMeta != null
          ? LlmMimoReply.fromNlu(nluMeta, intent: 'Record')
          : null;
      final llmText = (llmFromNlu?.text.isNotEmpty == true)
          ? llmFromNlu!.text
          : (aiComment ?? '');
      final llmMood = llmFromNlu?.emotionAsset ?? (mascotMood ?? 'Success');
      final llm = LlmMimoReply(text: llmText, emotionAsset: llmMood);

      if (reviewTxId != null) {
        if (isGroupBill) {
          await _api.updateGroupTransaction(reviewTxId, {
            'amount': _amount,
            'note': _note,
            'isDraft': false,
          });
        } else {
          await _api.updateTransaction(reviewTxId, {
            'amount': _amount,
            'type': _recordType == 'Income' ? 'income' : 'expense',
            'categoryCode': _category,
            'note': _note,
            'aiConfidence': _confidence,
            'isDraft': false,
            'processingStatus': 'completed',
            ...llm.toStoryPersistFields(),
          });
        }
      } else {
        String? imageUrl;
        final imagePath = widget.extractedData?['imagePath'] as String?;
        if (imagePath != null) {
          try {
            final uploadRes = await _api.uploadFile(imagePath);
            imageUrl = uploadRes['publicUrl'] as String?;
          } catch (_) {}
        }

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
      }
      if (!mounted) return;
      setState(() => _saving = false);
      notifyTransactionChanged();

      if (_category != _originalCategory) {
        final text =
            nluMeta?['text'] as String? ??
            nluMeta?['clean_content'] as String? ??
            'correction';
        _api
            .aiCorrection({
              'text': text,
              if (reviewTxId != null) 'transactionId': reviewTxId,
              'intent': 'Record',
              'categoryCode': _category,
              'recordType': _recordType,
            })
            .catchError((_) => {});
      }

      if (mounted) await StreakCelebration.instance.afterActivity(context);
      if (mounted) {
        await checkCategoryLimitAndSuggest(
          context,
          _category,
          walletId: targetWalletId,
        );
      }

      bool showAd = false;
      if (mounted) {
        showAd = AdsService.instance.incrementAndCheckIfNotPremium();
        if (showAd) {
          await showInterstitialAdDialog(
            context,
            onDismissed: () => showPremiumUpsellSheet(context),
          );
        }
      }

      if (!mounted) return;

      if (isGroupBill) {
        context.pop(); // Quay lại trang trước (có thể là trang chi tiết nhóm)
      } else if (isGroupWallet) {
        context.go(AppRoutes.shareWallet, extra: {'walletId': targetWalletId});
      } else {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.home);
        }
      }

      final reviewMsg = reviewTxId != null
          ? 'Đã cập nhật bill sau khi kiểm tra'
          : null;

      final mimoMsg = llm.text.isNotEmpty
          ? llm.text
          : (reviewMsg ?? 'Đã lưu! Mimo ghi nhận rồi nhé');
      Future.delayed(const Duration(milliseconds: 400), () {
        mimoController.show(
          MiMoResponse(emotionAsset: llm.emotionAsset, message: mimoMsg),
        );
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = e.localizedMessage;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = 'Không thể lưu giao dịch';
      });
    }
  }

  void _showEditSheet() {
    final amountCtrl = TextEditingController(text: _amount.toString());
    final noteCtrl = TextEditingController(text: _note);
    String editCategory = CategoryTheme.canonicalCodeOf(_category);
    if (!CategoryTheme.primaryCodes.contains(editCategory)) {
      editCategory = 'Other';
    }
    String? editWalletId = _targetWalletId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: Colors.transparent,
      builder: (ctx) => GestureDetector(
        onTap: () => FocusScope.of(ctx).unfocus(),
        child: StatefulBuilder(
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
            child: SingleChildScrollView(
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
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      hintText: 'Nhập số tiền',
                      suffixText: 'đ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Danh mục',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                        .where(
                          (e) => CategoryTheme.primaryCodes.contains(e.key),
                        )
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
                      if (val != null) {
                        setSheetState(() {
                          editCategory = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ví lưu',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _wallets.any((w) => w['id'] == editWalletId)
                        ? editWalletId
                        : null,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                    ),
                    items: _wallets
                        .map(
                          (w) => DropdownMenuItem<String>(
                            value: w['id'] as String,
                            child: Text(w['name'] as String? ?? 'Ví'),
                          ),
                        )
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
                  Text(
                    'Ghi chú',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                      onPressed: () {
                        final cleanAmountText = amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
                        final parsedAmount =
                            int.tryParse(cleanAmountText) ?? _amount;
                        if (parsedAmount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Vui lòng nhập số tiền hợp lệ (lớn hơn 0)',
                              ),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                          return;
                        }
                        setState(() {
                          _amount = parsedAmount;
                          _note = noteCtrl.text;
                          _category = editCategory;
                          _targetWalletId = editWalletId;
                          final targetWallet = _wallets.firstWhere(
                            (w) => w['id'] == _targetWalletId,
                            orElse: () => null,
                          );
                          if (targetWallet != null) {
                            final isGroup = targetWallet['type'] == 'group';
                            final name = targetWallet['name'] as String?;
                            if (name != null) {
                              _targetWalletName = isGroup
                                  ? '$name (Ví chung)'
                                  : name;
                            }
                          }
                        });
                        ctx.pop();
                        // Auto-confirm after editing to save user an extra click
                        // and prevent confusion about whether it was saved.
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (mounted) _onConfirm();
                        });
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Xác nhận & Lưu'),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    if (widget.extractedData?['status'] == 'pending') {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: AppColors.teal)),
      );
    }

    final confidencePct = (_confidence * 100).toStringAsFixed(0);
    final needsUserConfirm =
        _confidence < 0.9 || widget.extractedData?['reviewBill'] == true;
    final isLowConfidence = _confidence < 0.9;
    final isReviewBill = widget.extractedData?['reviewBill'] == true;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape =
              constraints.maxWidth > constraints.maxHeight ||
              constraints.maxWidth >= 600;

          final contentColumn = SafeArea(
            left: !isLandscape,
            right: !isLandscape,
            child: Center(
              child: ResponsiveMaxWidthContainer(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Top bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => context.pop(),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              isReviewBill
                                  ? 'Kiểm tra bill'
                                  : 'AI xác nhận',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(width: 40),
                          ],
                        ),
                        // Confidence badge
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _confidenceColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _confidenceColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome,
                                color: _confidenceColor,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'AI nhận dạng với độ chính xác $confidencePct%',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: _confidenceColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Low confidence warning
                        if (isLowConfidence) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.warning_amber,
                                  color: AppColors.danger,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Độ chính xác thấp — hãy kiểm tra lại',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.danger),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(
                          height: isLandscape
                              ? 24
                              : constraints.maxHeight * 0.1,
                        ),
                        // Error banner
                        if (_saveError != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppRadii.md),
                            ),
                            child: Text(
                              _saveError!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        // Transaction card
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppColors.teal.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.md,
                                      ),
                                    ),
                                    child: Center(
                                      child: CategoryTheme.iconOf(
                                        _category,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Giao dịch mới',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: Colors.white70),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _note.isNotEmpty
                                              ? _note
                                              : CategoryTheme.of(
                                                  _category,
                                                ).label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    formatVnd(_amount),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AppColors.teal,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Divider(color: Colors.white24, height: 1),
                              const SizedBox(height: 16),
                              _DetailRow(
                                label: 'Danh mục',
                                value: CategoryTheme.of(_category).label,
                              ),
                              _DetailRow(
                                label: 'Số tiền',
                                value: formatVnd(_amount),
                              ),
                              if (_note.isNotEmpty)
                                _DetailRow(label: 'Ghi chú', value: _note),
                              if (_targetWalletName != null)
                                _DetailRow(
                                  label: 'Ví lưu',
                                  value: _targetWalletName!,
                                ),
                              _DetailRow(
                                label: 'Thời gian',
                                value: _formatNow(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (!needsUserConfirm && _saving)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Độ chính xác cao — đang lưu tự động...',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        if (needsUserConfirm)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _saving ? null : _showEditSheet,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(
                                      color: Colors.white54,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.lg,
                                      ),
                                    ),
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
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        AppRadii.lg,
                                      ),
                                    ),
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text(
                                          'Xác nhận ✓',
                                          style: TextStyle(
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
                ),
              ),
            ),
          );

          if (isLandscape) {
            return Row(
              children: [
                Expanded(flex: 4, child: ClipRect(child: _buildBackground())),
                Expanded(
                  flex: 6,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF111827), // Dark slate
                    ),
                    child: contentColumn,
                  ),
                ),
              ],
            );
          }

          return Stack(
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
              contentColumn,
            ],
          );
        },
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
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
