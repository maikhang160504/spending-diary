import 'package:flutter/material.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_spacing.dart';
import '../../utils/formatters.dart';
import 'loan_form_screen.dart';

class LoansScreen extends StatefulWidget {
  const LoansScreen({super.key});

  @override
  State<LoansScreen> createState() => _LoansScreenState();
}

class _LoansScreenState extends State<LoansScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _api = ApiClient();
  List<dynamic> _loans = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  Future<void> _loadLoans() async {
    try {
      final res = await _api.getLoans();
      if (mounted) {
        setState(() {
          _loans = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải danh sách khoản vay/mượn';
          _loading = false;
        });
      }
    }
  }

  Future<void> _showCreateLoan() async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoanFormScreen()),
    );
    if (res == true) {
      _loadLoans();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.danger)),
            TextButton(onPressed: _loadLoans, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: Navigator.canPop(context)
          ? AppBar(
              backgroundColor: context.palette.card,
              elevation: 0,
              centerTitle: false,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Text(
                'Vay mượn',
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
            )
          : null,
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateLoan,
        backgroundColor: AppColors.teal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loans.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.handshake_outlined,
                    size: 68,
                    color: context.palette.muted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có khoản vay mượn nào',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: context.palette.textSecondary,
                        ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
        onRefresh: _loadLoans,
        child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _loans.length,
        separatorBuilder: (context, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final loan = _loans[index];
          final isLend = loan['type'] == 'lend';
          final amount = num.parse(loan['amount'].toString());
          final paidAmount = num.parse(loan['paid_amount'].toString());
          final remaining = amount - paidAmount;

          final contactName = loan['contact_name']?.toString() ?? 'Ai đó';
          final dt = loan['due_date'] != null ? DateTime.tryParse(loan['due_date'].toString())?.toLocal() : null;
          final dueDateStr = dt != null ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}' : '';

          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: context.palette.softShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isLend ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLend ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                    color: isLend ? AppColors.success : AppColors.danger,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLend ? 'Cho $contactName vay' : 'Vay của $contactName',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: context.palette.textPrimary,
                        ),
                      ),
                      if (dueDateStr.isNotEmpty)
                        Text(
                          'Hạn trả: $dueDateStr',
                          style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                        ),
                    ],
                  ),
                ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: context.palette.textSecondary),
                    onSelected: (value) async {
                      if (value == 'pay') {
                        await _api.updateLoan(loan['id'].toString(), {'paid_amount': amount, 'status': 'paid'});
                        _loadLoans();
                      } else if (value == 'delete') {
                        await _api.deleteLoan(loan['id'].toString());
                        _loadLoans();
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'pay', child: Text('Đã thanh toán')),
                      const PopupMenuItem(value: 'delete', child: Text('Xóa khoản vay')),
                    ],
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatVnd(remaining.toInt()),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isLend ? AppColors.success : AppColors.danger,
                      ),
                    ),
                    if (paidAmount > 0)
                      Text(
                        'Đã trả: ${formatVnd(paidAmount.toInt())}',
                        style: TextStyle(fontSize: 12, color: context.palette.textSecondary),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}
