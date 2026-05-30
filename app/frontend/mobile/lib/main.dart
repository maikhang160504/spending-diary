import 'package:cached_query/cached_query.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cấu hình cache chung cho cached_query: giữ dữ liệu "tươi" 30s (không refetch),
  // và giữ trong bộ nhớ 10 phút sau khi không còn listener → chuyển màn hình
  // quay lại không phải tải lại từ đầu.
  CachedQuery.instance.config(
    config: QueryConfig(
      refetchDuration: const Duration(seconds: 30),
      cacheDuration: const Duration(minutes: 10),
    ),
  );
  // Đọc lựa chọn sáng/tối đã lưu trước khi dựng UI.
  await ThemeController.instance.load();
  runApp(const SpendDiaryApp());
}
