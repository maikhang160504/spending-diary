import 'package:cached_network_image/cached_network_image.dart';
import 'package:cached_query/cached_query.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/app_queries.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/mimo_emotion.dart';
import '../../theme/categories.dart';
import '../../services/streak_celebration.dart';
import '../../services/transaction_notifier.dart';
import '../../utils/formatters.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/skeleton.dart';
import '../wallet/create_wallet_screen.dart';
import '../../widgets/premium_upsell_bottom_sheet.dart';
import '../../widgets/mimo_snackbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _tab = 'Story';
  String? _selectedWalletId;
  String? _currentUserId;

  // API data
  bool _loading = true;
  String? _error;
  String _userName = '';
  String? _userAvatar;
  int _streakDays = 0;
  List<dynamic> _wallets = [];
  Map<String, dynamic> _dashboard = {};
  List<dynamic> _transactions = [];
  List<dynamic> _stories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    transactionNotifier.addListener(_onTransactionChanged);
  }

  void _onTransactionChanged() {
    if (!mounted) return;
    // Đánh dấu cache liên quan là stale rồi tải lại để đồng bộ.
    AppQueries.invalidateWalletData();
    _loadWalletData(forceRefetch: true);
  }

  @override
  void dispose() {
    transactionNotifier.removeListener(_onTransactionChanged);
    super.dispose();
  }

  Future<void> _loadData() async {
    // Nếu đã có cache thì không hiện skeleton (tránh chớp khi quay lại màn hình).
    final hasCache = AppQueries.wallets().state.data != null;
    setState(() {
      _loading = !hasCache;
      _error = null;
    });
    try {
      final meState = await AppQueries.me().result;
      final walletsState = await AppQueries.wallets().result;
      final me = meState.data ?? {};
      final walletsList = List<dynamic>.from(walletsState.data ?? []);
      walletsList.sort((a, b) {
        final aType = a['type'] as String? ?? 'personal';
        final bType = b['type'] as String? ?? 'personal';
        if (aType == 'personal' && bType != 'personal') return -1;
        if (aType != 'personal' && bType == 'personal') return 1;
        return 0;
      });

      final failed =
          walletsState.status == QueryStatus.error && walletsState.data == null;
      if (failed) {
        if (mounted) setState(() => _error = 'Không thể tải dữ liệu');
        return;
      }

      _userName = (me['user']?['username'] as String?) ?? 'bạn';
      _userAvatar =
          me['user']?['avatarUrl'] as String? ??
          me['user']?['avatar_url'] as String?;
      _currentUserId = me['user']?['id'] as String?;
      _wallets = walletsList;
      AppQueries.streak().refetch().then((s) {
        if (mounted) {
          setState(
            () =>
                _streakDays = (s.data?['currentStreak'] as num?)?.toInt() ?? 0,
          );
        }
      });
      _selectedWalletId ??= ApiClient.lastSelectedWalletId;
      if (_selectedWalletId == null && walletsList.isNotEmpty) {
        final lastSelected = ApiClient.lastSelectedWalletId;
        final lastExists = lastSelected != null && walletsList.any((w) => w['id'] == lastSelected);
        if (lastExists) {
          _selectedWalletId = lastSelected;
        } else {
          final personalWallets = walletsList.where((w) => w['type'] != 'group').toList();
          _selectedWalletId = personalWallets.isNotEmpty 
              ? personalWallets[0]['id'] as String? 
              : walletsList[0]['id'] as String?;
        }
      }
      ApiClient.lastSelectedWalletId = _selectedWalletId;

      // Load dashboard + transactions for selected wallet
      await _loadWalletData(forceRefetch: true);
      if (mounted) {
        // ignore: unawaited_futures
        StreakCelebration.instance.checkBrokenOnLaunch(context);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Không thể tải dữ liệu');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadWalletData({bool forceRefetch = false}) async {
    try {
      // Chạy song song nhưng vẫn lấy kết quả có kiểu rõ ràng.
      final dashF = forceRefetch
          ? AppQueries.dashboard(_selectedWalletId).refetch()
          : AppQueries.dashboard(_selectedWalletId).result;
      final txF = forceRefetch
          ? AppQueries.transactions(_selectedWalletId).refetch()
          : AppQueries.transactions(_selectedWalletId).result;
      final storyF = forceRefetch
          ? AppQueries.stories(_selectedWalletId).refetch()
          : AppQueries.stories(_selectedWalletId).result;
      final dash = await dashF;
      final tx = await txF;
      final story = await storyF;
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
        _transactions.sort((a, b) => compareByTimestampDesc(
          Map<String, dynamic>.from(a as Map),
          Map<String, dynamic>.from(b as Map),
        ));
        _stories = story.data ?? [];
        _stories.sort((a, b) => compareStoryByTimestampDesc(
          Map<String, dynamic>.from(a as Map),
          Map<String, dynamic>.from(b as Map),
        ));
      });
    } catch (_) {}
  }

  void _onWalletTap(dynamic wallet) async {
    final walletType = wallet['type'] as String?;
    if (walletType == 'group') {
      await context.push(
        AppRoutes.shareWallet,
        extra: {'walletId': wallet['id'] as String? ?? ''},
      );
      _loadData();
      return;
    }
    final newId = wallet['id'] as String?;
    if (_selectedWalletId == newId) return;

    final hasCache = AppQueries.dashboard(newId).state.data != null;
    
    setState(() {
      _selectedWalletId = newId;
      if (!hasCache) {
        _loading = true;
        _dashboard = {};
        _transactions = [];
        _stories = [];
      }
    });
    ApiClient.lastSelectedWalletId = _selectedWalletId;
    
    await _loadWalletData();
    if (mounted && !hasCache) {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteWallet(dynamic wallet) async {
    final wId = wallet['id'] as String;
    final wName = wallet['name'] as String? ?? 'Ví';

    // Check ownership
    final memberRole =
        wallet['memberRole'] as String? ?? wallet['member_role'] as String?;
    final ownerId =
        wallet['ownerId'] as String? ?? wallet['owner_id'] as String?;
    final isOwner =
        memberRole == 'owner' || (ownerId != null && ownerId == _currentUserId);

    if (!isOwner) {
      MimoSnackBar.showWarning(
        context,
        message: 'Bạn không thể xóa ví này vì bạn không phải chủ sở hữu.',
        emotion: 'Alert',
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = ctx.palette;
        return AlertDialog(
          backgroundColor: palette.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          title: Text(
            'Xóa ví',
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa ví "$wName" không?',
            style: TextStyle(color: palette.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Hủy',
                style: TextStyle(
                  color: palette.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text(
                'Xóa',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final api = ApiClient();
      await api.deleteWallet(wId);
      if (!mounted) return;

      MimoSnackBar.showSuccess(
        context,
        message: 'Đã xóa ví "$wName" thành công ✓',
        emotion: 'Success',
      );

      AppQueries.invalidateWalletData();
      if (_selectedWalletId == wId) {
        _selectedWalletId = null;
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        MimoSnackBar.showError(
          context,
          message: 'Không thể xóa ví: ${e.toString()}',
          emotion: 'Sad',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onCreateWallet() async {
    final result = await CreateWalletScreen.show(context);
    if (result != null && mounted) {
      AppQueries.invalidateWalletData();
      await _loadData();
      if (mounted) {
        if (result['type'] == 'group') {
           _onWalletTap(result);
           return;
        }
        setState(() {
          _selectedWalletId = result['id'] as String?;
        });
        ApiClient.lastSelectedWalletId = _selectedWalletId;
        _loadWalletData();
      }
    }
  }

  Future<void> _joinWalletByCode() async {
    final codeCtrl = TextEditingController();
    bool loading = false;
    String? errorMsg;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final palette = ctx.palette;
          return AlertDialog(
            backgroundColor: palette.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            title: Text(
              'Nhập mã mời ví',
              style: TextStyle(
                color: palette.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nhập mã mời gồm 6 ký tự để tham gia ví chung.',
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeCtrl,
                  maxLength: 6,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    color: palette.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'VD: A1B2C3',
                    counterText: '',
                    errorText: errorMsg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: loading ? null : () => Navigator.pop(ctx),
                child: Text(
                  'Hủy',
                  style: TextStyle(
                    color: palette.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton(
                onPressed: loading
                    ? null
                    : () async {
                        final code = codeCtrl.text.trim();
                        if (code.length != 6) {
                          setDialogState(
                            () => errorMsg = 'Mã mời phải đúng 6 ký tự.',
                          );
                          return;
                        }
                        setDialogState(() {
                          loading = true;
                          errorMsg = null;
                        });
                        try {
                          final api = ApiClient();
                          final newWallet = await api.joinWalletByCode(code);
                          if (!mounted) return;

                          AppQueries.invalidateWalletData();
                          await _loadData();

                          if (mounted && ctx.mounted) {
                            Navigator.pop(ctx);
                            MimoSnackBar.showSuccess(
                              context,
                              message: 'Đã tham gia ví "${newWallet['name']}" thành công!',
                            );
                            if (newWallet['type'] == 'group') {
                              _onWalletTap(newWallet);
                            } else {
                              setState(() {
                                _selectedWalletId = newWallet['id'] as String?;
                              });
                              ApiClient.lastSelectedWalletId = _selectedWalletId;
                              _loadWalletData();
                            }
                          }
                        } on ApiException catch (e) {
                          if (e.message.contains('PREMIUM_REQUIRED_WALLET_LIMIT')) {
                            if (mounted) {
                              Navigator.pop(ctx);
                              showPremiumUpsellSheet(context);
                            }
                          } else {
                            setDialogState(() {
                              loading = false;
                              errorMsg = e.localizedMessage;
                            });
                          }
                        } catch (_) {
                          setDialogState(() {
                            loading = false;
                            errorMsg = 'Có lỗi xảy ra, vui lòng thử lại.';
                          });
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                ),
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Tham gia',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          );
        },
      ),
    );
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

  List<dynamic> get _draftTransactions =>
      _transactions.where((t) => t['isDraft'] == true).toList();

  @override
  Widget build(BuildContext context) {
    final selectedWallet = _wallets.cast<dynamic>().firstWhere(
      (w) => w is Map && w['id'] == _selectedWalletId,
      orElse: () => null,
    );
    final activeWalletColor = parseWalletColorHex(selectedWallet?['color'] as String?);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (selectedWalletColorNotifier.value != activeWalletColor) {
        selectedWalletColorNotifier.value = activeWalletColor;
      }
    });
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscapeMobile = constraints.maxWidth > constraints.maxHeight && constraints.maxHeight < 600;
            final isTabletLandscape = constraints.maxWidth >= 768 && constraints.maxWidth > constraints.maxHeight;
            final isTabletPortrait = constraints.maxWidth >= 600 && constraints.maxWidth <= constraints.maxHeight;
            final isWide = isTabletLandscape || isLandscapeMobile;

            final headerDelegate = _HomeHeaderDelegate(
              userName: _userName,
              formattedDate: _formattedDate(),
              streakDays: _streakDays,
              wallets: _wallets,
              selectedWalletId: _selectedWalletId,
              loading: _loading,
              balance: _balance,
              income: _totalIncome,
              expense: _totalExpense,
              isGroupWallet: _wallets.any((w) => w['id'] == _selectedWalletId && w['type'] == 'group'),
              tab: _tab,
              onWalletTap: _onWalletTap,
              onWalletLongPress: _deleteWallet,
              onTabChanged: (t) => setState(() => _tab = t),
              onStreakTap: () => context.push(AppRoutes.streak),
              onCreateWallet: _onCreateWallet,
              onJoinWallet: _joinWalletByCode,
              isCompact: isLandscapeMobile,
            );

            Widget mainContent;
            if (isWide) {
              mainContent = Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Bên trái: header info (cố định, không scroll vì header compact)
                  SizedBox(
                    width: isLandscapeMobile ? 240 : constraints.maxWidth * 0.38,
                    child: RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.teal,
                      child: CustomScrollView(
                        slivers: [
                          SliverPersistentHeader(
                            pinned: true,
                            delegate: headerDelegate,
                          ),
                          if (_error != null)
                            SliverToBoxAdapter(
                              child: ErrorBanner(message: _error!, onRetry: _loadData),
                            ),
                          const SliverToBoxAdapter(child: SizedBox(height: 20)),
                        ],
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                  // Bên phải: nội dung giao dịch + segment tabs
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        // Segment tab nằm ở đầu bên phải trong landscape
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: context.palette.surfaceAlt,
                                borderRadius: BorderRadius.circular(AppRadii.lg),
                              ),
                              child: Row(
                                children: [
                                  _SegmentItem(
                                    label: 'Story',
                                    icon: Icons.article_outlined,
                                    isSelected: _tab == 'Story',
                                    onTap: () => setState(() => _tab = 'Story'),
                                  ),
                                  _SegmentItem(
                                    label: 'Gallery',
                                    icon: Icons.grid_view,
                                    isSelected: _tab == 'Gallery',
                                    onTap: () => setState(() => _tab = 'Gallery'),
                                  ),
                                  _SegmentItem(
                                    label: 'Calendar',
                                    icon: Icons.calendar_month,
                                    isSelected: _tab == 'Calendar',
                                    onTap: () => setState(() => _tab = 'Calendar'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (_draftTransactions.isNotEmpty)
                          SliverToBoxAdapter(
                            child: _DraftReminderBanner(
                              draftCount: _draftTransactions.length,
                              onTap: () => _showDraftListSheet(context),
                            ),
                          ),
                        ..._buildTabContent(),
                        const SliverToBoxAdapter(child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              // Portrait phone/tablet: single-column scrollable layout
              // On tablet portrait, add horizontal padding to constrain content width
              final double sidepad = isTabletPortrait
                  ? ((constraints.maxWidth - 600) / 2).clamp(0.0, double.infinity)
                  : 0.0;
              mainContent = RefreshIndicator(
                onRefresh: _loadData,
                color: AppColors.teal,
                child: CustomScrollView(
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: headerDelegate,
                    ),
                    if (_error != null)
                      SliverToBoxAdapter(
                        child: ErrorBanner(message: _error!, onRetry: _loadData),
                      ),
                    SliverToBoxAdapter(child: SizedBox(height: isTabletPortrait ? 20 : 16)),
                    if (_draftTransactions.isNotEmpty)
                      SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: sidepad),
                        sliver: SliverToBoxAdapter(
                          child: _DraftReminderBanner(
                            draftCount: _draftTransactions.length,
                            onTap: () => _showDraftListSheet(context),
                          ),
                        ),
                      ),
                    if (sidepad > 0)
                      ..._buildTabContent().map((sliver) => SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: sidepad),
                        sliver: sliver,
                      ))
                    else
                      ..._buildTabContent(),
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              );
            }

            return Stack(
              children: [
                mainContent,
                // Chat FAB
                if (!isWide)
                  Positioned(
                    right: AppSpacing.xxl,
                    bottom: 24,
                  child: GestureDetector(
                    onTap: () => context.push(
                      AppRoutes.chat,
                      extra: {'walletId': _selectedWalletId},
                    ),
                    child: Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        gradient: activeWalletColor == AppColors.teal
                            ? AppGradients.teal
                            : LinearGradient(
                                colors: [
                                  activeWalletColor,
                                  HSLColor.fromColor(activeWalletColor)
                                      .withLightness((HSLColor.fromColor(activeWalletColor).lightness - 0.12).clamp(0.0, 0.9))
                                      .toColor(),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: activeWalletColor.withValues(alpha: 0.35),
                            blurRadius: 12,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildTabContent() {
    if (_loading) {
      if (_tab == 'Gallery') {
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => const Padding(
                  padding: EdgeInsets.all(4),
                  child: SkeletonCard(height: 100),
                ),
                childCount: 9,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                childAspectRatio: 1,
              ),
            ),
          ),
        ];
      }
      if (_tab == 'Calendar') {
        return [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(7, (i) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: SkeletonCard(width: 40, height: 60),
                    )),
                  ),
                  const SizedBox(height: 16),
                  const SkeletonCard(height: 80),
                ],
              ),
            ),
          ),
        ];
      }
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
          SliverToBoxAdapter(
            child: EmptyState(
              emoji: '📝',
              title: 'Chưa có giao dịch nào',
              subtitle:
                  'Thêm giao dịch đầu tiên bằng cách chụp bill hoặc nhập tay',
            ),
          ),
        ];
      }
      final navIds = _transactions
          .map<String>(
            (t) =>
                (t['storyId'] as String?) ??
                (t['story_id'] as String?) ??
                (t['id'] as String?) ??
                '',
          )
          .where((e) => e.isNotEmpty)
          .toList();
      return [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _TransactionStoryCard(
              tx: _transactions[i],
              allStoryIds: navIds,
              fallbackUserAvatar: _userAvatar,
            ),
            childCount: _transactions.length,
          ),
        ),
      ];
    }
    if (_tab == 'Gallery') {
      final galleryStories = _stories
          .where(
            (s) =>
                (s['cover_image_url'] as String? ??
                        s['coverImageUrl'] as String? ??
                        '')
                    .isNotEmpty,
          )
          .toList()
        ..sort((a, b) => compareStoryByTimestampDesc(
          Map<String, dynamic>.from(a as Map),
          Map<String, dynamic>.from(b as Map),
        ));
      if (galleryStories.isEmpty) {
        return [
          SliverToBoxAdapter(
            child: EmptyState(
              emoji: '📸',
              title: 'Chưa có story nào',
              subtitle: 'Chụp bill để lưu ảnh vào gallery',
            ),
          ),
        ];
      }
      final galleryIds = galleryStories
          .map((s) => (s['id'] as String?) ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          sliver: Builder(
            builder: (context) {
              final screenWidth = MediaQuery.of(context).size.width;
              final columns = screenWidth > 900 ? 5 : (screenWidth > 600 ? 4 : 3);
              return SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _StoryGalleryCard(
                    story: galleryStories[i] as Map<String, dynamic>,
                    allStoryIds: galleryIds,
                    initialIndex: i,
                  ),
                  childCount: galleryStories.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  childAspectRatio: 1, // ô vuông 1:1 đồng nhất với ảnh story
                ),
              );
            }
          ),
        ),
      ];
    }
    if (_tab == 'Calendar') {
      final byDay = (_dashboard['byDay'] as List<dynamic>?) ?? [];
      return [
        SliverToBoxAdapter(
          child: _InlineCalendarView(byDay: byDay, transactions: _transactions),
        ),
      ];
    }
    return [];
  }

  void _showDraftListSheet(BuildContext context) {
    final drafts = _draftTransactions;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _DraftListSheet(
          drafts: drafts,
          onFillAmount: (txId, label) {
            _openQuickFillForDraft(context, txId, label);
          },
        );
      },
    );
  }

  void _openQuickFillForDraft(BuildContext context, String txId, String label) {
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [50000, 100000, 200000, 500000].map((val) {
                    return InkWell(
                      onTap: () => amountCtrl.text = val.toString(),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vui lòng nhập số tiền hợp lệ (phải lớn hơn 0)'),
                                ),
                              );
                              return;
                            }
                            if (parsed > 100000000000) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Số tiền tối đa 100 tỷ đồng')),
                              );
                              return;
                            }
                            setSheetState(() => saving = true);
                            try {
                              final api = ApiClient();
                              await api.updateTransaction(txId, {
                                'amount': parsed,
                                'isDraft': false,
                                'processingStatus': 'completed',
                              });
                              notifyTransactionChanged();
                              if (ctx.mounted) ctx.pop();
                            } catch (_) {
                              setSheetState(() => saving = false);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Không thể cập nhật giao dịch',
                                    ),
                                  ),
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
      ),
    );
  }
}

