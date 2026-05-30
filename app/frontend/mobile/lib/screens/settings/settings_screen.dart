import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/app_queries.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/theme_controller.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/skeleton.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _selectedPersonality = 'Dui Dẻ';
  String _verbalStyle = 'funny';
  final _api = ApiClient();

  // API data
  bool _loading = true;
  String _userName = 'Người dùng SpendDiary';
  String _email = 'user@email.com';
  String? _avatarUrl;
  bool _uploadingAvatar = false;
  int _monthlyIncome = 0;
  String _ageGroup = '';
  String _jobType = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getMe(),
        _api.getSettings(),
      ]);
      final me = results[0];
      final settings = results[1];
      if (!mounted) return;
      setState(() {
        final user = me['user'] as Map<String, dynamic>?;
        _userName = (user?['username'] as String?) ?? 'Người dùng SpendDiary';
        _email = (user?['email'] as String?) ?? 'user@email.com';
        _avatarUrl = (user?['avatar_url'] as String?) ?? (user?['avatarUrl'] as String?);
        final inc = user?['income_amount'];
        _monthlyIncome = inc is num ? inc.toInt() : 0;
        _ageGroup = (settings['age_group'] as String?) ?? '';
        _jobType = (settings['job_type'] as String?) ?? '';
        _verbalStyle = (settings['verbal_style'] as String?) == 'strict' ? 'strict' : 'funny';
        _selectedPersonality = _verbalStyle == 'strict' ? 'Dận Dữ' : 'Dui Dẻ';
        _notificationsEnabled = (settings['notifications_enabled'] as bool?) ?? true;
      });
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      await _api.updateSettings({key: value});
    } catch (_) {}
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1024);
    if (xFile == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uploaded = await _api.uploadFile(xFile.path);
      final url = (uploaded['publicUrl'] as String?) ??
          (uploaded['url'] as String?) ??
          (uploaded['fileUrl'] as String?) ??
          (uploaded['file_url'] as String?);
      if (url != null && url.isNotEmpty) {
        await _api.updateProfile({'avatarUrl': url});
        if (!mounted) return;
        setState(() => _avatarUrl = url);
        messenger.showSnackBar(
          const SnackBar(content: Text('Đã cập nhật ảnh đại diện ✓'), backgroundColor: AppColors.teal),
        );
      }
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Không thể cập nhật ảnh đại diện')));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _logout() async {
    try {
      await _api.logout();
    } catch (_) {
      await _api.clearTokens();
    }
    // Xoá cache để phiên đăng nhập mới không thấy dữ liệu của user cũ.
    AppQueries.clearAll();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  void _showPersonalInfoDialog() {
    final nameCtrl = TextEditingController(text: _userName);
    final ageCtrl = TextEditingController(text: _ageGroup);
    final jobCtrl = TextEditingController(text: _jobType);
    final incomeCtrl = TextEditingController(text: _monthlyIncome > 0 ? _monthlyIncome.toString() : '');
    String? dialogError;
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Chỉnh sửa thông tin'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (dialogError != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                  child: Text(dialogError!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Tên người dùng')),
              const SizedBox(height: 10),
              Text(_email, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              const SizedBox(height: 10),
              TextField(controller: ageCtrl, decoration: const InputDecoration(labelText: 'Độ tuổi (vd: 18-24)')),
              const SizedBox(height: 10),
              TextField(controller: jobCtrl, decoration: const InputDecoration(labelText: 'Nghề nghiệp')),
              const SizedBox(height: 10),
              TextField(
                controller: incomeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Thu nhập hàng tháng', suffixText: 'đ'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => ctx.pop(), child: const Text('Hủy')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        setDialogState(() => dialogError = 'Tên người dùng không được để trống');
                        return;
                      }
                      setDialogState(() { saving = true; dialogError = null; });
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await _api.updateProfile({
                          'username': name,
                          'incomeAmount': int.tryParse(incomeCtrl.text.trim()) ?? _monthlyIncome,
                        });
                        await _api.updateSettings({
                          'ageGroup': ageCtrl.text.trim(),
                          'jobType': jobCtrl.text.trim(),
                        });
                        if (!mounted) return;
                        setState(() {
                          _userName = name;
                          _ageGroup = ageCtrl.text.trim();
                          _jobType = jobCtrl.text.trim();
                          _monthlyIncome = int.tryParse(incomeCtrl.text.trim()) ?? _monthlyIncome;
                        });
                        if (ctx.mounted) ctx.pop();
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Đã lưu thông tin cá nhân ✓'), backgroundColor: AppColors.teal),
                        );
                      } on ApiException catch (e) {
                        setDialogState(() { saving = false; dialogError = e.localizedMessage; });
                      } catch (_) {
                        setDialogState(() { saving = false; dialogError = 'Không thể lưu thông tin'; });
                      }
                    },
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePassword() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Đổi mật khẩu'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            if (dialogError != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                child: Text(dialogError!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
              ),
              const SizedBox(height: 8),
            ],
            TextField(controller: currentCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu hiện tại')),
            const SizedBox(height: 8),
            TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu mới (≥ 8 ký tự)')),
            const SizedBox(height: 8),
            TextField(controller: confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu')),
          ]),
          actions: [
            TextButton(onPressed: () => ctx.pop(), child: const Text('Hủy')),
            FilledButton(
              onPressed: () async {
                if (newCtrl.text.length < 8) {
                  setDialogState(() => dialogError = 'Mật khẩu mới phải ≥ 8 ký tự');
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  setDialogState(() => dialogError = 'Mật khẩu xác nhận không khớp');
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _api.changePassword(currentCtrl.text, newCtrl.text);
                  if (!ctx.mounted) return;
                  ctx.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Đổi mật khẩu thành công ✓'), backgroundColor: AppColors.teal),
                  );
                } on ApiException catch (e) {
                  setDialogState(() => dialogError = e.localizedMessage);
                } catch (_) {
                  setDialogState(() => dialogError = 'Không thể đổi mật khẩu');
                }
              },
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SettingsHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Profile card — dynamic from API
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: context.palette.softShadow,
                      ),
                      child: _loading
                          ? const SkeletonCard(height: 56)
                          : Row(
                              children: [
                                GestureDetector(
                                  onTap: _uploadingAvatar ? null : _changeAvatar,
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: _avatarColor(_userName),
                                          shape: BoxShape.circle,
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: _uploadingAvatar
                                            ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                                            : (_avatarUrl != null && _avatarUrl!.isNotEmpty)
                                                ? CachedNetworkImage(
                                                    imageUrl: _avatarUrl!,
                                                    fit: BoxFit.cover,
                                                    memCacheWidth: 300,
                                                    errorWidget: (_, __, ___) => Center(child: Text(
                                                      _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
                                                    )),
                                                  )
                                                : Center(child: Text(
                                                    _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 22),
                                                  )),
                                      ),
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          width: 20, height: 20,
                                          decoration: BoxDecoration(
                                            color: AppColors.teal,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 2),
                                          ),
                                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_userName, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(_email, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 24),
                    // Tài khoản section
                    Text('Tài khoản', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: context.palette.softShadow,
                      ),
                      child: Column(
                        children: [
                          _SettingRow(
                            icon: Icons.person_outline,
                            label: 'Thông tin cá nhân',
                            subtitle: _email,
                            showDivider: true,
                            onTap: _showPersonalInfoDialog,
                          ),
                          _SettingRow(
                            icon: Icons.tune_outlined,
                            label: 'Hạn mức chi tiêu',
                            subtitle: 'Xem các giới hạn đã đặt',
                            showDivider: false,
                            onTap: () => context.push(AppRoutes.limits),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Tùy chỉnh section
                    Text('Tùy chỉnh', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: context.palette.softShadow,
                      ),
                      child: Column(
                        children: [
                          // AI personality — synced with onboarding Dui Dẻ / Dận Dữ
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.teal.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.auto_awesome, color: AppColors.teal, size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Phong cách AI', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                          Text(_selectedPersonality, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: AppColors.muted),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _AiStyleSwapSelector(
                                  selected: _verbalStyle,
                                  onSelected: (style) {
                                    setState(() {
                                      _verbalStyle = style;
                                      _selectedPersonality = style == 'strict' ? 'Dận Dữ' : 'Dui Dẻ';
                                    });
                                    _updateSetting('verbalStyle', style);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          // Notifications toggle — persisted via API
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.notifications_outlined, color: AppColors.teal, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text('Thông báo', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                              Switch(
                                value: _notificationsEnabled,
                                onChanged: (v) {
                                  setState(() => _notificationsEnabled = v);
                                  _updateSetting('notificationsEnabled', v);
                                },
                                activeThumbColor: AppColors.teal,
                              ),
                            ]),
                          ),
                          Divider(height: 1, color: context.palette.border),
                          // Dark mode toggle — persisted via API
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.teal.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.dark_mode_outlined, color: AppColors.teal, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text('Chế độ tối', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                              Switch(
                                value: ThemeController.instance.mode == ThemeMode.dark,
                                onChanged: (v) {
                                  // Đổi giao diện ngay + lưu lựa chọn cục bộ.
                                  ThemeController.instance.setMode(v ? ThemeMode.dark : ThemeMode.light);
                                  setState(() {});
                                  _updateSetting('themeMode', v);
                                },
                                activeThumbColor: AppColors.teal,
                              ),
                            ]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Bảo mật section
                    Text('Bảo mật', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showChangePassword,
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.palette.card,
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          boxShadow: context.palette.softShadow,
                        ),
                        child: const _SettingRow(icon: Icons.shield_outlined, label: 'Đổi mật khẩu', showDivider: false),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Logout button — real API
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: AppColors.danger, size: 18),
                        label: const Text('Đăng xuất', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.danger),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text('SpendDiary v1.0.0', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _avatarColor(String name) {
    if (name.isEmpty) return AppColors.teal;
    final hash = name.codeUnits.fold<int>(0, (prev, c) => prev + c);
    final colors = [
      AppColors.teal, const Color(0xFF6366F1), const Color(0xFFEC4899),
      const Color(0xFFF59E0B), const Color(0xFF3B82F6), const Color(0xFF10B981),
    ];
    return colors[hash % colors.length];
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppGradients.teal,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppRadii.xl),
          bottomRight: Radius.circular(AppRadii.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cài đặt', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Quản lý tài khoản và tùy chỉnh ứng dụng', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool showDivider;
  final VoidCallback? onTap;

  const _SettingRow({required this.icon, required this.label, this.subtitle, this.showDivider = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.teal, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        )),
        if (showDivider) Divider(height: 1, color: context.palette.border),
      ],
    );
  }
}

/// Bộ chọn phong cách AI có hiệu ứng 2 icon đổi chỗ cho nhau khi chọn.
class _AiStyleSwapSelector extends StatefulWidget {
  final String selected; // 'funny' | 'strict'
  final ValueChanged<String> onSelected;
  const _AiStyleSwapSelector({required this.selected, required this.onSelected});

  @override
  State<_AiStyleSwapSelector> createState() => _AiStyleSwapSelectorState();
}

class _AiStyleSwapSelectorState extends State<_AiStyleSwapSelector> {
  // Khi true: "Dui Dẻ" ở bên trái. 2 icon đổi chỗ liên tục (như xáo thẻ bài)
  // cho đến khi người dùng chọn.
  bool _funnyOnLeft = true;
  bool _chosen = false;
  Timer? _shuffleTimer;

  @override
  void initState() {
    super.initState();
    _startShuffle();
  }

  void _startShuffle() {
    _shuffleTimer?.cancel();
    _shuffleTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      if (!mounted || _chosen) return;
      setState(() => _funnyOnLeft = !_funnyOnLeft);
    });
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    super.dispose();
  }

  void _select(String style) {
    _shuffleTimer?.cancel();
    setState(() {
      _chosen = true;
      // Thẻ được chọn dừng ở bên trái (vị trí nổi bật).
      _funnyOnLeft = style == 'funny';
    });
    widget.onSelected(style);
  }

  @override
  Widget build(BuildContext context) {
    const gap = 10.0;
    const height = 92.0;
    return LayoutBuilder(builder: (ctx, c) {
      final cardW = (c.maxWidth - gap) / 2;
      final rightX = cardW + gap;
      final funnyX = _funnyOnLeft ? 0.0 : rightX;
      final strictX = _funnyOnLeft ? rightX : 0.0;
      return SizedBox(
        height: height,
        child: Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOut,
            left: funnyX, top: 0, width: cardW, height: height,
            child: _StyleCard(
              asset: 'assets/MiMo/emotions/Cool.png',
              fallback: '😎',
              label: 'Dui Dẻ',
              selected: widget.selected == 'funny',
              onTap: () => _select('funny'),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOut,
            left: strictX, top: 0, width: cardW, height: height,
            child: _StyleCard(
              asset: 'assets/MiMo/emotions/Angry.png',
              fallback: '🔥',
              label: 'Dận Dữ',
              selected: widget.selected == 'strict',
              onTap: () => _select('strict'),
            ),
          ),
        ]),
      );
    });
  }
}

class _StyleCard extends StatelessWidget {
  final String asset;
  final String fallback;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StyleCard({required this.asset, required this.fallback, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal.withValues(alpha: 0.1) : context.palette.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: selected ? AppColors.teal : context.palette.border, width: selected ? 2 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.asset(asset, width: 36, height: 36, errorBuilder: (_, __, ___) => Text(fallback, style: const TextStyle(fontSize: 24))),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.teal : AppColors.textPrimary,
          )),
        ]),
      ),
    );
  }
}