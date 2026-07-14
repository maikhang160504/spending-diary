import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';
import '../theme/categories.dart';
import '../theme/app_radii.dart';
import '../theme/app_palette.dart';
import '../theme/app_spacing.dart';
import '../utils/formatters.dart';

class InlineCalendarView extends StatefulWidget {
  final List<dynamic> byDay;
  final List<dynamic> transactions;
  final String? walletOwnerId;

  const InlineCalendarView({
    super.key,
    this.byDay = const [],
    this.transactions = const [],
    this.walletOwnerId,
  });
  @override
  State<InlineCalendarView> createState() => InlineCalendarViewState();
}

class InlineCalendarViewState extends State<InlineCalendarView> {
  DateTime _focus = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;

  Map<int, Map<String, dynamic>> get _dayMap {
    final result = <int, Map<String, dynamic>>{};
    for (final entry in widget.byDay) {
      final e = entry as Map<String, dynamic>;
      final dayStr = e['day'] as String? ?? '';
      if (dayStr.isEmpty) continue;
      try {
        final dt = DateTime.parse(dayStr);
        if (dt.year == _focus.year && dt.month == _focus.month) {
          result[dt.day] = e;
        }
      } catch (_) {}
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_focus.year, _focus.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_focus.year, _focus.month);
    final startWeekday = firstDay.weekday % 7;
    final dayMap = _dayMap;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () => setState(() {
                  _focus = DateTime(_focus.year, _focus.month - 1);
                  _selectedDay = null;
                }),
              ),
              Text(
                'tháng ${_focus.month} ${_focus.year}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () => setState(() {
                  _focus = DateTime(_focus.year, _focus.month + 1);
                  _selectedDay = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: startWeekday + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 0.58,
            ),
            itemBuilder: (ctx, i) {
              if (i < startWeekday) return const SizedBox();
              final day = i - startWeekday + 1;
              final isSelected = _selectedDay == day;
              final isToday =
                  _focus.month == DateTime.now().month &&
                  _focus.year == DateTime.now().year &&
                  day == DateTime.now().day;

              final dayTxList = widget.transactions.where((tx) {
                final dateStr =
                    tx['occurredAt'] as String? ??
                    tx['occurred_at'] as String? ??
                    tx['createdAt'] as String? ??
                    tx['created_at'] as String? ??
                    '';
                if (dateStr.isEmpty) return false;
                try {
                  final dt = DateTime.parse(dateStr).toLocal();
                  return dt.year == _focus.year &&
                      dt.month == _focus.month &&
                      dt.day == day;
                } catch (_) {
                  return false;
                }
              }).toList();

              return GestureDetector(
                onTap: () => setState(
                  () => _selectedDay = _selectedDay == day ? null : day,
                ),
                child: _buildDayCell(day, dayTxList, isSelected, isToday),
              );
            },
          ),
          if (_selectedDay != null && dayMap[_selectedDay!] != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_selectedDay tháng ${_focus.month} ${_focus.year}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '-${formatVnd((dayMap[_selectedDay!]!['expense'] as num?)?.toInt() ?? 0)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (((dayMap[_selectedDay!]!['income'] as num?)?.toInt() ??
                            0) >
                        0)
                      Text(
                        '+${formatVnd((dayMap[_selectedDay!]!['income'] as num?)?.toInt() ?? 0)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...widget.transactions
                .where((tx) {
                  final dateStr =
                      tx['occurredAt'] as String? ??
                      tx['occurred_at'] as String? ??
                      tx['createdAt'] as String? ??
                      tx['created_at'] as String? ??
                      '';
                  if (dateStr.isEmpty) return false;
                  try {
                    final dt = DateTime.parse(dateStr).toLocal();
                    return dt.year == _focus.year &&
                        dt.month == _focus.month &&
                        dt.day == _selectedDay;
                  } catch (_) {
                    return false;
                  }
                })
                .map((tx) {
                  return CalendarTransactionListItem(
                    tx: Map<String, dynamic>.from(tx as Map),
                  );
                }),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDayCell(
    int day,
    List<dynamic> dayTxList,
    bool isSelected,
    bool isToday,
  ) {
    if (dayTxList.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.teal.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: AppColors.teal, width: 1.5)
              : isToday
              ? Border.all(
                  color: AppColors.teal.withValues(alpha: 0.5),
                  width: 1.5,
                )
              : Border.all(color: context.palette.border, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
            ), // placeholder matching card stack size
            const SizedBox(height: 8),
            Text(
              '$day',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday ? AppColors.teal : context.palette.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    final imageTx = dayTxList.firstWhere(
      (tx) => (tx['imageUrl'] as String? ?? tx['image_url'] as String? ?? '')
          .isNotEmpty,
      orElse: () => null,
    );

    final hasMultiple = dayTxList.length > 1;

    Widget buildCardContent(dynamic tx) {
      if (tx == null) return Container(color: const Color(0xFFCBD5E1));
      final imgUrl =
          tx['imageUrl'] as String? ?? tx['image_url'] as String? ?? '';
      if (imgUrl.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: imgUrl,
          fit: BoxFit.cover,
          memCacheWidth: 200,
          errorWidget: (context, url, error) => Container(
            color: const Color(0xFFCBD5E1),
            child: const Icon(
              Icons.broken_image_outlined,
              size: 14,
              color: Colors.white70,
            ),
          ),
        );
      } else {
        final category =
            tx['category_name'] as String? ??
            tx['categoryCode'] as String? ??
            tx['category_code'] as String? ??
            'Other';
        return Container(
          color: CategoryTheme.colorOf(category).withValues(alpha: 0.85),
          child: Center(child: CategoryTheme.iconOf(category, size: 18)),
        );
      }
    }

    final bottomTx = dayTxList.length > 1 ? dayTxList[1] : null;
    final topTx = imageTx ?? dayTxList[0];

    const cardSize = 36.0;

    Widget topCard = Container(
      width: cardSize,
      height: cardSize,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: buildCardContent(topTx),
      ),
    );

    Widget stackWidget;
    if (hasMultiple) {
      Widget bottomCard = Container(
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: buildCardContent(bottomTx ?? dayTxList[0]),
        ),
      );

      stackWidget = SizedBox(
        width: cardSize + 6,
        height: cardSize + 4,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              top: 4,
              child: Transform.rotate(angle: -0.1, child: bottomCard),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: Transform.rotate(angle: 0.08, child: topCard),
            ),
          ],
        ),
      );
    } else {
      stackWidget = SizedBox(
        width: cardSize + 6,
        height: cardSize + 4,
        child: Center(child: topCard),
      );
    }

    final remainingCount = dayTxList.length - 1;

    Widget cardWithBadge = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        stackWidget,
        if (remainingCount > 0)
          Positioned(
            bottom: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                '+$remainingCount',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
            ),
          ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.teal.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isSelected
            ? Border.all(color: AppColors.teal, width: 1.5)
            : isToday
            ? Border.all(
                color: AppColors.teal.withValues(alpha: 0.5),
                width: 1.5,
              )
            : Border.all(color: context.palette.border, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          cardWithBadge,
          const SizedBox(height: 8),
          Text(
            '$day',
            style: TextStyle(
              fontSize: 11,
              fontWeight: (isToday || isSelected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: isToday ? AppColors.teal : context.palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class CalendarTransactionListItem extends StatelessWidget {
  final Map<String, dynamic> tx;
  const CalendarTransactionListItem({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
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
    final label = originalText.isNotEmpty
        ? originalText
        : (note.isNotEmpty ? note : 'Giao dịch');
    final displayTime = txTimestampIso(tx) ?? '';
    final isExpense = type.toLowerCase() == 'expense';
    final catStyle = CategoryTheme.of(category);

    String timeStr = '';
    if (displayTime.isNotEmpty) {
      final dt = parseToLocalDateTime(displayTime);
      if (dt != null) {
        timeStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(12),
        boxShadow: context.palette.softShadow,
      ),
      child: Row(
        children: [
          // Category Icon Circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: catStyle.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(child: CategoryTheme.iconOf(category, size: 20)),
          ),
          const SizedBox(width: 12),
          // Info Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: context.palette.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Amount
          Text(
            '${isExpense ? '-' : '+'}${formatVnd(amount)}',
            style: TextStyle(
              color: isExpense ? AppColors.danger : AppColors.teal,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Draft Reminder Banner ─────────────────────────────────────────────────────

class _DraftReminderBanner extends StatefulWidget {
  final int draftCount;
  final VoidCallback onTap;

  const _DraftReminderBanner({required this.draftCount, required this.onTap});

  @override
  State<_DraftReminderBanner> createState() => _DraftReminderBannerState();
}

class _DraftReminderBannerState extends State<_DraftReminderBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnim = Tween<double>(
      begin: -30,
      end: 0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _fadeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child: Opacity(opacity: _fadeAnim.value, child: child),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('⚡', style: TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bạn có ${widget.draftCount} giao dịch chưa điền tiền',
                      style: const TextStyle(
                        color: Color(0xFF92400E),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Chạm để điền nhanh →',
                      style: TextStyle(
                        color: Color(0xFFB45309),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${widget.draftCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
