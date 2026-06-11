import 'package:cached_query/cached_query.dart';

import 'api_client.dart';

/// Lớp truy vấn có cache (cached_query) cho dữ liệu dùng chung.
///
/// Mục đích: tránh tải lại từ đầu mỗi lần chuyển màn hình. Dữ liệu được cache
/// trong bộ nhớ; khi còn "tươi" (trong [QueryConfig.refetchDuration]) sẽ trả về
/// ngay lập tức, khi đã cũ sẽ tự refetch nền để giữ đồng bộ.
class AppQueries {
  AppQueries._();

  static final ApiClient _api = ApiClient();

  static Query<Map<String, dynamic>> me() =>
      Query<Map<String, dynamic>>(key: 'me', queryFn: () => _api.getMe());

  static Query<List<dynamic>> wallets() =>
      Query<List<dynamic>>(key: 'wallets', queryFn: () => _api.getWallets());

  static Query<Map<String, dynamic>> streak() =>
      Query<Map<String, dynamic>>(key: 'streak', queryFn: () => _api.getStreak());

  static Query<Map<String, dynamic>> dashboard(String? walletId, {String? from, String? to}) =>
      Query<Map<String, dynamic>>(
        key: 'dashboard:${walletId ?? 'all'}:${from ?? 'default'}:${to ?? 'default'}',
        queryFn: () => _api.getDashboard(walletId: walletId, from: from, to: to),
      );

  static Query<Map<String, dynamic>> transactions(String? walletId, {int pageSize = 50}) =>
      Query<Map<String, dynamic>>(
        key: 'transactions:${walletId ?? 'all'}:$pageSize',
        queryFn: () => _api.getTransactions(walletId: walletId, pageSize: pageSize),
      );

  static Query<List<dynamic>> stories(String? walletId) =>
      Query<List<dynamic>>(
        key: 'stories:${walletId ?? 'all'}',
        queryFn: () => _api.getStories(walletId: walletId),
      );

  static Query<List<dynamic>> statsByCategory(String? range, String? walletId, {String? from, String? to}) =>
      Query<List<dynamic>>(
        key: 'statsCategory:${range ?? 'all'}:${walletId ?? 'all'}:${from ?? 'default'}:${to ?? 'default'}',
        queryFn: () => _api.getStatsByCategory(range: range, walletId: walletId, from: from, to: to),
      );

  static Query<List<dynamic>> statsByMonth(int year, String? walletId) =>
      Query<List<dynamic>>(
        key: 'statsMonth:$year:${walletId ?? 'all'}',
        queryFn: () => _api.getStatsByMonth(year: year, walletId: walletId),
      );

  static Query<List<dynamic>> statsMoM(String? walletId) =>
      Query<List<dynamic>>(
        key: 'statsMoM:${walletId ?? 'all'}',
        queryFn: () => _api.getStatsMoM(walletId: walletId),
      );

  static Query<Map<String, dynamic>> statsCumulativeVsBudget(String? walletId) =>
      Query<Map<String, dynamic>>(
        key: 'statsCumulativeVsBudget:${walletId ?? 'all'}',
        queryFn: () => _api.getStatsCumulativeVsBudget(walletId: walletId),
      );

  /// Khi có thay đổi giao dịch → đánh dấu các query liên quan là stale để refetch.
  static void invalidateWalletData() {
    CachedQuery.instance.invalidateCache(
      filterFn: (_, key) =>
          key.contains('dashboard') ||
          key.contains('transactions') ||
          key.contains('stories') ||
          key.contains('stats') ||
          key.contains('streak') ||
          key.contains('wallets'),
    );
  }

  /// Xoá toàn bộ cache (dùng khi đăng xuất).
  static void clearAll() => CachedQuery.instance.deleteCache();
}
