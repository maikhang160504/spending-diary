import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/mock_data.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/skeleton.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _tab = 'Story';
  String? _selectedWalletId;
  final _api = ApiClient();

  // API data
  bool _loading = true;
  String? _error;
  String _userName = '';
  int _streakDays = 0;
  List<dynamic> _wallets = [];
  Map<String, dynamic> _dashboard = {};
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        _api.getMe(),
        _api.getWallets(),
      ]);
      final me = results[0] as Map<String, dynamic>;
      final wallets = results[1] as List<dynamic>;

      _userName = (me['user']?['username'] as String?) ?? 'bạn';
      _wallets = wallets;
      if (_selectedWalletId == null && wallets.isNotEmpty) {
        _selectedWalletId = wallets[0]['id'] as String?;
      }

      // Load dashboard + transactions for selected wallet
      await _loadWalletData();
    } on ApiException catch (e) {
      setState(() => _error = e.localizedMessage);
    } catch (e) {
      setState(() => _error = 'Không thể tải dữ liệu');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadWalletData() async {
    try {
      final results = await Future.wait([
        _api.getDashboard(walletId: _selectedWalletId),
        _api.getTransactions(walletId: _selectedWalletId, pageSize: 50),
      ]);
      if (!mounted) return;
      setState(() {
        _dashboard = results[0];
        final txResult = results[1];
        _transactions = (txResult['data'] as List<dynamic>?) ?? [];
      });
    } catch (_) {}
  }

  void _onWalletTap(dynamic wallet) {
    final walletType = wallet['type'] as String?;
    if (walletType == 'group') {
      context.push(AppRoutes.shareWallet);
      return;
    }
    setState(() => _selectedWalletId = wallet['id'] as String?);
    _loadWalletData();
  }

  String _formattedDate() {
    final now = DateTime.now();
    const weekdays = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];
    return '${weekdays[now.weekday % 7]}, ${now.day} tháng ${now.month.toString().padLeft(2, '0')} ${now.year}';
  }

  int get _totalIncome => ((_dashboard['totalIncome'] ?? 0) is num) ? (_dashboard['totalIncome'] as num).toInt() : 0;
  int get _totalExpense => ((_dashboard['totalExpense'] ?? 0) is num) ? (_dashboard['totalExpense'] as num).toInt() : 0;
  int get _balance => _totalIncome - _totalExpense;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadData,
              color: AppColors.teal,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader()),
                  if (_error != null)
                    SliverToBoxAdapter(child: ErrorBanner(message: _error!, onRetry: _loadData)),
                  SliverToBoxAdapter(child: _buildSegmentTabs()),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ..._buildTabContent(),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
            // Chat FAB
            Positioned(
              right: AppSpacing.xxl,
              bottom: 24,
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.chat),
                child: Container(
                  height: 48, width: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 6))],
                  ),
                  child: const Icon(Icons.smart_toy_outlined, color: AppColors.teal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTabContent() {
    if (_loading) {
      return [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: SkeletonCard(height: 80),
            ),
            childCount: 5,
          ),
        ),
      ];
    }
    if (_tab == 'Story') {
      if (_transactions.isEmpty) {
        return [
          SliverToBoxAdapter(child: EmptyState(
            emoji: '📝',
            title: 'Chưa có giao dịch nào',
            subtitle: 'Thêm giao dịch đầu tiên bằng cách chụp bill hoặc nhập tay',
          )),
        ];
      }
      return [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _TransactionStoryCard(tx: _transactions[i]),
            childCount: _transactions.length,
          ),
        ),
      ];
    }
    if (_tab == 'Gallery') {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _GalleryCard(item: MockData.galleryItems[i]),
              childCount: MockData.galleryItems.length,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 5,
              crossAxisSpacing: 5,
              childAspectRatio: 0.75,
            ),
          ),
        ),
      ];
    }
    if (_tab == 'Calendar') {
      return [SliverToBoxAdapter(child: _InlineCalendarView())];
    }
    return [];
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_formattedDate(), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)),
            const SizedBox(height: 4),
            Row(children: [
              Text('Chào ${_userName.isNotEmpty ? _userName : 'bạn'}!', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              const Text('👋', style: TextStyle(fontSize: 18)),
            ]),
          ]),
          GestureDetector(
            onTap: () => context.push(AppRoutes.streak),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(AppRadii.md)),
              child: Row(children: [
                const Text('🔥', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$_streakDays ngày', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  Text('Streak', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70, fontSize: 10)),
                ]),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        // Wallet chips — dynamic from API
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            ..._wallets.map((w) {
              final wId = w['id'] as String;
              final wName = w['name'] as String? ?? 'Ví';
              final wType = w['type'] as String? ?? 'personal';
              final memberCount = (w['member_count'] ?? 0) as int;
              final icon = wType == 'group' ? Icons.group_outlined : Icons.account_balance_wallet_outlined;
              final label = memberCount > 0 ? '$wName ($memberCount)' : wName;
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
            _WalletChip(label: 'Tạo ví', icon: Icons.add_circle_outline, isSelected: false, onTap: () {
              // TODO: Create wallet dialog
            }),
          ]),
        ),
        const SizedBox(height: 16),
        // Balance card — dynamic from API
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.lg)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.auto_awesome, color: AppColors.teal, size: 16),
              const SizedBox(width: 6),
              Text('Số dư hiện tại', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 8),
            _loading
                ? const SkeletonLine(width: 180, height: 28)
                : Text(formatVnd(_balance), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 26)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _BalanceStat(label: 'Thu nhập', value: _loading ? '...' : formatVnd(_totalIncome), color: AppColors.teal)),
              Container(width: 1, height: 28, color: AppColors.border),
              Expanded(child: _BalanceStat(label: 'Chi tiêu', value: _loading ? '...' : formatVnd(_totalExpense), color: AppColors.danger)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSegmentTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(AppRadii.lg)),
        child: Row(children: [
          _SegmentItem(label: 'Story', icon: Icons.article_outlined, isSelected: _tab == 'Story', onTap: () => setState(() => _tab = 'Story')),
          _SegmentItem(label: 'Gallery', icon: Icons.grid_view, isSelected: _tab == 'Gallery', onTap: () => setState(() => _tab = 'Gallery')),
          _SegmentItem(label: 'Calendar', icon: Icons.calendar_month, isSelected: _tab == 'Calendar', onTap: () => setState(() => _tab = 'Calendar')),
        ]),
      ),
    );
  }
}

