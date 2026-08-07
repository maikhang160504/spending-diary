import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/mimo_snackbar.dart';

// You will need to implement group_detail_screen.dart later
import 'group_detail_screen.dart';

class GroupBillsScreen extends StatefulWidget {
  const GroupBillsScreen({super.key});

  @override
  State<GroupBillsScreen> createState() => _GroupBillsScreenState();
}

class _GroupBillsScreenState extends State<GroupBillsScreen> {
  final _api = ApiClient();
  List<dynamic> _groups = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await _api.getExpenseGroups();
      _groups = groups;
    } on ApiException catch (e) {
      _error = e.localizedMessage;
    } catch (_) {
      _error = 'Không thể tải danh sách nhóm';
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showCreateGroup() {
    final nameCtrl = TextEditingController();
    String currency = 'VND';
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tạo nhóm chi tiêu mới',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Tên nhóm',
                  hintText: 'VD: Du lịch Đà Lạt',
                  counterText: '',
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;

                          setSheet(() => isSubmitting = true);
                          try {
                            await _api.createExpenseGroup(name);
                            if (mounted) {
                              Navigator.pop(ctx);
                              _loadGroups();
                              MimoSnackBar.show(
                                context,
                                message: 'Tạo nhóm thành công!',
                                type: MimoSnackBarType.success,
                              );
                            }
                          } on ApiException catch (e) {
                            MimoSnackBar.show(
                              context,
                              message: e.localizedMessage,
                              type: MimoSnackBarType.error,
                            );
                            setSheet(() => isSubmitting = false);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Tạo nhóm'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showJoinGroup() {
    final codeCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 600),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tham gia nhóm',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Mã tham gia',
                  hintText: 'VD: AB12CD',
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final code = codeCtrl.text.trim();
                          if (code.isEmpty) return;

                          setSheet(() => isSubmitting = true);
                          try {
                            await _api.joinExpenseGroup(code);
                            if (mounted) {
                              Navigator.pop(ctx);
                              _loadGroups();
                              MimoSnackBar.show(
                                context,
                                message: 'Tham gia thành công!',
                                type: MimoSnackBarType.success,
                              );
                            }
                          } on ApiException catch (e) {
                            MimoSnackBar.show(
                              context,
                              message: e.localizedMessage,
                              type: MimoSnackBarType.error,
                            );
                            setSheet(() => isSubmitting = false);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Tham gia'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        title: const Text('Chia Bill Nhóm'),
        backgroundColor: context.palette.bg,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: _showCreateGroup,
            tooltip: 'Tạo nhóm',
          ),
          IconButton(
            icon: const Icon(Icons.login_rounded),
            onPressed: _showJoinGroup,
            tooltip: 'Tham gia',
          ),
        ],
      ),
      body: _loading
          ? ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 4,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SkeletonCard(height: 80, borderRadius: AppRadii.lg),
              ),
            )
          : _error != null
              ? Center(
                  child: ErrorBanner(
                    message: _error!,
                    onRetry: _loadGroups,
                  ),
                )
              : _groups.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadGroups,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _groups.length,
                        itemBuilder: (ctx, index) {
                          final group = _groups[index];
                          return _buildGroupCard(group);
                        },
                      ),
                    ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.groups_rounded,
              size: 64,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Chưa có nhóm nào',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tạo hoặc tham gia nhóm để quản lý\nchi tiêu chung cùng bạn bè.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: [
              FilledButton.icon(
                onPressed: _showCreateGroup,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Tạo nhóm'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _showJoinGroup,
                icon: const Icon(Icons.login_rounded, size: 20),
                label: const Text('Tham gia'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  side: BorderSide(color: AppColors.teal),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.palette.bg,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GroupDetailScreen(groupId: group['id']),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    group['name'].toString().substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: AppColors.teal,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Thành viên: ${group['member_count'] ?? 1}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