// ─── Collapsible Home Header (pinned SliverPersistentHeader) ──────────────────
//
// GIỮ khi cuộn: lời chào "Chào [tên] 👋" + nút streak + segment tabs (ghim đáy).
// ẨN dần khi cuộn (fade theo t): ngày, dải ví, thẻ số dư.
class _HomeHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String userName;
  final String formattedDate;
  final int streakDays;
  final List<dynamic> wallets;
  final String? selectedWalletId;
  final bool loading;
  final int balance;
  final int income;
  final int expense;
  final bool isGroupWallet;
  final String tab;
  final void Function(dynamic wallet) onWalletTap;
  final void Function(dynamic wallet)? onWalletLongPress;
  final ValueChanged<String> onTabChanged;
  final VoidCallback onStreakTap;
  final VoidCallback onCreateWallet;
  final VoidCallback onJoinWallet;
  /// Chế độ compact: dùng khi màn hình ngang (landscape mobile) để giảm maxExtent
  final bool isCompact;

  _HomeHeaderDelegate({
    required this.userName,
    required this.formattedDate,
    required this.streakDays,
    required this.wallets,
    required this.selectedWalletId,
    required this.loading,
    required this.balance,
    required this.income,
    required this.expense,
    this.isGroupWallet = false,
    required this.tab,
    required this.onWalletTap,
    this.onWalletLongPress,
    required this.onTabChanged,
    required this.onStreakTap,
    required this.onCreateWallet,
    required this.onJoinWallet,
    this.isCompact = false,
  });

  // Khi isCompact (landscape mobile): ẩn dải ví và segment tab trong header
  // segment tab sẽ được render ở cột phải thay vào đó.
  double get _segmentH => isCompact ? 0 : 64;
  static const double _greetingTop = 18;
  static const double _fadeTop = 62;

  @override
  double get minExtent => isCompact ? 68 : 70 + 64;
  @override
  double get maxExtent => isCompact ? 310 : 298 + 64;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final maxShrink = maxExtent - minExtent;
    final t = maxShrink <= 0
        ? 1.0
        : (1 - (shrinkOffset / maxShrink)).clamp(0.0, 1.0);
    final theme = Theme.of(context);

    // Resolve selected wallet color & gentle gradient
    final selectedWallet = wallets.cast<dynamic>().firstWhere(
      (w) => w is Map && w['id'] == selectedWalletId,
      orElse: () => null,
    );
    final walletColorHex = (selectedWallet?['color'] as String? ?? '#0D9488').replaceAll('#', '');
    Color walletColor;
    try {
      walletColor = Color(int.parse(walletColorHex.length == 6 ? 'FF$walletColorHex' : walletColorHex, radix: 16));
    } catch (_) {
      walletColor = const Color(0xFF0D9488);
    }
    final hsl = HSLColor.fromColor(walletColor);
    final lightColor = hsl
        .withSaturation((hsl.saturation * 0.72).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + 0.18).clamp(0.0, 0.92))
        .toColor();

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Nền trắng (để dải tabs ở đáy luôn trắng)
          Positioned.fill(child: ColoredBox(color: context.palette.bg)),

          // Nền gradient (bo góc dưới) — phủ từ trên xuống ngay trên dải tabs
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: _segmentH,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [walletColor, lightColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(AppRadii.xl),
                  bottomRight: Radius.circular(AppRadii.xl),
                ),
              ),
            ),
          ),

          // GIỮ: lời chào + streak (luôn hiển thị)
          Positioned(
            top: _greetingTop,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'Chào ${userName.isNotEmpty ? userName : 'bạn'}!',
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.waving_hand_rounded,
                        color: Color(0xFFFFD600),
                        size: 20,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onStreakTap,
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFFF9100),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$streakDays ngày',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Streak',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                                fontSize: 10,
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
          ),

          // ẨN dần: ngày + ví + thẻ số dư (fade theo t, không nhận chạm khi mờ)
          Positioned(
            top: _fadeTop,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: t < 0.05,
              child: Opacity(
                opacity: t,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formattedDate,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 38,
                        child: ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return const LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [Colors.black, Colors.black, Colors.transparent],
                              stops: [0.0, 0.92, 1.0],
                            ).createShader(bounds);
                          },
                          blendMode: BlendMode.dstIn,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ...wallets.map((w) {
                                  final wId = w['id'] as String;
                                  final wName = w['name'] as String? ?? 'Ví';
                                  final wType =
                                      w['type'] as String? ?? 'personal';
                                  final memberCount =
                                      (w['member_count'] ?? 0) as int;
                                  final icon = wType == 'group'
                                      ? Icons.group_outlined
                                      : Icons.account_balance_wallet_outlined;
                                  final wEmoji = w['icon'] as String?;
                                  final wColorHex = (w['color'] as String? ?? '#0D9488').replaceAll('#', '');
                                  Color chipAccent;
                                  try {
                                    chipAccent = Color(int.parse(wColorHex.length == 6 ? 'FF$wColorHex' : wColorHex, radix: 16));
                                  } catch (_) {
                                    chipAccent = AppColors.teal;
                                  }
                                  final label = memberCount > 0
                                      ? '$wName ($memberCount)'
                                      : wName;
                                  final unseenCount =
                                      (w['unseenCount'] ?? 0) as int;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: _WalletChip(
                                      label: label,
                                      icon: icon,
                                      emoji: wEmoji,
                                      accentColor: chipAccent,
                                      isSelected: selectedWalletId == wId,
                                      unseenCount: unseenCount,
                                      onTap: () => onWalletTap(w),
                                      onLongPress: onWalletLongPress != null
                                          ? () => onWalletLongPress!(w)
                                          : null,
                                    ),
                                  );
                                }),
                                _WalletChip(
                                  label: 'Tạo ví',
                                  icon: Icons.add_circle_outline,
                                  isSelected: false,
                                  onTap: onCreateWallet,
                                ),
                                const SizedBox(width: 8),
                                _WalletChip(
                                  label: 'Nhập mã mời',
                                  icon: Icons.vpn_key_outlined,
                                  isSelected: false,
                                  onTap: onJoinWallet,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.palette.card,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          boxShadow: context.palette.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: walletColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isGroupWallet ? 'Còn lại' : 'Số dư hiện tại',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: context.palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            loading
                                ? const SkeletonLine(width: 180, height: 28)
                                : Text(
                                    formatVnd(balance),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: balance < 0 ? FontWeight.w800 : FontWeight.w700,
                                      fontSize: balance < 0 ? 28 : 26,
                                      color: balance < 0 ? AppColors.danger : theme.textTheme.titleLarge?.color,
                                    ),
                                  ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _BalanceStat(
                                    label: isGroupWallet ? 'Quỹ nhóm' : 'Thu nhập',
                                    value: loading ? '...' : formatVnd(income),
                                    color: walletColor,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 28,
                                  color: context.palette.border,
                                ),
                                Expanded(
                                  child: _BalanceStat(
                                    label: isGroupWallet ? 'Đã chi' : 'Chi tiêu',
                                    value: loading ? '...' : formatVnd(expense),
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
                ),
              ),
            ),
          ),

          // GIỮ: segment tabs (ghim đáy, luôn hiển thị — ẩn khi compact vì đã render ở cột phải)
          if (!isCompact)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 64,
            child: Container(
              color: context.palette.bg,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                8,
                AppSpacing.xxl,
                12,
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Row(
                  children: [
                    _SegmentItem(
                      label: 'Story',
                      icon: Icons.article_outlined,
                      isSelected: tab == 'Story',
                      onTap: () => onTabChanged('Story'),
                    ),
                    _SegmentItem(
                      label: 'Gallery',
                      icon: Icons.grid_view,
                      isSelected: tab == 'Gallery',
                      onTap: () => onTabChanged('Gallery'),
                    ),
                    _SegmentItem(
                      label: 'Calendar',
                      icon: Icons.calendar_month,
                      isSelected: tab == 'Calendar',
                      onTap: () => onTabChanged('Calendar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HomeHeaderDelegate old) {
    return old.userName != userName ||
        old.formattedDate != formattedDate ||
        old.streakDays != streakDays ||
        old.wallets.length != wallets.length ||
        old.selectedWalletId != selectedWalletId ||
        old.loading != loading ||
        old.balance != balance ||
        old.income != income ||
        old.expense != expense ||
        old.tab != tab ||
        old.onJoinWallet != onJoinWallet ||
        old.onWalletLongPress != onWalletLongPress ||
        old.isCompact != isCompact;
  }
}

// ─── Transaction Story Card (replaces _StoryCard with real API data) ──────────

class _TransactionStoryCard extends StatelessWidget {
  final dynamic tx;

  /// Danh sách id để lướt qua trong màn hình chi tiết (tùy chọn).
  final List<String>? allStoryIds;
  final String? fallbackUserAvatar;
  const _TransactionStoryCard({
    required this.tx,
    this.allStoryIds,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Đã cập nhật giao dịch và ghi nhận góp ý! Mimo sẽ học thêm từ bạn 🙏',
            ),
            backgroundColor: AppColors.teal,
          ),
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vui lòng nhập số tiền hợp lệ (phải lớn hơn 0)'),
                                ),
                              );
                              return;
                            }
                            if (parsed > 100000000000) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Số tiền tối đa 100 tỷ đồng')),
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Không thể cập nhật giao dịch',
                                    ),
                                  ),
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
    final originalText = tx['originalText'] as String? ?? tx['original_text'] as String? ?? '';
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