// ─── Transaction Story Card (replaces _StoryCard with real API data) ──────────

class _TransactionStoryCard extends StatelessWidget {
  final dynamic tx;
  const _TransactionStoryCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final amount = ((tx['amount'] ?? 0) is num) ? (tx['amount'] as num).toInt() : 0;
    final type = tx['type'] as String? ?? 'expense';
    final category = tx['category_name'] as String? ?? tx['category_code'] as String? ?? 'Other';
    final note = tx['note'] as String? ?? '';
    final createdAt = tx['created_at'] as String? ?? '';
    final isExpense = type == 'expense';
    final catStyle = CategoryTheme.of(category);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: catStyle.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Center(child: Text(catStyle.emoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(note.isNotEmpty ? note : catStyle.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: catStyle.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Text('${catStyle.emoji} $category', style: TextStyle(color: catStyle.color, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 6),
              if (createdAt.isNotEmpty)
                Text(_formatTime(createdAt), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontSize: 11)),
            ]),
          ])),
          Text(
            '${isExpense ? '-' : '+'}${formatVnd(amount)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isExpense ? AppColors.danger : AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ]),
      ),
    );
  }

  String _formatTime(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
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

  const _WalletChip({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: isSelected ? AppColors.teal : Colors.white),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isSelected ? AppColors.teal : Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _BalanceStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _SegmentItem({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: isSelected ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 3))] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: isSelected ? AppColors.teal : AppColors.muted),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: isSelected ? AppColors.teal : AppColors.muted, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

