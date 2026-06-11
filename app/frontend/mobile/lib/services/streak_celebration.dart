import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lottie/lottie.dart';

import 'api_client.dart';
import 'app_queries.dart';
import 'transaction_notifier.dart';

/// Kiểm tra streak sau chat / addStory và khi mở app (mất chuỗi).
class StreakCelebration {
  StreakCelebration._();
  static final StreakCelebration instance = StreakCelebration._();
  static const _storage = FlutterSecureStorage();
  static const _keyStreak = 'streak_last_count';
  static const _keyDate = 'streak_last_activity';

  Future<void> persistSnapshot(int streak, String? lastDate) async {
    await _storage.write(key: _keyStreak, value: '$streak');
    if (lastDate != null) await _storage.write(key: _keyDate, value: lastDate);
  }

  Future<int?> _readLastStreak() async {
    final s = await _storage.read(key: _keyStreak);
    return s != null ? int.tryParse(s) : null;
  }

  /// Gọi sau khi gửi chat hoặc lưu giao dịch — nếu streak tăng thì chúc mừng.
  Future<void> afterActivity(BuildContext context) async {
    final prev = await _readLastStreak();
    try {
      final data = await ApiClient().getStreak();
      final cur = (data['currentStreak'] as num?)?.toInt() ?? 0;
      final lastDate = data['lastActivityDate'] as String?;
      await persistSnapshot(cur, lastDate);
      AppQueries.invalidateWalletData();
      notifyTransactionChanged();
      if (!context.mounted) return;
      if (prev != null && cur > prev) {
        await _showCelebrate(context, cur);
      }
    } catch (_) {}
  }

  /// Gọi khi vào home sau splash — streak về 0 sau khi từng > 0.
  Future<void> checkBrokenOnLaunch(BuildContext context) async {
    final prev = await _readLastStreak();
    try {
      final data = await ApiClient().getStreak();
      final cur = (data['currentStreak'] as num?)?.toInt() ?? 0;
      final lastDate = data['lastActivityDate'] as String?;
      if (!context.mounted) return;
      if (prev != null && prev > 0 && cur == 0) {
        await _showBroken(context);
      }
      await persistSnapshot(cur, lastDate);
    } catch (_) {}
  }

  Future<void> _showCelebrate(BuildContext context, int days) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'streak',
      barrierColor: Colors.black54,
      pageBuilder: (ctx, _, _) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: Lottie.asset('assets/animations/Fire.json', repeat: false),
                ),
                Image.asset('assets/MiMo/emotions/Celebrate.png', width: 64, height: 64,
                  errorBuilder: (_, e, s) => const Text('🎉', style: TextStyle(fontSize: 48))),
                const SizedBox(height: 12),
                Text('Chuỗi $days ngày!', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Tiếp tục chat hoặc ghi chi tiêu mỗi ngày nhé', textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Tuyệt vời!')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showBroken(BuildContext context) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'streak-broken',
      barrierColor: Colors.black54,
      pageBuilder: (ctx, _, _) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/MiMo/emotions/Sad.png', width: 72, height: 72,
                  errorBuilder: (_, e, s) => const Text('😢', style: TextStyle(fontSize: 48))),
                const SizedBox(height: 12),
                Text('Chuỗi đã dừng', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Bạn đã bỏ lỡ một ngày — bắt đầu lại từ hôm nay nhé!', textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
