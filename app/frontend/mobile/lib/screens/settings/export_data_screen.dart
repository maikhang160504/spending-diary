import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';
import '../../theme/categories.dart';
import '../../utils/formatters.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  final _api = ApiClient();

  String _timeFilter = 'all'; // all, month, 3m, 6m, year, custom
  DateTime? _customFrom;
  DateTime? _customTo;

  String _typeFilter = 'all'; // all, expense, income
  String _categoryFilter = 'all'; // all or canonical code

  bool _loading = false;
  List<Map<String, dynamic>> _transactions = [];
  int _totalExpense = 0;
  int _totalIncome = 0;


  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _loading = true;
    });

    try {
      // ─── Build time range for API ────────────────────────────────────
      String? fromStr;
      String? toStr;
      final now = DateTime.now();

      if (_timeFilter == 'month') {
        final from = DateTime(now.year, now.month, 1);
        fromStr = from.toUtc().toIso8601String();
        toStr = DateTime(now.year, now.month + 1, 0, 23, 59, 59).toUtc().toIso8601String();
      } else if (_timeFilter == '3m') {
        fromStr = DateTime(now.year, now.month - 3, now.day).toUtc().toIso8601String();
        toStr = now.toUtc().toIso8601String();
      } else if (_timeFilter == '6m') {
        fromStr = DateTime(now.year, now.month - 6, now.day).toUtc().toIso8601String();
        toStr = now.toUtc().toIso8601String();
      } else if (_timeFilter == 'year') {
        fromStr = DateTime(now.year, 1, 1).toUtc().toIso8601String();
        toStr = DateTime(now.year, 12, 31, 23, 59, 59).toUtc().toIso8601String();
      } else if (_timeFilter == 'custom') {
        if (_customFrom != null) {
          fromStr = _customFrom!.toUtc().toIso8601String();
        }
        if (_customTo != null) {
          toStr = _customTo!.add(const Duration(hours: 23, minutes: 59, seconds: 59)).toUtc().toIso8601String();
        }
      }
      // 'all' → no from/to filter

      // ─── Pass filters directly to API (server-side) ──────────────────
      final res = await _api.getTransactions(
        pageSize: 2000,
        type: _typeFilter == 'all' ? null : _typeFilter,
        categoryCode: _categoryFilter == 'all' ? null : _categoryFilter,
        from: fromStr,
        to: toStr,
      );

      final rawList = res['data'] is Map
          ? (res['data']['items'] as List? ?? [])
          : (res['items'] as List? ?? []);

      final List<Map<String, dynamic>> allTx = rawList.map((e) {
        if (e is Map<String, dynamic>) return e;
        if (e is Map) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();

      int exp = 0;
      int inc = 0;
      for (final t in allTx) {
        final amt = (t['amount'] as num? ?? 0).toInt();
        final type = (t['type'] ?? '').toString().toLowerCase();
        if (type == 'expense') {
          exp += amt;
        } else if (type == 'income') {
          inc += amt;
        }
      }

      if (mounted) {
        setState(() {
          _transactions = allTx;
          _totalExpense = exp;
          _totalIncome = inc;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customFrom != null && _customTo != null
          ? DateTimeRange(start: _customFrom!, end: _customTo!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.teal,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _timeFilter = 'custom';
        _customFrom = picked.start;
        _customTo = picked.end;
      });
      _fetchTransactions();
    }
  }

  Future<void> _exportToCsv() async {
    if (_transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có giao dịch nào khớp bộ lọc để xuất!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    try {
      final buffer = StringBuffer();
      // BOM cho UTF-8 Excel tiếng Việt
      buffer.write('\uFEFF');
      buffer.writeln('Mã giao dịch,Ngày giờ,Loại,Danh mục,Số tiền (VNĐ),Ghi chú');

      for (final tx in _transactions) {
        final id = tx['id']?.toString() ?? '';
        final occurred = tx['occurredAt']?.toString() ?? '';
        final formattedDate = occurred.isNotEmpty
            ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.tryParse(occurred) ?? DateTime.now())
            : '';
        final typeRaw = (tx['type'] ?? '').toString().toLowerCase();
        final typeStr = typeRaw == 'income' ? 'Thu nhập' : 'Chi tiêu';
        final catCode = (tx['categoryCode'] ?? 'Other').toString();
        final style = CategoryTheme.of(catCode);
        final catLabel = style.label;
        final amount = (tx['amount'] as num? ?? 0).toInt();
        final note = (tx['note'] ?? '').toString().replaceAll('"', '""');

        buffer.writeln('"$id","$formattedDate","$typeStr","$catLabel",$amount,"$note"');
      }

      final dir = await getApplicationDocumentsDirectory();
      final nowStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final file = File('${dir.path}/SpendingDiary_Export_$nowStr.csv');
      await file.writeAsString(buffer.toString(), encoding: utf8);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: AppColors.teal, size: 28),
                SizedBox(width: 10),
                Expanded(child: Text('Xuất dữ liệu thành công')),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Đã xuất thành công ${_transactions.length} giao dịch sang tệp CSV.'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    file.path,
                    style: const TextStyle(fontSize: 12, color: AppColors.teal),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  OpenFilex.open(file.path);
                },
                child: const Text('Mở tệp', style: TextStyle(color: AppColors.teal)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // ignore: deprecated_member_use
                  Share.shareXFiles([XFile(file.path)], text: 'Dữ liệu Sổ thu chi');
                },
                child: const Text('Chia sẻ', style: TextStyle(color: AppColors.teal)),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xuất tệp: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: const Text('Xuất dữ liệu chi tiêu'),
        backgroundColor: palette.card,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.teal, Color(0xFF0F766E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        boxShadow: palette.softShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.file_download_outlined,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tùy chỉnh bộ lọc xuất tệp',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Xuất tệp CSV / Excel chuẩn tiếng Việt theo nhu cầu',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bộ lọc Thời gian
                    Text(
                      'Thời gian',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildChip('Tất cả', 'all', _timeFilter, (v) {
                          setState(() => _timeFilter = v);
                          _fetchTransactions();
                        }),
                        _buildChip('Tháng này', 'month', _timeFilter, (v) {
                          setState(() => _timeFilter = v);
                          _fetchTransactions();
                        }),
                        _buildChip('3 tháng qua', '3m', _timeFilter, (v) {
                          setState(() => _timeFilter = v);
                          _fetchTransactions();
                        }),
                        _buildChip('6 tháng qua', '6m', _timeFilter, (v) {
                          setState(() => _timeFilter = v);
                          _fetchTransactions();
                        }),
                        _buildChip(
                          _timeFilter == 'custom' && _customFrom != null && _customTo != null
                              ? '${DateFormat('dd/MM').format(_customFrom!)} - ${DateFormat('dd/MM').format(_customTo!)}'
                              : 'Tùy chọn ngày',
                          'custom',
                          _timeFilter,
                          (_) => _pickCustomDateRange(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Bộ lọc Loại giao dịch
                    Text(
                      'Loại giao dịch',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildChip('Tất cả', 'all', _typeFilter, (v) {
                          setState(() => _typeFilter = v);
                          _fetchTransactions();
                        }),
                        _buildChip('Chi tiêu', 'expense', _typeFilter, (v) {
                          setState(() => _typeFilter = v);
                          _fetchTransactions();
                        }),
                        _buildChip('Thu nhập', 'income', _typeFilter, (v) {
                          setState(() => _typeFilter = v);
                          _fetchTransactions();
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Bộ lọc Danh mục
                    Text(
                      'Danh mục',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: palette.card,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: palette.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _categoryFilter,
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('Tất cả danh mục'),
                            ),
                            ...CategoryTheme.styles.keys.map((code) {
                              final style = CategoryTheme.of(code);
                              return DropdownMenuItem(
                                value: code,
                                child: Text('${style.emoji}  ${style.label}'),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _categoryFilter = val);
                              _fetchTransactions();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Preview Tóm tắt
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.card,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(color: palette.border),
                      ),
                      child: _loading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20),
                                child: CircularProgressIndicator(color: AppColors.teal),
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Kết quả lọc:',
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '${_transactions.length} giao dịch',
                                      style: const TextStyle(
                                        color: AppColors.teal,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildSummaryBox(
                                        'Tổng chi',
                                        '-${formatVnd(_totalExpense)}đ',
                                        AppColors.danger,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildSummaryBox(
                                        'Tổng thu',
                                        '+${formatVnd(_totalIncome)}đ',
                                        AppColors.teal,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: palette.card,
                boxShadow: palette.softShadow,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  onPressed: _loading || _transactions.isEmpty ? null : _exportToCsv,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                  ),
                  icon: const Icon(Icons.file_download),
                  label: const Text(
                    'Xuất tệp CSV / Excel',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, String val, String selectedVal, Function(String) onTap) {
    final isSelected = val == selectedVal;
    return InkWell(
      onTap: () => onTap(val),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.teal : context.palette.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.teal : context.palette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBox(String label, String valStr, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(
            valStr,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