class _GalleryCard extends StatelessWidget {
  final GalleryItem item;
  const _GalleryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isPositive = item.amount >= 0;
    return GestureDetector(
      onTap: () => context.push(AppRoutes.storyDetail),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Stack(fit: StackFit.expand, children: [
          Image.network(item.imageUrl, fit: BoxFit.cover,
            errorBuilder: (ctx, e, st) => Container(color: const Color(0xFFCBD5E1)),
          ),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.center,
              colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent],
            ),
          ))),
          Positioned(left: 5, top: 5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: CategoryTheme.colorOf(item.category), borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(item.categoryEmoji, style: const TextStyle(fontSize: 9)),
                const SizedBox(width: 3),
                Text(item.category, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
          Positioned(left: 5, bottom: 5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                child: Text(item.date, style: const TextStyle(color: Colors.white70, fontSize: 8)),
              ),
              const SizedBox(height: 2),
              Text(
                '${isPositive ? '+' : '-'}${formatVnd(item.amount.abs())}',
                style: TextStyle(
                  color: isPositive ? const Color(0xFF4ADE80) : Colors.white,
                  fontSize: 10, fontWeight: FontWeight.w700,
                  shadows: const [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}


// ─── Inline Calendar View ─────────────────────────────────────────────────────

class _InlineCalendarView extends StatefulWidget {
  @override
  State<_InlineCalendarView> createState() => _InlineCalendarViewState();
}

class _InlineCalendarViewState extends State<_InlineCalendarView> {
  DateTime _focus = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedDay;

  List<CalendarEntry> get _entries => MockData.calendarEntries
      .where((e) => e.month == _focus.month && e.year == _focus.year)
      .toList();

  List<CalendarEntry> get _selectedEntries => _selectedDay == null
      ? []
      : _entries.where((e) => e.day == _selectedDay).toList();

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_focus.year, _focus.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_focus.year, _focus.month);
    final startWeekday = firstDay.weekday % 7;
    final entryMap = {for (final e in _entries) e.day: e};

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () => setState(() { _focus = DateTime(_focus.year, _focus.month - 1); _selectedDay = null; }),
          ),
          Text('tháng ${_focus.month} ${_focus.year}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: () => setState(() { _focus = DateTime(_focus.year, _focus.month + 1); _selectedDay = null; }),
          ),
        ]),
        Row(children: ['S','M','T','W','T','F','S'].map((d) =>
          Expanded(child: Center(child: Text(d, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600))))).toList()),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: startWeekday + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 0.85),
          itemBuilder: (ctx, i) {
            if (i < startWeekday) return const SizedBox();
            final day = i - startWeekday + 1;
            final entry = entryMap[day];
            final isSelected = _selectedDay == day;
            final isToday = _focus.month == DateTime.now().month && _focus.year == DateTime.now().year && day == DateTime.now().day;

            return GestureDetector(
              onTap: () => setState(() => _selectedDay = _selectedDay == day ? null : day),
              child: entry != null
                  ? _StackedPhotoCell(entry: entry, isSelected: isSelected)
                  : Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.teal.withValues(alpha: 0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isToday ? Border.all(color: AppColors.teal, width: 1.5) : null,
                      ),
                      child: Center(child: Text('$day', style: TextStyle(
                        fontSize: 13,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                        color: isToday ? AppColors.teal : AppColors.textPrimary,
                      ))),
                    ),
            );
          },
        ),
        if (_selectedDay != null && _selectedEntries.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              '$_selectedDay tháng ${_focus.month} ${_focus.year}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              '-${formatVnd(_selectedEntries.fold<int>(0, (s, e) => s + e.totalAmount))}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
            ),
          ]),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedEntries.fold<int>(0, (s, e) => s + e.imageUrls.length),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.5,
            ),
            itemBuilder: (ctx, idx) {
              final allImages = _selectedEntries.expand((e) => e.imageUrls).toList();
              final entry = _selectedEntries.firstWhere(
                (e) => idx < e.imageUrls.length,
                orElse: () => _selectedEntries.last,
              );
              final url = allImages[idx];
              return GestureDetector(
                onTap: () => context.push(AppRoutes.storyDetail),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: Stack(fit: StackFit.expand, children: [
                    Image.network(url, fit: BoxFit.cover,
                      errorBuilder: (ctx, e, st) => Container(color: const Color(0xFFCBD5E1)),
                    ),
                    Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
                      ),
                    ))),
                    Positioned(left: 8, bottom: 8,
                      child: Text(
                        '-${formatVnd(entry.totalAmount)}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _StackedPhotoCell extends StatelessWidget {
  final CalendarEntry entry;
  final bool isSelected;
  const _StackedPhotoCell({required this.entry, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final photos = entry.imageUrls.take(3).toList();
    final count = photos.length;
    const tilts = [0.22, -0.15, 0.0];
    const offsets = [-9.0, 9.0, 0.0];
    const vOffsets = [-4.0, -4.0, 0.0];

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: List.generate(count, (i) {
              return Positioned(
                left: 22 + offsets[i < 3 ? i : 2] - 14,
                top: 0 + vOffsets[i < 3 ? i : 2],
                child: Transform.rotate(
                  angle: tilts[i < 3 ? i : 2],
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: const [BoxShadow(color: Color(0x28000000), blurRadius: 3, offset: Offset(0, 1))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4.5),
                      child: Image.network(
                        photos[i], fit: BoxFit.cover,
                        errorBuilder: (ctx, e, st) => Container(color: const Color(0xFFCBD5E1)),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        Positioned(
          bottom: -10, left: 0, right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.teal : Colors.black54,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('${entry.day}', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        if (entry.count > 3)
          Positioned(
            top: -4, right: -4,
            child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
              child: Center(child: Text('+${entry.count - 3}', style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700))),
            ),
          ),
      ],
    );
  }
}
