import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

import '../../services/api_client.dart';

class OnboardingStep1 extends StatefulWidget {
  const OnboardingStep1({super.key});

  @override
  State<OnboardingStep1> createState() => _OnboardingStep1State();
}

class _OnboardingStep1State extends State<OnboardingStep1> {
  final _controller = TextEditingController();
  final _api = ApiClient();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefillName();
    _checkOnboarding();
  }

  Future<void> _prefillName() async {
    try {
      final profile = await _api.getMe();
      final user = profile['user'] as Map<String, dynamic>?;
      final name = user?['username'] as String?;
      if (name != null && name.isNotEmpty && mounted) {
        _controller.text = name;
      }
    } catch (_) {}
  }

  Future<void> _checkOnboarding() async {
    try {
      final loggedIn = await _api.isLoggedIn;
      if (!loggedIn) return;
      final settings = await _api.getSettings();
      final ageGroup = settings['ageGroup'] as String? ?? settings['age_group'] as String?;
      final jobType = settings['jobType'] as String? ?? settings['job_type'] as String?;
      if ((ageGroup != null && ageGroup.isNotEmpty) || (jobType != null && jobType.isNotEmpty)) {
        if (mounted) {
          context.go(AppRoutes.home);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _api.updateProfile({'username': name});
      if (mounted) context.push(AppRoutes.onboardingStep2);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.teal),
        child: SafeArea(
          child: Column(
            children: [
              const _ProgressHeader(label: 'Bước 1/4', percent: '25%', value: 0.25),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      boxShadow: const [
                        BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 20)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset('assets/MiMo/emotions/Hello.png', width: 100, height: 100, fit: BoxFit.contain),
                        const SizedBox(height: 12),
                        Text('Xin chào! Mình là Mimo 😊', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                        const SizedBox(height: 10),
                        Text(
                           'Còn bạn tên gì nhỉ? Cho mình xin tên để dễ gọi nha~',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Tên của bạn', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Nguyễn Văn A, hoặc gọi bạn là gì cũng được',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: SizedBox(
                  width: double.infinity,
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (ctx, child) {
                      final hasText = _controller.text.trim().isNotEmpty;
                      return FilledButton(
                        onPressed: hasText && !_saving ? _submit : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: hasText ? 1.0 : 0.25),
                          foregroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xl)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_saving ? 'Đang lưu...' : 'Tiếp nào! ✨', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_ios, size: 14),
                          ],
                        ),
                      );
                    }
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

class _ProgressHeader extends StatelessWidget {
  final String label;
  final String percent;
  final double value;

  const _ProgressHeader({required this.label, required this.percent, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
              Text(percent, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}