class _WalletChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? emoji;
  final bool isSelected;
  final int unseenCount;
  final Color? accentColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _WalletChip({
    required this.label,
    required this.icon,
    this.emoji,
    required this.isSelected,
    this.unseenCount = 0,
    this.accentColor,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? AppColors.teal;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null && emoji!.trim().isNotEmpty)
              Text(
                emoji!,
                style: const TextStyle(fontSize: 14),
              )
            else
              Icon(
                icon,
                size: 16,
                color: isSelected ? effectiveAccent : Colors.white,
              ),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isSelected ? effectiveAccent : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (unseenCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+$unseenCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _SegmentItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _SegmentItem({
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
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? context.palette.card : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.md),
            boxShadow: isSelected ? context.palette.softShadow : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppColors.teal : AppColors.muted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isSelected ? AppColors.teal : AppColors.muted,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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

class _StoryGalleryCard extends StatelessWidget {
  final Map<String, dynamic> story;

  /// Danh sách id để lướt qua trong màn hình chi tiết.
  final List<String>? allStoryIds;

  /// Vị trí của story hiện tại trong [allStoryIds].
  final int initialIndex;
  const _StoryGalleryCard({
    required this.story,
    this.allStoryIds,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final id = story['id'] as String? ?? '';
    final title = story['title'] as String? ?? '';
    final imageUrl =
        story['cover_image_url'] as String? ??
        story['coverImageUrl'] as String? ??
        '';
    final occurredOn =
        story['latest_occurred_at'] as String? ??
        story['latestOccurredAt'] as String? ??
        story['occurred_on'] as String? ??
        story['occurredOn'] as String? ??
        story['created_at'] as String? ??
        story['createdAt'] as String? ??
        '';
    String dateStr = '';
    if (occurredOn.isNotEmpty) {
      final dt = parseStoryDisplayDateTime(
        occurredOn,
        timeSourceIso: story['created_at'] ?? story['createdAt'],
      );
      if (dt != null) {
        dateStr = formatDateTimeShort(dt);
      }
    }
    return GestureDetector(
      onTap: id.isNotEmpty
          ? () {
              final ids = allStoryIds;
              if (ids != null && ids.isNotEmpty) {
                final idx = ids.indexOf(id);
                context.push(
                  AppRoutes.storyDetailOf(id),
                  extra: {
                    'storyIds': ids,
                    'initialIndex': idx < 0 ? initialIndex : idx,
                  },
                );
              } else {
                context.push(AppRoutes.storyDetailOf(id));
              }
            }
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 600,
                    errorWidget: (ctx, url, e) => Container(
                      color: const Color(0xFFCBD5E1),
                      child: const Icon(
                        Icons.photo_camera_outlined,
                        color: Colors.white54,
                        size: 24,
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xFFCBD5E1),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),
            if (dateStr.isNotEmpty)
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            // Category Icon Badge at top-right
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: IconTheme(
                  data: const IconThemeData(color: Colors.white),
                  child: CategoryTheme.iconOf(
                    story['category_code'] as String? ??
                    story['categoryCode'] as String? ??
                    'Other',
                    size: 12,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              right: 8,
              child: Text(
                title.isNotEmpty ? title : 'Story',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Inline Calendar View ─────────────────────────────────────────────────────

class _InlineCalendarView extends StatefulWidget {
  final List<dynamic> byDay;
  final List<dynamic> transactions;
  const _InlineCalendarView({
    this.byDay = const [],
    this.transactions = const [],
  });
  @override
  State<_InlineCalendarView> createState() => _InlineCalendarViewState();
}

class _InlineCalendarViewState extends State<_InlineCalendarView> {
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
                  return _CalendarTransactionListItem(tx: Map<String, dynamic>.from(tx as Map));
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

class _CalendarTransactionListItem extends StatelessWidget {
  final Map<String, dynamic> tx;
  const _CalendarTransactionListItem({required this.tx});

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
    final originalText = tx['originalText'] as String? ?? tx['original_text'] as String? ?? '';
    final label = originalText.isNotEmpty ? originalText : (note.isNotEmpty ? note : 'Giao dịch');
    final displayTime = txTimestampIso(tx) ?? '';
    final isExpense = type.toLowerCase() == 'expense';
    final catStyle = CategoryTheme.of(category);

    String timeStr = '';
    if (displayTime.isNotEmpty) {
      final dt = parseToLocalDateTime(displayTime);
      if (dt != null) {
        timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
            child: Center(
              child: CategoryTheme.iconOf(category, size: 20),
            ),
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

// ─── Draft List Sheet ──────────────────────────────────────────────────────────

class _DraftListSheet extends StatelessWidget {
  final List<dynamic> drafts;
  final void Function(String txId, String label) onFillAmount;

  const _DraftListSheet({required this.drafts, required this.onFillAmount});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.muted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('⚡', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  'Giao dịch chờ điền tiền',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${drafts.length}',
                    style: const TextStyle(
                      color: Color(0xFFB45309),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              itemCount: drafts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final tx = drafts[i] as Map<String, dynamic>;
                final category =
                    tx['category_name'] as String? ??
                    tx['categoryCode'] as String? ??
                    tx['category_code'] as String? ??
                    'Others';
                final note = tx['note'] as String? ?? '';
                final displayTime = txTimestampIso(tx) ?? '';
                final catStyle = CategoryTheme.of(category);
                final label = note.isNotEmpty ? note : catStyle.label;
                final txId = tx['id'] as String? ?? '';

                String timeAgo = '';
                if (displayTime.isNotEmpty) {
                  final dt = parseToLocalDateTime(displayTime);
                  if (dt != null) {
                    final diff = DateTime.now().difference(dt);
                    if (diff.inDays > 0) {
                      timeAgo = '${diff.inDays} ngày trước';
                    } else if (diff.inHours > 0) {
                      timeAgo = '${diff.inHours} giờ trước';
                    } else {
                      timeAgo = '${diff.inMinutes} phút trước';
                    }
                  }
                }

                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    onFillAmount(txId, label);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: catStyle.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: CategoryTheme.iconOf(category, size: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF78350F),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (timeAgo.isNotEmpty)
                                Text(
                                  timeAgo,
                                  style: const TextStyle(
                                    color: Color(0xFFB45309),
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Điền ngay',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
