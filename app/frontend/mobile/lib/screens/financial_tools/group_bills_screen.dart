import 'package:flutter/material.dart';
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
    final descCtrl = TextEditingController();
    final membersCtrl = TextEditingController();
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
                  labelText: 'Tên nhóm (*)',
                  hintText: 'VD: Du lịch Đà Lạt',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                maxLength: 255,
                decoration: const InputDecoration(
                  labelText: 'Mô tả',
                  hintText: 'Mục đích của nhóm (không bắt buộc)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: membersCtrl,
                decoration: const InputDecoration(
                  labelText: 'Thành viên ban đầu',
                  hintText: 'Nhập tên, cách nhau bởi dấu phẩy',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Lưu ý: Bạn (Chủ nhóm) sẽ tự động được thêm vào nhóm.',
                style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;
                          
                          final desc = descCtrl.text.trim();
                          final membersText = membersCtrl.text.trim();
                          List<String>? members;
                          if (membersText.isNotEmpty) {
                            members = membersText.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                          }

                          setSheet(() => isSubmitting = true);
                          try {
                            await _api.createExpenseGroup(
                              name: name,
                              description: desc,
                              members: members,
                            );
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              _loadGroups();
                              MimoSnackBar.show(
                                context,
                                message: 'Tạo nhóm thành công!',
                                type: MimoSnackBarType.success,
                              );
                            }
                          } on ApiException catch (e) {
                            if (!mounted) return;
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
    bool showMemberSelection = false;
    Map<String, dynamic>? groupInfo;
    List<dynamic> availableMembers = [];
    String? selectedMemberId;

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
                showMemberSelection ? 'Chọn vai trò của bạn' : 'Tham gia nhóm',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              if (!showMemberSelection) ...[
                TextField(
                  controller: codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Mã tham gia',
                    hintText: 'VD: AB12CD',
                  ),
                ),
              ] else ...[
                Text('Bạn đang tham gia nhóm: ${groupInfo?['name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('Vui lòng chọn vai trò của bạn (nếu chủ nhóm đã tạo sẵn tên bạn):'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: selectedMemberId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Tôi là thành viên mới', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.teal)),
                    ),
                    ...availableMembers.map((m) => DropdownMenuItem<String?>(
                          value: m['id'],
                          child: Text(m['display_name']),
                        )),
                  ],
                  onChanged: (val) {
                    setSheet(() => selectedMemberId = val);
                  },
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!showMemberSelection) {
                            final code = codeCtrl.text.trim();
                            if (code.isEmpty) return;
                            
                            setSheet(() => isSubmitting = true);
                            try {
                              final preview = await _api.previewExpenseGroup(code);
                              if (mounted) {
                                setSheet(() {
                                  isSubmitting = false;
                                  showMemberSelection = true;
                                  groupInfo = preview['group'];
                                  availableMembers = preview['availableMembers'] ?? [];
                                  selectedMemberId = null;
                                });
                              }
                            } on ApiException catch (e) {
                              if (!mounted) return;
                              MimoSnackBar.show(
                                context,
                                message: e.localizedMessage,
                                type: MimoSnackBarType.error,
                              );
                              setSheet(() => isSubmitting = false);
                            }
                          } else {
                            setSheet(() => isSubmitting = true);
                            try {
                              await _api.joinExpenseGroup(
                                codeCtrl.text.trim(),
                                memberId: selectedMemberId,
                              );
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                              }
                              if (mounted) {
                                _loadGroups();
                                MimoSnackBar.show(
                                  context,
                                  message: 'Tham gia thành công!',
                                  type: MimoSnackBarType.success,
                                );
                              }
                            } on ApiException catch (e) {
                              if (!mounted) return;
                              MimoSnackBar.show(
                                context,
                                message: e.localizedMessage,
                                type: MimoSnackBarType.error,
                              );
                              setSheet(() => isSubmitting = false);
                            }
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
                      : Text(showMemberSelection ? 'Xác nhận tham gia' : 'Tiếp tục'),
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
      body: SafeArea(
        child: Column(
          children: [
            _GroupBillsHeader(
              onCreateGroup: _showCreateGroup,
              onJoinGroup: _showJoinGroup,
            ),
            Expanded(
              child: _loading
                  ? ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: 4,
                      itemBuilder: (_, _) => Padding(
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
            ),
          ],
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
        boxShadow: AppShadows.card,
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

class _GroupBillsHeader extends StatelessWidget {
  final VoidCallback onCreateGroup;
  final VoidCallback onJoinGroup;
  const _GroupBillsHeader({required this.onCreateGroup, required this.onJoinGroup});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadii.xl),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 24),
      child: Row(
        children: [
          if (Navigator.canPop(context)) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 38,
                height: 38,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Chia Bill Nhóm',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Quản lý chi tiêu chung cùng bạn bè',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Tạo nhóm mới',
            child: GestureDetector(
              onTap: onCreateGroup,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Tham gia nhóm',
            child: GestureDetector(
              onTap: onJoinGroup,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.login_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

