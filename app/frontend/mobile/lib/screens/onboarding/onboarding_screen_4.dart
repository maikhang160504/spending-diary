import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/categories.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class OnboardingStep4 extends StatefulWidget {
  const OnboardingStep4({super.key});

  @override
  State<OnboardingStep4> createState() => _OnboardingStep4State();
}

class _OnboardingStep4State extends State<OnboardingStep4> {
  final _cats = [
    _Cat('Food',          'Ăn uống', const Color(0xFFEC4899), TextEditingController(text: '2.000.000')),
    _Cat('Shopping',      'Mua sắm', const Color(0xFF8B5CF6), TextEditingController(text: '1.500.000')),
    _Cat('Transport',     'Di chuyển', const Color(0xFF3B82F6), TextEditingController(text: '500.000')),
    _Cat('Entertainment', 'Giải trí', const Color(0xFFF59E0B), TextEditingController(text: '800.000')),
    _Cat('Others',        'Khác', const Color(0xFF94A3B8), TextEditingController()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.teal),
        child: SafeArea(
          child: Column(
            children: [
              const _ProgressHeader(label: 'Bước 4/5', percent: '80%', value: 0.8),
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
                        Image.asset('assets/MiMo/category/Savings.png', width: 56, height: 56, fit: BoxFit.contain),
                        const SizedBox(height: 12),
                        Text('Giới hạn chi tiêu', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Đặt giới hạn cho từng danh mục (có thể bỏ qua)',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        ..._cats.map((cat) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(width: 32, height: 32, decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                                  child: Center(child: CategoryTheme.iconOf(cat.code, size: 20))),
                              const SizedBox(width: 8),
                              Text(cat.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 8),
                            TextField(controller: cat.controller, keyboardType: TextInputType.number,
                                decoration: const InputDecoration(hintText: 'Nhập giới hạn...', prefixIcon: Icon(Icons.attach_money, size: 18), suffixText: 'đ')),
                          ]),
                        )),
                        Container(padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFE8F7F6), borderRadius: BorderRadius.circular(AppRadii.md)),
                            child: Row(children: [
                              const Text('💡', style: TextStyle(fontSize: 16)), const SizedBox(width: 8),
                              Expanded(child: Text('Bạn có thể thay đổi giới hạn này bất cứ lúc nào trong Cài đặt',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.tealDark))),
                            ])),
                      ],
                    ),
                  ),
                ),
              ),
              _NavButtons(onBack: () => context.pop(), onNext: () => context.push(AppRoutes.onboardingStep5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cat {
  final String code, label;
  final Color color;
  final TextEditingController controller;
  const _Cat(this.code, this.label, this.color, this.controller);
}

class _NavButtons extends StatelessWidget {
  final VoidCallback onBack, onNext;
  const _NavButtons({required this.onBack, required this.onNext});

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
            child: const Text('Tiếp tục', style: TextStyle(fontWeight: FontWeight.w600)))),
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