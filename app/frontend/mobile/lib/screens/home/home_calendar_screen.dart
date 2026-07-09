import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:cached_query/cached_query.dart';

import '../../routes/app_routes.dart';
import '../../services/app_queries.dart';
import '../../services/transaction_notifier.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/mimo_emotion.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/loading_indicator.dart';
import '../../widgets/skeleton.dart';

class HomeCalendarScreen extends StatefulWidget {
  const HomeCalendarScreen({super.key});

  @override
  State<HomeCalendarScreen> createState() => _HomeCalendarScreenState();
}

class _HomeCalendarScreenState extends State<HomeCalendarScreen> {
  bool _loading = true;
  String? _error;
  String _userName = '';
  int _streakDays = 0;
  List<dynamic> _wallets = [];
  Map<String, dynamic> _dashboard = {};
  List<dynamic> _transactions = [];
  String? _selectedWalletId;
  DateTime _focus = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadData();
    transactionNotifier.addListener(_onTransactionChanged);
  }

  @override
  void dispose() {
    transactionNotifier.removeListener(_onTransactionChanged);
    super.dispose();
  }

  void _onTransactionChanged() {
    if (!mounted) return;
    AppQueries.invalidateWalletData();
    _loadWalletData(forceRefetch: true);
  }

  Future<void> _loadData() async {
    final hasCache = AppQueries.wallets().state.data != null;
    setState(() {
      _loading = !hasCache;
      _error = null;
    });
    try {
      final meState = await AppQueries.me().result;
      final walletsState = await AppQueries.wallets().result;
      final me = meState.data ?? {};
      final wallets = walletsState.data ?? [];

      if (walletsState.status == QueryStatus.error &&
          walletsState.data == null) {
        setState(() => _error = 'Không thể tải dữ liệu');
        return;
      }

      _userName = (me['user']?['username'] as String?) ?? 'bạn';
      _wallets = wallets;
      AppQueries.streak().result.then((s) {
        if (mounted)
          setState(
            () =>
                _streakDays = (s.data?['currentStreak'] as num?)?.toInt() ?? 0,
          );
      });
      if (_selectedWalletId == null && wallets.isNotEmpty) {
        _selectedWalletId = wallets[0]['id'] as String?;
      }

      await _loadWalletData();
    } catch (e) {
      setState(() => _error = 'Không thể tải dữ liệu');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadWalletData({bool forceRefetch = false}) async {
    try {
      final dashF = forceRefetch
          ? AppQueries.dashboard(_selectedWalletId).refetch()
          : AppQueries.dashboard(_selectedWalletId).result;
      final txF = forceRefetch
          ? AppQueries.transactions(_selectedWalletId, pageSize: 100).refetch()
          : AppQueries.transactions(_selectedWalletId, pageSize: 100).result;
      final dash = await dashF;
      final tx = await txF;
      if (!mounted) return;
      setState(() {
        _dashboard = dash.data ?? {};
        final txData = tx.data?['data'];
        if (txData is Map<String, dynamic>) {
          _transactions = (txData['items'] as List<dynamic>?) ?? [];
        } else if (txData is List<dynamic>) {
          _transactions = txData;
        } else {
          _transactions = [];
        }
      });
    } catch (_) {}
  }

  void _onWalletTap(dynamic wallet) {
    final walletType = wallet['type'] as String?;
    if (walletType == 'group') {
      context.push(
        AppRoutes.shareWallet,
        extra: {'walletId': wallet['id'] as String? ?? ''},
      );
      return;
    }
    setState(() => _selectedWalletId = wallet['id'] as String?);
    _loadWalletData();
  }

  String _formattedDate() {
    final now = DateTime.now();
    const weekdays = [
      'Chủ Nhật',
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
    ];
    return '${weekdays[now.weekday % 7]}, ${now.day} tháng ${now.month.toString().padLeft(2, '0')} ${now.year}';
  }

  int get _totalIncome {
    final totals = _dashboard['totals'] as Map<String, dynamic>?;
    final v = totals?['income'] ?? _dashboard['totalIncome'] ?? 0;
    return v is num ? v.toInt() : 0;
  }

  int get _totalExpense {
    final totals = _dashboard['totals'] as Map<String, dynamic>?;
    final v = totals?['expense'] ?? _dashboard['totalExpense'] ?? 0;
    return v is num ? v.toInt() : 0;
  }

  int get _balance => _totalIncome - _totalExpense;

  Map<int, Map<String, dynamic>> get _dayMap {
    final result = <int, Map<String, dynamic>>{};
    final byDay = (_dashboard['byDay'] as List<dynamic>?) ?? [];
    for (final entry in byDay) {
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

    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              _SegmentTabs(
                selected: 'Calendar',
                onStory: () => context.pop(),
                onGallery: () => context.push(AppRoutes.homeGallery),
                onCalendar: () {},
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ErrorBanner(message: _error!, onRetry: _loadData),
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: LoadingIndicator(),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                  ),
                  child: Column(
                    children: [
                      // Calendar controls and grid container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.palette.card,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          boxShadow: context.palette.softShadow,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() {
                                    _focus = DateTime(
                                      _focus.year,
                                      _focus.month - 1,
                                    );
                                    _selectedDay = null;
                                    _loadWalletData();
                                  }),
                                ),
                                Text(
                                  'tháng ${_focus.month} ${_focus.year}',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    size: 20,
                                  ),
                                  onPressed: () => setState(() {
                                    _focus = DateTime(
                                      _focus.year,
                                      _focus.month + 1,
                                    );
                                    _selectedDay = null;
                                    _loadWalletData();
                                  }),
                                ),
                              ],
                            ),
                            Row(
                              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                                  .map(
                                    (d) => Expanded(
                                      child: Center(
                                        child: Text(
                                          d,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
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
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
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

                                final dayTxList = _transactions.where((tx) {
                                  final dateStr =
                                      tx['occurredAt'] as String? ??
                                      tx['occurred_at'] as String? ??
                                      tx['createdAt'] as String? ??
                                      tx['created_at'] as String? ??
                                      '';
                                  if (dateStr.isEmpty) return false;
                                  try {
                                    final dt = DateTime.parse(
                                      dateStr,
                                    ).toLocal();
                                    return dt.year == _focus.year &&
                                        dt.month == _focus.month &&
                                        dt.day == day;
                                  } catch (_) {
                                    return false;
                                  }
                                }).toList();

                                return GestureDetector(
                                  onTap: () => setState(
                                    () => _selectedDay = _selectedDay == day
                                        ? null
                                        : day,
                                  ),
                                  child: _buildDayCell(
                                    day,
                                    dayTxList,
                                    isSelected,
                                    isToday,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      if (_selectedDay != null &&
                          dayMap[_selectedDay!] != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$_selectedDay tháng ${_focus.month} ${_focus.year}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '-${formatVnd((dayMap[_selectedDay!]!['expense'] as num?)?.toInt() ?? 0)}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                if (((dayMap[_selectedDay!]!['income'] as num?)
                                            ?.toInt() ??
                                        0) >
                                    0)
                                  Text(
                                    '+${formatVnd((dayMap[_selectedDay!]!['income'] as num?)?.toInt() ?? 0)}',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: AppColors.teal,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ..._transactions
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
                              final dayNavIds = _transactions
                                  .where((t) {
                                    final ds =
                                        t['occurredAt'] as String? ??
                                        t['occurred_at'] as String? ??
                                        t['createdAt'] as String? ??
                                        t['created_at'] as String? ??
                                        '';
                                    if (ds.isEmpty) return false;
                                    try {
                                      final d = DateTime.parse(ds).toLocal();
                                      return d.year == _focus.year &&
                                          d.month == _focus.month &&
                                          d.day == _selectedDay;
                                    } catch (_) {
                                      return false;
                                    }
                                  })
                                  .map<String>(
                                    (t) =>
                                        (t['storyId'] as String?) ??
                                        (t['story_id'] as String?) ??
                                        (t['id'] as String?) ??
                                        '',
                                  )
                                  .where((e) => e.isNotEmpty)
                                  .toList();
                              return _TransactionStoryCard(
                                tx: tx,
                                allStoryIds: dayNavIds,
                              );
                            }),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.xl),
          bottomRight: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formattedDate(),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Chào ${_userName.isNotEmpty ? _userName : 'bạn'}!',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 4),
                      const Text('👋', style: TextStyle(fontSize: 18)),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.push(AppRoutes.streak),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_streakDays ngày',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            'Streak',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Wallet chips — dynamic from API
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ..._wallets.map((w) {
                  final wId = w['id'] as String;
                  final wName = w['name'] as String? ?? 'Ví';
                  final wType = w['type'] as String? ?? 'personal';
                  final memberCount = (w['member_count'] ?? 0) as int;
                  final icon = wType == 'group'
                      ? Icons.group_outlined
                      : Icons.account_balance_wallet_outlined;
                  final label = memberCount > 0
                      ? '$wName ($memberCount)'
                      : wName;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _WalletChip(
                      label: label,
                      icon: icon,
                      isSelected: _selectedWalletId == wId,
                      onTap: () => _onWalletTap(w),
                    ),
                  );
                }),
                _WalletChip(
                  label: 'Tạo ví',
                  icon: Icons.add_circle_outline,
                  isSelected: false,
                  onTap: () {
                    // TODO: Create wallet dialog
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Balance card — dynamic from API
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.teal,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Số dư hiện tại',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _loading
                    ? const SkeletonLine(width: 180, height: 28)
                    : Text(
                        formatVnd(_balance),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 26,
                        ),
                      ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _BalanceStat(
                        label: 'Thu nhập',
                        value: _loading ? '...' : formatVnd(_totalIncome),
                        color: AppColors.teal,
                      ),
                    ),
                    Container(width: 1, height: 28, color: AppColors.border),
                    Expanded(
                      child: _BalanceStat(
                        label: 'Chi tiêu',
                        value: _loading ? '...' : formatVnd(_totalExpense),
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
              : Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
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
                color: isToday ? AppColors.teal : AppColors.textPrimary,
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
            : Border.all(color: const Color(0xFFE2E8F0), width: 0.5),
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
              color: isToday ? AppColors.teal : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Transaction Story Card (matching HomeScreen inline calendar list) ──────

class _TransactionStoryCard extends StatelessWidget {
  final dynamic tx;
  final List<String>? allStoryIds;
  const _TransactionStoryCard({required this.tx, this.allStoryIds});

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
    final caption = originalText.isNotEmpty ? originalText : note;
    final createdAt =
        tx['createdAt'] as String? ?? tx['created_at'] as String? ?? '';
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
        tx['userAvatar'] as String? ?? tx['user_avatar'] as String?;

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
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: context.palette.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
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
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: catStyle.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                catStyle.label,
                                style: TextStyle(
                                  color: catStyle.color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (createdAt.isNotEmpty)
                              Text(
                                _formatTime(createdAt),
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
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  caption,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ),
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              const SizedBox(height: 10),
              ClipRRect(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  memCacheWidth: 1080,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
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
            Divider(height: 1, color: context.palette.divider),
            if (aiComment != null && aiComment.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/MiMo/emotions/$mascotMood.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Center(
                            child: Text('😎', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: context.palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mimo AI',
                              style: TextStyle(
                                color: AppColors.teal,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              aiComment,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: context.palette.textPrimary,
                                    height: 1.4,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  String _formatTime(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} ${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _WalletChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _WalletChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.teal : Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isSelected ? AppColors.teal : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BalanceStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.palette.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentTabs extends StatelessWidget {
  final String selected;
  final VoidCallback onStory;
  final VoidCallback onGallery;
  final VoidCallback onCalendar;

  const _SegmentTabs({
    required this.selected,
    required this.onStory,
    required this.onGallery,
    required this.onCalendar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.palette.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            _SegItem(
              label: 'Story',
              icon: Icons.article_outlined,
              isSelected: selected == 'Story',
              onTap: onStory,
            ),
            _SegItem(
              label: 'Gallery',
              icon: Icons.grid_view,
              isSelected: selected == 'Gallery',
              onTap: onGallery,
            ),
            _SegItem(
              label: 'Calendar',
              icon: Icons.calendar_month,
              isSelected: selected == 'Calendar',
              onTap: onCalendar,
            ),
          ],
        ),
      ),
    );
  }
}

class _SegItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: isSelected ? AppShadows.soft : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppColors.teal : AppColors.muted,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected ? AppColors.teal : AppColors.muted,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
