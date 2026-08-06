import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/categories.dart';
import '../theme/app_radii.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';
import '../services/transaction_notifier.dart';
import 'category_chip.dart';
import '../utils/mimo_emotion.dart';
import '../routes/app_routes.dart';
import '../services/api_client.dart';
import 'mimo_snackbar.dart';

class TransactionStoryCard extends StatelessWidget {
  final dynamic tx;

  /// Danh sách id để lướt qua trong màn hình chi tiết (tùy chọn).
  final List<String>? allStoryIds;
  final String? walletOwnerId;
  final String? fallbackUserAvatar;

  const TransactionStoryCard({
    super.key,
    required this.tx,
    this.allStoryIds,
    this.walletOwnerId,
    this.fallbackUserAvatar,
  });

  Future<void> _onLongPress(BuildContext context) async {
    final api = ApiClient();
    final picked = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Sửa danh mục',
                style: Theme.of(
                  ctx,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: CategoryTheme.primaryCodes.map((code) {
                  final style = CategoryTheme.of(code);
                  return ListTile(
                    leading: CategoryTheme.iconOf(code, size: 22),
                    title: Text(style.label),
                    onTap: () => Navigator.pop(ctx, code),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    try {
      await api.updateTransaction(tx['id'] ?? '', {'categoryCode': picked});
      notifyTransactionChanged();
      if (context.mounted) {
        MimoSnackBar.showSuccess(
          context,
          message:
              'Đã cập nhật giao dịch và ghi nhận góp ý! Mimo sẽ học thêm từ bạn 🙏',
        );
      }
    } catch (_) {}
  }

  void _showQuickAmountFill(BuildContext context, String txId, String label) {
    final amountCtrl = TextEditingController();
    bool saving = false;

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
                  'Bổ sung số tiền',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Điền số tiền còn thiếu cho "$label"',
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Nhập số tiền',
                    suffixText: 'đ',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Quick amount chips
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [50000, 100000, 200000, 500000].map((val) {
                    return InkWell(
                      onTap: () {
                        amountCtrl.text = val.toString();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: ctx.palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                          border: Border.all(color: ctx.palette.border),
                        ),
                        child: Text(
                          formatVnd(val),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            final parsed = int.tryParse(amountCtrl.text);
                            if (parsed == null || parsed <= 0) {
                              MimoSnackBar.showInfo(
                                context,
                                message: 'Vui lòng nhập số tiền hợp lệ',
                              );
                              return;
                            }
                            setSheetState(() => saving = true);
                            try {
                              final api = ApiClient();
                              await api.updateTransaction(txId, {
                                'amount': parsed,
                                'isDraft': false,
                              });
                              notifyTransactionChanged();
                              if (ctx.mounted) ctx.pop();
                            } catch (_) {
                              setSheetState(() => saving = false);
                              if (context.mounted) {
                                MimoSnackBar.showInfo(
                                  context,
                                  message: 'Không thể cập nhật giao dịch',
                                );
                              }
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Lưu giao dịch',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDraft = tx['isDraft'] == true;
    if (isDraft) {
      final category =
          tx['category_name'] as String? ??
          tx['categoryCode'] as String? ??
          tx['category_code'] as String? ??
          'Others';
      final note = tx['note'] as String? ?? '';
      final displayTime = txTimestampIso(tx) ?? '';
      final source = tx['source'] as String? ?? '';
      final catStyle = CategoryTheme.of(category);
      final label = note.isNotEmpty ? note : catStyle.label;

      return GestureDetector(
        onTap: () => _showQuickAmountFill(context, tx['id'] as String, label),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB), // Amber 50
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: const Color(0xFFFDE68A),
              width: 1.5,
            ), // Amber 200
            boxShadow: context.palette.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7), // Amber 100
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      source == 'voice'
                          ? Icons.mic_none_rounded
                          : (source == 'bill'
                                ? Icons.receipt_long_rounded
                                : Icons.edit_note_rounded),
                      color: const Color(0xFFD97706), // Amber 600
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          source == 'voice'
                              ? 'Nhập liệu giọng nói'
                              : (source == 'bill'
                                    ? 'Nhập hóa đơn'
                                    : 'Giao dịch nháp'),
                          style: const TextStyle(
                            color: Color(0xFFB45309), // Amber 700
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Thiếu số tiền cho "$label"',
                          style: const TextStyle(
                            color: Color(0xFF78350F), // Amber 900
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color(0xFFD97706),
                    size: 14,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Bạn quên chưa nhập số tiền cho giao dịch này, chạm vào đây để điền nhanh nhé!',
                style: TextStyle(
                  color: Color(0xFF92400E), // Amber 800
                  fontSize: 11,
                  height: 1.4,
                ),
              ),
              if (displayTime.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _formatTime(displayTime),
                  style: const TextStyle(color: Color(0xFFD97706), fontSize: 9),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final amount = parseToInt(tx['amount']);
    final type = tx['type'] as String? ?? 'expense';
    final category =
        tx['category_name'] as String? ??
        tx['categoryCode'] as String? ??
        tx['category_code'] as String? ??
        'Other';
    final note = tx['note'] as String? ?? '';
    final originalText =
        tx['originalText'] as String? ?? tx['original_text'] as String? ?? '';
    final caption = originalText.isNotEmpty ? originalText : note;
    final displayTime = txTimestampIso(tx) ?? '';
    final isExpense = type.toLowerCase() == 'expense';
    final catStyle = CategoryTheme.of(category);

    final storyId =
        tx['storyId'] as String? ??
        tx['story_id'] as String? ??
        tx['id'] as String? ??
        '';
    final imageUrl = tx['imageUrl'] as String? ?? tx['image_url'] as String?;
    final aiComment = tx['aiComment'] as String? ?? tx['ai_message'] as String?;
    final mascotMoodRaw =
        tx['mascotMood'] as String? ?? tx['mascot_mood'] as String?;
    final mascotMood = normalizeMimoAssetName(
      mascotMoodRaw,
      fallback: 'Success',
    );

    // User display
    final userName =
        tx['username'] as String? ?? tx['user_name'] as String? ?? 'Bạn';
    final userAvatar =
        tx['userAvatar'] as String? ??
        tx['user_avatar'] as String? ??
        fallbackUserAvatar;

    return GestureDetector(
      onTap: storyId.isNotEmpty
          ? () {
              final ids = allStoryIds;
              if (ids != null && ids.isNotEmpty) {
                final idx = ids.indexOf(storyId);
                context.push(
                  AppRoutes.storyDetailOf(storyId),
                  extra: {'storyIds': ids, 'initialIndex': idx < 0 ? 0 : idx},
                );
              } else {
                context.push(AppRoutes.storyDetailOf(storyId));
              }
            }
          : null,
      onLongPress: () => _onLongPress(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: context.palette.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Post header: avatar + name + time + category badge ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  // User avatar circle (letter-based when no photo)
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: catStyle.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: catStyle.color.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: userAvatar != null && userAvatar.isNotEmpty
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: userAvatar,
                              fit: BoxFit.cover,
                              memCacheWidth: 200,
                              errorWidget: (_, _, _) => Center(
                                child: Text(
                                  userName.isNotEmpty
                                      ? userName[0].toUpperCase()
                                      : 'B',
                                  style: TextStyle(
                                    color: catStyle.color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : 'B',
                              style: TextStyle(
                                color: catStyle.color,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Row(
                          children: [
                            CategoryChip(category: category),
                            const SizedBox(width: 6),
                            if (displayTime.isNotEmpty)
                              Text(
                                _formatTime(displayTime),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.muted,
                                      fontSize: 10,
                                    ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.more_horiz,
                    color: AppColors.muted,
                    size: 20,
                  ),
                ],
              ),
            ),

            // ── Caption: user's note (text they typed) ──
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                child: Text(
                  caption,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),

            // ── Amount chip (moved above image) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isExpense
                          ? AppColors.danger.withValues(alpha: 0.1)
                          : AppColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isExpense
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          size: 12,
                          color: isExpense ? AppColors.danger : AppColors.teal,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${isExpense ? '-' : '+'}${formatVnd(amount)}',
                          style: TextStyle(
                            color: isExpense
                                ? AppColors.danger
                                : AppColors.teal,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Photo attachment — bo góc và có padding ──
            if (imageUrl != null && imageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1.5,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      memCacheWidth: 1080,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),

            Divider(height: 1, color: context.palette.divider),

            // ── Compact Mimo AI comment bubble ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: context.palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Mimo avatar or robot emoji
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/MiMo/emotions/$mascotMood.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Text('🤖', style: TextStyle(fontSize: 10)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mimo: ${(aiComment != null && aiComment.isNotEmpty) ? aiComment : 'Mimo đã ghi nhận giao dịch này!'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.palette.textPrimary,
                          height: 1.35,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String isoDate) {
    final dt = parseToLocalDateTime(isoDate);
    if (dt == null) return '';
    return formatDateTimeShort(dt);
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────
