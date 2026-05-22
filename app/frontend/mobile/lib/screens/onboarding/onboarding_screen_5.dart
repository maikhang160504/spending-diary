import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class OnboardingStep5 extends StatefulWidget {
  const OnboardingStep5({super.key});

  @override
  State<OnboardingStep5> createState() => _OnboardingStep5State();
}

class _OnboardingStep5State extends State<OnboardingStep5> {
  final _api = ApiClient();
  bool _saving = false;
  String? _selectedAge;
  String? _selectedJob;

  static const _ages = ['18-22 tuổi', '23-30 tuổi', '31-40 tuổi', '41-50 tuổi', 'Trên 50'];
  static const _ageEmojis = ['🎓', '💼', '👔', '🏢', '✨'];
  static const _jobs = ['Sinh viên', 'Văn phòng', 'Freelancer', 'Kinh doanh', 'Khác'];
  static const _jobEmojis = ['📚', '💻', '✨', '💼', '🎯'];

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await _api.updateSettings({
        if (_selectedAge != null) 'ageGroup': _selectedAge,
        if (_selectedJob != null) 'jobType': _selectedJob,
      });
    } catch (_) {}
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.teal),
        child: SafeArea(
          child: Column(
            children: [
              const _ProgressHeader(label: 'Bước 5/5', percent: '100%', value: 1.0),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.xl),
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 20))]),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 60, height: 60,
                            decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(AppRadii.lg)),
                            child: const Center(child: Text('👤', style: TextStyle(fontSize: 28)))),
                        const SizedBox(height: 16),
                        Text('Thông tin cá nhân', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Để Mimo có thể tư vấn phù hợp với bạn nhất',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        _sectionLabel(context, 'Độ tuổi của bạn'),
                        const SizedBox(height: 12),
                        _optionGrid(_ages, _ageEmojis, _selectedAge, (v) => setState(() => _selectedAge = v)),
                        const SizedBox(height: 20),
                        _sectionLabel(context, 'Nghề nghiệp'),
                        const SizedBox(height: 12),
                        _optionGrid(_jobs, _jobEmojis, _selectedJob, (v) => setState(() => _selectedJob = v)),
                        const SizedBox(height: 16),
                        Container(padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFE8F7F6), borderRadius: BorderRadius.circular(AppRadii.md)),
                            child: Row(children: [
                              const Text('💡', style: TextStyle(fontSize: 16)), const SizedBox(width: 8),
                              Expanded(child: Text('Thông tin này giúp AI nhận xét chính xác hơn về chi tiêu của bạn',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.tealDark))),
                            ])),
                      ],
                    ),
                  ),
                ),
              ),
              _NavButtons(
                onBack: () => context.pop(),
                onNext: _saving ? null : _finish,
                nextLabel: _saving ? 'Đang lưu...' : 'Hoàn thành 🎉',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String label) {
    return Align(alignment: Alignment.centerLeft, child: Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700)));
  }

  Widget _optionGrid(List<String> labels, List<String> emojis, String? selected, ValueChanged<String> onTap) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: List.generate(labels.length, (i) {
        final isSelected = selected == labels[i];
        return GestureDetector(
          onTap: () => onTap(labels[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.teal.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: isSelected ? AppColors.teal : AppColors.border, width: isSelected ? 2 : 1),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(emojis[i], style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 2),
              Text(labels[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isSelected ? AppColors.teal : AppColors.textSecondary),
                  textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        );
      }),
    );
  }
}

class _NavButtons extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final String nextLabel;
  const _NavButtons({required this.onBack, required this.onNext, this.nextLabel = 'Tiếp tục'});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: onBack,
            icon: const Icon(Icons.chevron_left, color: Colors.white), label: const Text('Quay lại', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(vertical: 14)))),
        const SizedBox(width: 12),
        Expanded(child: FilledButton(onPressed: onNext,
            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Text(nextLabel, style: const TextStyle(fontWeight: FontWeight.w700)))),
      ]),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final String label, percent;
  final double value;
  const _ProgressHeader({required this.label, required this.percent, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(percent, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(value: value, backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), minHeight: 6)),
      ]),
    );
  }
}