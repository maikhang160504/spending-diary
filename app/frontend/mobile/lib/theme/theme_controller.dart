import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Quản lý chế độ sáng/tối và lưu lựa chọn của người dùng.
///
/// Dùng [FlutterSecureStorage] (đã có sẵn cho auth) để khỏi thêm dependency.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  static const _key = 'theme_mode';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Đọc lựa chọn đã lưu (gọi 1 lần lúc khởi động).
  Future<void> load() async {
    try {
      final saved = await _storage.read(key: _key);
      _mode = _parse(saved);
      notifyListeners();
    } catch (_) {
      // Bỏ qua lỗi đọc storage — dùng mặc định theo hệ thống.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      await _storage.write(key: _key, value: mode.name);
    } catch (_) {}
  }

  ThemeMode _parse(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
