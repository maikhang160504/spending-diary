import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/categories.dart';
import '../routes/app_routes.dart';

/// Kiểm tra xem danh mục chi tiêu có hạn mức chưa.
/// Nếu chưa, hiển thị modal gợi ý người dùng tạo hạn mức.
Future<void> checkCategoryLimitAndSuggest(BuildContext context, String categoryCode) async {
  // Bỏ qua các danh mục thu nhập (Income) hoặc danh mục khác không cần hạn mức
  final lower = categoryCode.toLowerCase();
  if (lower == 'salary' ||
      lower == 'bonus' ||
      lower == 'business' ||
      lower == 'other' ||
      lower == 'others') {
    return;
  }

  try {
    final api = ApiClient();
    final budgets = await api.getBudgets();
    
    // Chuẩn hóa mã danh mục để so sánh chính xác
    final canonicalTarget = CategoryTheme.canonicalCodeOf(categoryCode);
    final hasLimit = budgets.any((b) {
      final rawCat = b['categoryCode'] as String? ?? b['category_code'] as String? ?? '';
      return CategoryTheme.canonicalCodeOf(rawCat) == canonicalTarget;
    });

    if (!hasLimit && context.mounted) {
      final style = CategoryTheme.of(categoryCode);
      showDialog(
        context: context,
        useRootNavigator: true,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              CategoryTheme.iconOf(categoryCode, size: 24),
              const SizedBox(width: 8),
              Flexible(
                child: Text('Hạn mức chi tiêu', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Text(
            'Bạn vừa thêm giao dịch thuộc danh mục "${style.label}" nhưng chưa thiết lập hạn mức chi tiêu. Bạn có muốn thiết lập ngay không?',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: const Text('Bỏ qua', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx, rootNavigator: true).pop();
                context.push('${AppRoutes.limits}?categoryCode=$categoryCode');
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Thiết lập ngay'),
            ),
          ],
        ),
      );
    }
  } catch (_) {
    // Thất bại trong âm thầm để không ảnh hưởng đến trải nghiệm người dùng
  }
}
