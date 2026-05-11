import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class OnboardingStep2 extends StatefulWidget {
  const OnboardingStep2({super.key});

  @override
  State<OnboardingStep2> createState() => _OnboardingStep2State();
}

class _OnboardingStep2State extends State<OnboardingStep2> {
  bool _isFixed = true;
  final _amountController = TextEditingController(text: '8.000.000');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.teal),
        child: SafeArea(
          child: Column(
            children: [
              const _ProgressHeader(label: 'Bước 2/5', percent: '40%', value: 0.4),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 20))],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(color: AppColors.teal, borderRadius: BorderRadius.circular(AppRadii.lg)),
                            child: const Center(child: Text('💼', style: TextStyle(fontSize: 28))),
                          ),
                          const SizedBox(height: 16),
                          Text('Thu nhập của bạn', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text('Để Mimo hiểu rõ tình hình tài chính của bạn hơn',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: _typeCard('💼', 'Cố định', _isFixed, () => setState(() => _isFixed = true))),
                              const SizedBox(width: 12),
                              Expanded(child: _typeCard('📊', 'Không cố định', !_isFixed, () => setState(() => _isFixed = false))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Align(alignment: Alignment.centerLeft, child: Text('Số tiền (VND)', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
                          const SizedBox(height: 8),
                          TextField(controller: _amountController, keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: '8.000.000', prefixIcon: Icon(Icons.attach_money))),
                          const SizedBox(height: 6),
                          Align(alignment: Alignment.centerLeft,
                              child: Text('${_amountController.text} đ/tháng', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w600))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _NavButtons(onBack: () => context.pop(), onNext: () => context.push(AppRoutes.onboardingStep3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeCard(String emoji, String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.teal.withValues(alpha: 0.1) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: isSelected ? AppColors.teal : AppColors.border, width: isSelected ? 2 : 1),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? AppColors.teal : AppColors.textPrimary)),
        ]),
      ),
    );
  }
}

class _NavButtons extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _NavButtons({required this.onBack, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left, color: Colors.white),
              label: const Text('Quay lại', style: TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.teal, padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Tiếp tục', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
          Text(percent, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: value, backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white), minHeight: 6),
        ),
      ]),
    );
  }
}