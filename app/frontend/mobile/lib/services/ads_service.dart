import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// AdsService — Singleton quản lý logic Mock Ads cho người dùng Free.
///
/// Cách dùng:
///   // Sau mỗi lần thêm giao dịch thành công:
///   final showAd = AdsService.instance.incrementAndCheck();
///   if (showAd) { /* hiển thị Interstitial Ad */ }
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  int _actionCount = 0;

  /// Số hành động trước khi trigger quảng cáo
  static const int _triggerThreshold = 5;

  /// Tăng bộ đếm và kiểm tra xem có nên hiện quảng cáo không.
  /// Trả về `true` nếu đã đủ ngưỡng (actionCount == threshold).
  bool incrementAndCheck() {
    _actionCount++;
    if (_actionCount >= _triggerThreshold) {
      return true;
    }
    return false;
  }

  /// Reset bộ đếm về 0 (gọi sau khi đóng popup Premium upsell).
  void reset() {
    _actionCount = 0;
    resetTime();
  }

  // Timer logic
  Timer? _usageTimer;
  int _usageSeconds = 0;
  static const int _timeThreshold = 600; // 10 minutes
  
  final _adTriggerController = StreamController<void>.broadcast();
  Stream<void> get onAdTriggered => _adTriggerController.stream;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _usageSeconds = prefs.getInt('ads_usage_seconds') ?? 0;
    _startUsageTimer();
  }

  void _startUsageTimer() {
    _usageTimer?.cancel();
    _usageTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (_isPremium) return;
      _usageSeconds += 10;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('ads_usage_seconds', _usageSeconds);
      
      if (_usageSeconds >= _timeThreshold) {
        _adTriggerController.add(null);
      }
    });
  }

  Future<void> resetTime() async {
    _usageSeconds = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ads_usage_seconds', 0);
  }

  void triggerTestAd() {
    _adTriggerController.add(null);
  }

  /// Số hành động hiện tại (dùng để debug).
  int get actionCount => _actionCount;

  /// Kiểm tra xem có nên disable ads (user Premium).
  bool _isPremium = false;

  void setPremium(bool value) {
    _isPremium = value;
    if (value) reset(); // Premium users không cần đếm
  }

  bool get isPremium => _isPremium;

  /// Convenience: tăng đếm nhưng nếu là Premium thì luôn trả false
  bool incrementAndCheckIfNotPremium() {
    if (_isPremium) return false;
    return incrementAndCheck();
  }
}
