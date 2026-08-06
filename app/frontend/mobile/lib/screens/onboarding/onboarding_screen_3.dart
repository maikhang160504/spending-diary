import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/categories.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../services/api_client.dart';
import '../../widgets/mimo_snackbar.dart';

class OnboardingStep3 extends StatefulWidget {
  const OnboardingStep3({super.key});

  @override
  State<OnboardingStep3> createState() => _OnboardingStep3State();
}

class _OnboardingStep3State extends State<OnboardingStep3> {
  final _api = ApiClient();
  bool _saving = false;

  static const _allCats = [
    _Cat('Food', 'Ăn uống', Color(0xFFEC4899), '2.000.000'),
    _Cat('Transport', 'Di chuyển', Color(0xFF3B82F6), '500.000'),
    _Cat('Shopping', 'Mua sắm', Color(0xFF8B5CF6), '1.500.000'),
    _Cat('Entertainment', 'Giải trí', Color(0xFFF59E0B), '800.000'),
    _Cat('Health', 'Sức khỏe', Color(0xFF10B981), '300.000'),
    _Cat('Education', 'Giáo dục', Color(0xFF06B6D4), '500.000'),
    _Cat('Beauty', 'Làm đẹp', Color(0xFFDB2777), '300.000'),
    _Cat('Housing', 'Nhà ở', Color(0xFF22C55E), '1.000.000'),
    _Cat('Social', 'Xã hội', Color(0xFFE11D48), '400.000'),
    _Cat('Business', 'Kinh doanh', Color(0xFF0EA5E9), ''),
    _Cat('Bonus', 'Thưởng', Color(0xFF16A34A), ''),
    _Cat('Charity', 'Từ thiện', Color(0xFFEC4899), ''),
    _Cat('Essentials', 'Đồ thiết yếu', Color(0xFF64748B), '500.000'),
    _Cat('Debt', 'Nợ', Color(0xFFDC2626), ''),
    _Cat('Investment', 'Đầu tư', Color(0xFF6366F1), ''),
    _Cat('Saving', 'Tiết kiệm', Color(0xFF0EA5E9), ''),
    _Cat('Salary', 'Lương', Color(0xFF16A34A), ''),
    _Cat('Other', 'Khác', Color(0xFF94A3B8), ''),
  ];

  final Set<String> _selected = {
    'Food',
    'Shopping',
    'Transport',
    'Entertainment',
    'Other',
  };
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final c in _allCats) {
      _controllers[c.code] = TextEditingController(text: c.defaultAmount);
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final wallets = await _api.getWallets();
      if (wallets.isNotEmpty) {
        final walletId = wallets[0]['id'];
        final startDate = DateTime.now().toIso8601String().split('T')[0];
        for (final catCode in _selected) {
          final text =
              _controllers[catCode]?.text
                  .replaceAll('.', '')
                  .replaceAll(',', '')
                  .trim() ??
              '';
          final amount = double.tryParse(text);
          if (amount != null && amount > 0) {
            try {
              await _api.createBudget({
                'walletId': walletId,
                'categoryCode': catCode,
                'amountLimit': amount.toInt(),
                'period': 'month',
                'startDate': startDate,
              });
            } catch (_) {}
          }
        }
      }
      if (mounted) context.push(AppRoutes.onboardingStep4);
    } catch (e) {
      if (mounted) {
        MimoSnackBar.showInfo(context, message: 'Lỗi: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.teal),
        child: SafeArea(
          child: Column(
            children: [
              _ProgressHeader(
                label: 'Bước 3/4',
                percent: '75%',
                value: 0.75,
                onSkip: () => context.go(AppRoutes.onboardingStep4),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 30,
                          offset: Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/MiMo/category/Savings.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Giới hạn chi tiêu',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Đặt giới hạn cho từng danh mục (có thể bỏ qua)',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Chọn danh mục cần đặt giới hạn:',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _allCats.map((cat) {
                            final isOn = _selected.contains(cat.code);
                            return GestureDetector(
                              onTap: () => setState(() {
                                if (isOn) {
                                  _selected.remove(cat.code);
                                } else {
                                  _selected.add(cat.code);
                                }
                              }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isOn
                                      ? cat.color.withValues(alpha: 0.12)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(
                                    AppRadii.lg,
                                  ),
                                  border: Border.all(
                                    color: isOn ? cat.color : AppColors.border,
                                    width: isOn ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CategoryTheme.iconOf(cat.code, size: 16),
                                    const SizedBox(width: 5),
                                    Text(
                                      cat.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isOn
                                            ? cat.color
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),
                        ..._allCats
                            .where((c) => _selected.contains(c.code))
                            .map(
                              (cat) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: cat.color.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Center(
                                            child: CategoryTheme.iconOf(
                                              cat.code,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          cat.label,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    TextField(
                                      controller: _controllers[cat.code],
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        hintText: 'Nhập giới hạn...',
                                        prefixIcon: Icon(
                                          Icons.attach_money,
                                          size: 18,
                                        ),
                                        suffixText: 'đ',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F7F6),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Row(
                            children: [
                              const Text('💡', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bạn có thể thay đổi giới hạn này bất cứ lúc nào trong Cài đặt',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: AppColors.tealDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _NavButtons(
                onBack: () => context.pop(),
                onNext: _saving ? () {} : _submit,
                nextLabel: _saving ? 'Đang lưu...' : 'Tiếp tục',
              ),
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
  final String defaultAmount;
  const _Cat(this.code, this.label, this.color, this.defaultAmount);
}

class _NavButtons extends StatelessWidget {
  final VoidCallback onBack, onNext;
  final String nextLabel;
  const _NavButtons({
    required this.onBack,
    required this.onNext,
    this.nextLabel = 'Tiếp tục',
  });

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
              label: const Text(
                'Quay lại',
                style: TextStyle(color: Colors.white),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                nextLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final String label, percent;
  final double value;
  final VoidCallback? onSkip;
  const _ProgressHeader({
    required this.label,
    required this.percent,
    required this.value,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onSkip != null)
                GestureDetector(
                  onTap: onSkip,
                  child: const Text(
                    'Bỏ qua',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white70,
                    ),
                  ),
                )
              else
                Text(
                  percent,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
