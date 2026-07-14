import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';

class OnboardingStep4 extends StatefulWidget {
  const OnboardingStep4({super.key});

  @override
  State<OnboardingStep4> createState() => _OnboardingStep4State();
}

class _OnboardingStep4State extends State<OnboardingStep4> {
  final _api = ApiClient();
  bool _saving = false;
  String? _selectedAge;
  String? _selectedJob;

  static const _ages = ['18-22 tuổi', '23-30 tuổi', '31-40 tuổi', '41-50 tuổi', 'Trên 50'];
  static const _ageEmojis = ['🎓', '💼', '👔', '🏢', '✨'];
  static const _jobs = ['Sinh viên', 'Văn phòng', 'Freelancer', 'Kinh doanh', 'Khác'];
  static const _jobEmojis = ['📚', '💻', '✨', '💼', '🎯'];

  Future<void> _finish() async {
    final walletConfig = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final nameCtrl = TextEditingController(text: 'Ví cá nhân');
        final balanceCtrl = TextEditingController(text: '0');
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tạo ví đầu tiên của bạn',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thiết lập ví đầu tiên để ghi chép các giao dịch chi tiêu của bạn.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 20),
                    // Wallet Name Field
                    const Text(
                      'Tên ví',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        hintText: 'VD: Ví cá nhân, Quỹ tiêu vặt...',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    // Initial Balance Field
                    const Text(
                      'Số dư ban đầu',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: balanceCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [MoneyTextInputFormatter()],
                      decoration: const InputDecoration(
                        hintText: 'VD: 0',
                        suffixText: 'đ',
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 24),
                    // Buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, {'name': 'Ví cá nhân', 'balance': 0}),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.teal),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                            ),
                            child: const Text('Bỏ qua', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              final name = nameCtrl.text.trim();
                              final rawBal = balanceCtrl.text.trim().replaceAll(',', '');
                              final bal = int.tryParse(rawBal) ?? 0;
                              Navigator.pop(ctx, {
                                'name': name.isNotEmpty ? name : 'Ví cá nhân',
                                'balance': bal,
                              });
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                            ),
                            child: const Text('Lưu & Bắt đầu', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    final config = walletConfig ?? {'name': 'Ví cá nhân', 'balance': 0};

    setState(() => _saving = true);
    try {
      await _api.updateSettings({
        if (_selectedAge != null) 'ageGroup': _selectedAge,
        if (_selectedJob != null) 'jobType': _selectedJob,
      });

      final wallets = await _api.getWallets();
      Map<String, dynamic>? personalWallet;
      for (final w in wallets) {
        if (w is Map<String, dynamic> && w['type'] == 'personal') {
          personalWallet = w;
          break;
        }
      }

      if (personalWallet != null) {
        final walletId = personalWallet['id'] as String;
        await _api.updateWallet(walletId, {
          'name': config['name'] as String,
        });
        final balance = config['balance'] as int;
        if (balance > 0) {
          await _api.createTransaction({
            'walletId': walletId,
            'amount': balance,
            'type': 'income',
            'categoryCode': 'Others',
            'note': 'Số dư ban đầu',
            'source': 'manual',
          });
        }
      } else {
        await _api.createWallet({
          'name': config['name'] as String,
          'type': 'personal',
          'currency': 'VND',
          'icon': '💼',
          'color': '#14B8A6',
          'balance': config['balance'] as int,
        });
      }

      if (mounted) context.go(AppRoutes.home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: AppGradients.teal),
            child: SafeArea(
              child: Column(
                children: [
                  const _ProgressHeader(label: 'Bước 4/4', percent: '100%', value: 1.0),
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
                    nextLabel: 'Hoàn thành 🎉',
                  ),
                ],
              ),
            ),
          ),
          if (_saving)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.teal),
              ),
            ),
        ],
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
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
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