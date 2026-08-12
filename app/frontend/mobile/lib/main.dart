import 'package:cached_query/cached_query.dart';
import 'package:cached_storage/cached_storage.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cấu hình cache chung cho cached_query: giữ dữ liệu "tươi" 30s (không refetch),
  // và giữ trong bộ nhớ lâu hơn để không bị mất.
  CachedQuery.instance.config(
    storage: await CachedStorage.ensureInitialized(),
    config: QueryConfig(
      refetchDuration: const Duration(
        days: 1,
      ), // Chỉ tự động tải lại nếu cache quá 1 ngày (hoặc có trigger)
      cacheDuration: const Duration(days: 7),
    ),
  );
  // Đọc lựa chọn sáng/tối đã lưu trước khi dựng UI.
  await ThemeController.instance.load();
  runApp(const SpendDiaryApp());
}
