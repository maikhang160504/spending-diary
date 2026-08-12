import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/image_compressor.dart';
import 'connection_manager.dart';
import 'streak_celebration.dart';
import '../routes/app_routes.dart';

/// Centralized API client for all backend calls.
/// Replaces old `BackendApiService` with proper JWT auth flow.
class ApiClient {
  static const _defaultBaseUrl = 'http://10.0.2.2:4000';

  final String baseUrl;
  final FlutterSecureStorage _storage;
  final http.Client _http;
  static Future<bool>? _refreshFuture;

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    return trimmed.endsWith('/api/v1') ? trimmed : '$trimmed/api/v1';
  }

  static bool? _isOnboardingBypassed;
  static String? lastSelectedWalletId;

  ApiClient({
    String? baseUrl,
    FlutterSecureStorage? storage,
    http.Client? httpClient,
  }) : baseUrl = _normalizeBaseUrl(
         baseUrl ??
             const String.fromEnvironment(
               'API_BASE_URL',
               defaultValue: _defaultBaseUrl,
             ),
       ),
       _storage = storage ?? const FlutterSecureStorage(),
       _http = httpClient ?? http.Client();

  // â”€â”€â”€ Token Management â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<String?> get accessToken => _storage.read(key: 'access_token');
  Future<String?> get refreshToken => _storage.read(key: 'refresh_token');

  Future<void> _saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
    try {
      await StreakCelebration.instance.reset();
    } catch (_) {}
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    try {
      await StreakCelebration.instance.reset();
    } catch (_) {}
  }

  Future<bool> get isLoggedIn async => (await accessToken) != null;

  // â”€â”€â”€ HTTP Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<Map<String, String>> _authHeaders() async {
    final token = await accessToken;
    return {
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
    bool requireAuth = true,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: queryParams);
    final headers = requireAuth
        ? await _authHeaders()
        : {'Content-Type': 'application/json; charset=utf-8'};

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _http.get(uri, headers: headers);
          break;
        case 'POST':
          response = await _http.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PATCH':
          response = await _http.patch(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await _http.delete(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        default:
          throw UnsupportedError('HTTP method $method not supported');
      }
    } catch (e) {
      ConnectionManager.instance.setLost(true);
      rethrow;
    }

    // Handle 401 â€” try refresh
    if (response.statusCode == 401 && requireAuth) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _request(
          method,
          path,
          body: body,
          queryParams: queryParams,
          requireAuth: true,
        );
      }
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final Map<String, dynamic> jsonBody = decoded is List
        ? {'success': true, 'data': decoded}
        : (decoded as Map<String, dynamic>);

    if (response.statusCode >= 400) {
      final errMap = jsonBody['error'] as Map<String, dynamic>?;
      final errorMessage =
          errMap?['message'] as String? ??
          jsonBody['message'] as String? ??
          'Request failed';

      // Handle User Banned
      if (response.statusCode == 403 &&
          errorMessage.toLowerCase().contains('banned')) {
        appRouter.go(AppRoutes.banned, extra: errorMessage);
        // We throw so it doesn't return data, but we DO NOT clearTokens() so they can appeal.
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // Other unhandled auth errors might clear token, but for now we let tryRefresh handle it.
      }

      throw ApiException(
        statusCode: response.statusCode,
        message: errorMessage,
        code: errMap?['code'] as String? ?? jsonBody['code'] as String?,
      );
    }

    return jsonBody;
  }

  Future<bool> _tryRefresh() async {
    if (_refreshFuture != null) {
      return _refreshFuture!;
    }
    _refreshFuture = _doRefresh();
    try {
      return await _refreshFuture!;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<bool> _doRefresh() async {
    final rToken = await refreshToken;
    if (rToken == null) return false;

    try {
      final response = await _http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': rToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'] as Map<String, dynamic>;
        await _saveTokens(data['accessToken'], data['refreshToken']);
        return true;
      }

      // Chỉ xóa token nếu server phản hồi lỗi xác thực rõ ràng
      if (response.statusCode == 400 ||
          response.statusCode == 401 ||
          response.statusCode == 403) {
        await clearTokens();
      }
    } catch (_) {
      // Bỏ qua lỗi kết nối (SocketException/Timeout) để không tự động logout khi mất mạng
    }

    return false;
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<Map<String, dynamic>> login(String email, String password) async {
    _isOnboardingBypassed = null;
    final result = await _request(
      'POST',
      '/auth/login',
      body: {'email': email, 'password': password},
      requireAuth: false,
    );
    final data = result['data'] as Map<String, dynamic>;
    await _saveTokens(data['accessToken'], data['refreshToken']);
    return data;
  }

  Future<Map<String, dynamic>> loginWithGoogle(String idToken) async {
    _isOnboardingBypassed = null;
    final result = await _request(
      'POST',
      '/auth/google',
      body: {'idToken': idToken},
      requireAuth: false,
    );
    final data = result['data'] as Map<String, dynamic>;
    await _saveTokens(data['accessToken'], data['refreshToken']);
    return data;
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String username,
  ) async {
    _isOnboardingBypassed = null;
    final result = await _request(
      'POST',
      '/auth/register',
      body: {'email': email, 'password': password, 'username': username},
      requireAuth: false,
    );
    final data = result['data'] as Map<String, dynamic>;
    await _saveTokens(data['accessToken'], data['refreshToken']);
    return data;
  }

  Future<Map<String, dynamic>> submitAppeal(String reason) async {
    final result = await _request(
      'POST',
      '/auth/appeals',
      body: {'reason': reason},
      requireAuth: true,
    );
    return result;
  }

  Future<Map<String, dynamic>?> getAppealStatus() async {
    try {
      final result = await _request(
        'GET',
        '/auth/appeals/status',
        requireAuth: true,
      );
      return result['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    final result = await _request('GET', '/auth/me');
    return result['data'] as Map<String, dynamic>;
  }

  Future<void> logout() async {
    _isOnboardingBypassed = null;
    final rToken = await refreshToken;
    if (rToken != null) {
      try {
        await _request('POST', '/auth/logout', body: {'refreshToken': rToken});
      } catch (_) {}
    }
    await clearTokens();
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _request(
      'POST',
      '/auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<void> forgotPassword(String email) async {
    await _request(
      'POST',
      '/auth/forgot-password',
      body: {'email': email},
      requireAuth: false,
    );
  }

  Future<Map<String, dynamic>> verifyResetOtp(String email, String otp) async {
    final result = await _request(
      'POST',
      '/auth/verify-reset-otp',
      body: {'email': email, 'otp': otp},
      requireAuth: false,
    );
    return result['data'] as Map<String, dynamic>;
  }

  Future<void> resetPassword(String resetToken, String newPassword) async {
    await _request(
      'POST',
      '/auth/reset-password',
      body: {'resetToken': resetToken, 'newPassword': newPassword},
      requireAuth: false,
    );
  }

  Future<Map<String, dynamic>> getStreak() async {
    final result = await _request('GET', '/users/me/streak');
    return result['data'] as Map<String, dynamic>;
  }

  Future<void> registerFcmToken(String token, String platform) async {
    await _request(
      'POST',
      '/users/me/fcm/token',
      body: {'token': token, 'platform': platform},
    );
  }

  Future<void> removeFcmToken(String token) async {
    await _request('DELETE', '/users/me/fcm/token', body: {'token': token});
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<List<dynamic>> getWallets() async {
    final result = await _request('GET', '/wallets');
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getWallet(String id) async {
    final result = await _request('GET', '/wallets/$id');
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createWallet(Map<String, dynamic> body) async {
    final result = await _request('POST', '/wallets', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateWallet(
    String id,
    Map<String, dynamic> body,
  ) async {
    final result = await _request('PATCH', '/wallets/$id', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<void> deleteWallet(String id) async {
    await _request('DELETE', '/wallets/$id');
  }

  Future<void> leaveWallet(String id) async {
    await _request('POST', '/wallets/$id/leave');
  }

  Future<Map<String, dynamic>> generateWalletInviteCode(String walletId) async {
    final result = await _request('POST', '/wallets/$walletId/generate-code');
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinWalletByCode(String code) async {
    final result = await _request(
      'POST',
      '/wallets/join',
      body: {'code': code},
    );
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> transferBetweenWallets({
    required String fromWalletId,
    required String toWalletId,
    required int amount,
  }) async {
    final result = await _request(
      'POST',
      '/wallets/transfer',
      body: {
        'fromWalletId': fromWalletId,
        'toWalletId': toWalletId,
        'amount': amount,
      },
    );
    return result['data'] as Map<String, dynamic>;
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<List<dynamic>> getCategories() async {
    final result = await _request('GET', '/categories');
    return result['data'] as List<dynamic>;
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<Map<String, dynamic>> getTransactions({
    String? walletId,
    String? type,
    String? categoryCode,
    int pageSize = 20,
    int page = 1,
    String? from,
    String? to,
  }) async {
    final result = await _request(
      'GET',
      '/transactions',
      queryParams: {
        if (walletId != null) 'walletId': walletId,
        if (type != null) 'type': type,
        if (categoryCode != null) 'categoryCode': categoryCode,
        'pageSize': '$pageSize',
        'page': '$page',
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
    );
    return result;
  }

  Future<Map<String, dynamic>> getTransaction(String id) async {
    final result = await _request('GET', '/transactions/$id');
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createTransaction(
    Map<String, dynamic> body,
  ) async {
    final result = await _request('POST', '/transactions', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTransaction(
    String id,
    Map<String, dynamic> body,
  ) async {
    final result = await _request('PATCH', '/transactions/$id', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<void> deleteTransaction(String id) async {
    await _request('DELETE', '/transactions/$id');
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<Map<String, dynamic>> getDashboard({
    String? walletId,
    String? from,
    String? to,
  }) async {
    final result = await _request(
      'GET',
      '/stats/dashboard',
      queryParams: {
        if (walletId != null) 'walletId': walletId,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
      },
    );
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPeerCompare({String? month}) async {
    final result = await _request(
      'GET',
      '/stats/peer-compare',
      queryParams: {if (month != null) 'month': month},
    );
    return result['data'] as Map<String, dynamic>;
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<List<dynamic>> getBudgets() async {
    final result = await _request('GET', '/budgets/summary');
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getBudgetSummary() async {
    final result = await _request('GET', '/budgets/summary');
    return result;
  }

  Future<bool> checkOnboardingBypassed() async {
    if (_isOnboardingBypassed == true) return true;
    try {
      final settings = await getSettings();
      final ageGroup =
          settings['ageGroup'] as String? ?? settings['age_group'] as String?;
      final jobType =
          settings['jobType'] as String? ?? settings['job_type'] as String?;
      if ((ageGroup != null && ageGroup.isNotEmpty) ||
          (jobType != null && jobType.isNotEmpty)) {
        _isOnboardingBypassed = true;
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<Map<String, dynamic>> createBudget(Map<String, dynamic> body) async {
    final result = await _request('POST', '/budgets', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateBudget(
    String id,
    Map<String, dynamic> body,
  ) async {
    final result = await _request('PATCH', '/budgets/$id', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<List<dynamic>> getGoals([String? type]) async {
    final path = type != null ? '/goals?type=' : '/goals';
    final result = await _request('GET', path);
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getGoal(String id) async {
    final result = await _request('GET', '/goals/$id');
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createGoal(Map<String, dynamic> body) async {
    final result = await _request('POST', '/goals', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateGoal(
    String id,
    Map<String, dynamic> body,
  ) async {
    final result = await _request('PATCH', '/goals/$id', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> contributeGoal(String id, double amount) async {
    final result = await _request(
      'POST',
      '/goals/$id/contribute',
      body: {'amount': amount},
    );
    return result['data'] as Map<String, dynamic>;
  }

  Future<void> deleteGoal(String id) async {
    await _request('DELETE', '/goals/$id');
  }

  Future<void> leaveGoal(String id) async {
    await _request('POST', '/goals/$id/leave');
  }

  Future<String> inviteGoal(String id) async {
    final result = await _request('POST', '/goals/$id/invite');
    final data = result['data'] as Map<String, dynamic>;
    return data['inviteCode'] as String;
  }

  Future<Map<String, dynamic>> joinGoal(String inviteCode) async {
    final result = await _request(
      'POST',
      '/goals/join',
      body: {'inviteCode': inviteCode},
    );
    return result['data'] as Map<String, dynamic>;
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<List<dynamic>> getRecurringRules() async {
    final result = await _request('GET', '/recurring');
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createRecurringRule(
    Map<String, dynamic> body,
  ) async {
    final result = await _request('POST', '/recurring', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateRecurringRule(
    String id,
    Map<String, dynamic> body,
  ) async {
    final result = await _request('PATCH', '/recurring/$id', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<void> deleteRecurringRule(String id) async {
    await _request('DELETE', '/recurring/$id');
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<Map<String, dynamic>> aiNlu(String text, {bool runLlm = false}) async {
    final result = await _request(
      'POST',
      '/ai/nlu',
      body: {'text': text, 'runLlm': runLlm},
    );
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aiExpenseFromText({
    required String walletId,
    required String text,
    bool autoSave = false,
  }) async {
    final result = await _request(
      'POST',
      '/ai/expense/from-text',
      body: {'walletId': walletId, 'text': text, 'autoSave': autoSave},
    );
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aiExpenseFromTextAsync({
    required String walletId,
    required String text,
  }) async {
    final result = await _request(
      'POST',
      '/ai/expense/from-text-async',
      body: {'walletId': walletId, 'text': text},
    );
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aiExpenseFromBill({
    required String walletId,
    required String filePath,
  }) async {
    final token = await accessToken;
    // Bill OCR: giữ cạnh dài lớn hơn để chữ trên hoá đơn vẫn đọc được.
    final uploadPath = await compressForUpload(
      filePath,
      maxSize: 1600,
      quality: 85,
    );
    final uri = Uri.parse('$baseUrl/ai/expense/from-bill?walletId=$walletId');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${token ?? ''}'
      ..fields['walletId'] = walletId
      ..files.add(await http.MultipartFile.fromPath('file', uploadPath));
    final streamed = await req.send();
    final response = await http.Response.fromStream(streamed);
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(
        statusCode: response.statusCode,
        message: jsonBody['message'] as String? ?? 'Bill upload failed',
        code: jsonBody['code'] as String?,
      );
    }
    return jsonBody['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aiCorrection(Map<String, dynamic> body) async {
    final result = await _request('POST', '/ai/corrections', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aiExecuteAction(
    Map<String, dynamic> body,
  ) async {
    final result = await _request('POST', '/ai/actions/execute', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBudgetSuggestions({String? month}) async {
    final query = month != null ? '?month=$month' : '';
    final result = await _request('GET', '/budgets/suggestions$query');
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> applyBudgetSuggestions({
    required String month,
    Map<String, num>? overrides,
  }) async {
    final result = await _request(
      'POST',
      '/budgets/suggestions/apply',
      body: {'month': month, 'overrides': overrides},
    );
    return {
      'data': result['data'],
      'message': result['message'] as String? ?? '',
    };
  }

  Future<String> dismissBudgetSuggestions({required String month}) async {
    final result = await _request(
      'POST',
      '/budgets/suggestions/dismiss',
      body: {'month': month},
    );
    return result['message'] as String? ?? 'Đã bỏ qua gợi ý.';
  }

  Future<bool> aiIsActionConfirmed(String actionSignature) async {
    final result = await _request(
      'GET',
      '/ai/actions/is-confirmed?actionSignature=${Uri.encodeQueryComponent(actionSignature)}',
    );
    final data = result['data'] as Map<String, dynamic>?;
    return data?['confirmed'] as bool? ?? false;
  }

  Future<void> aiConfirmAction(
    String actionSignature, {
    String? actionType,
  }) async {
    await _request(
      'POST',
      '/ai/actions/confirm',
      body: {'actionSignature': actionSignature, 'actionType': actionType},
    );
  }

  Future<Map<String, dynamic>> uploadFile(String filePath) async {
    final token = await accessToken;
    final uploadPath = await compressForUpload(filePath);
    final uri = Uri.parse('$baseUrl/upload/direct');
    final req = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${token ?? ''}'
      ..files.add(await http.MultipartFile.fromPath('file', uploadPath));
    final streamed = await req.send();
    final response = await http.Response.fromStream(streamed);
    final jsonBody = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiException(
        statusCode: response.statusCode,
        message: jsonBody['message'] as String? ?? 'Upload failed',
        code: jsonBody['code'] as String?,
      );
    }
    return jsonBody['data'] as Map<String, dynamic>;
  }

  Future<void> aiRejectAction({
    String? text,
    Map<String, dynamic>? predicted,
  }) async {
    await _request(
      'POST',
      '/ai/actions/reject',
      body: {'text': text, 'predicted': predicted},
    );
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<Map<String, dynamic>> getSettings() async {
    final result = await _request('GET', '/users/me/settings');
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> body) async {
    final result = await _request('PATCH', '/users/me/settings', body: body);
    final data = result['data'] as Map<String, dynamic>;
    final ageGroup =
        data['ageGroup'] as String? ?? data['age_group'] as String?;
    final jobType = data['jobType'] as String? ?? data['job_type'] as String?;
    if ((ageGroup != null && ageGroup.isNotEmpty) ||
        (jobType != null && jobType.isNotEmpty)) {
      _isOnboardingBypassed = true;
    }
    return data;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async {
    final result = await _request('PATCH', '/auth/me', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<List<dynamic>> getChatSessions() async {
    final result = await _request('GET', '/chat/sessions');
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createChatSession({
    String? title,
    String? walletId,
  }) async {
    final result = await _request(
      'POST',
      '/chat/sessions',
      body: {'title': title, if (walletId != null) 'walletId': walletId},
    );
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aiChat(
    String sessionId,
    String content, {
    Map<String, dynamic>? contextMeta,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (contextMeta != null) body['contextMeta'] = contextMeta;
    final result = await _request('POST', '/ai/chat/$sessionId', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getChatMessagesPage(
    String sessionId, {
    int limit = 30,
    String? before,
  }) async {
    final result = await _request(
      'GET',
      '/chat/sessions/$sessionId/messages',
      queryParams: {
        'limit': limit.toString(),
        if (before != null && before.isNotEmpty) 'before': before,
      },
    );
    final data = result['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    if (data is List) {
      final list = data.cast<dynamic>();
      return {
        'messages': list,
        'hasMore': list.length >= limit,
        'oldestId': list.isNotEmpty
            ? (list.first as Map)['id']?.toString()
            : null,
      };
    }
    return {'messages': <dynamic>[], 'hasMore': false, 'oldestId': null};
  }

  Future<Map<String, dynamic>> sendChatMessage(
    String sessionId,
    String content,
  ) async {
    final result = await _request(
      'POST',
      '/chat/sessions/$sessionId/messages',
      body: {'content': content, 'role': 'user'},
    );
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendChatMessageRaw(
    String sessionId,
    Map<String, dynamic> payload,
  ) async {
    final result = await _request(
      'POST',
      '/chat/sessions/$sessionId/messages',
      body: payload,
    );
    return result['data'] as Map<String, dynamic>;
  }

  Future<void> deleteChatSession(String sessionId) async {
    await _request('DELETE', '/chat/sessions/$sessionId');
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<List<dynamic>> getStories({String? walletId}) async {
    final result = await _request(
      'GET',
      '/stories',
      queryParams: {if (walletId != null) 'walletId': walletId},
    );
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getStory(String id) async {
    final result = await _request('GET', '/stories/$id');
    return result['data'] as Map<String, dynamic>;
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<Map<String, dynamic>> getGroupOverview(String walletId) async {
    final result = await _request('GET', '/group-stats/$walletId/overview');
    return result['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getGroupCategories(String walletId) async {
    final result = await _request('GET', '/group-stats/$walletId/categories');
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getGroupSettlement(String walletId) async {
    final result = await _request('GET', '/group-stats/$walletId/settlement');
    return result['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getGroupTimeline(
    String walletId, {
    String? range,
    String? from,
    String? to,
  }) async {
    final query = <String, String>{};
    if (range != null) query['range'] = range;
    if (from != null) query['from'] = from;
    if (to != null) query['to'] = to;

    final uri = Uri(
      path: '/group-stats/$walletId/timeline',
      queryParameters: query.isEmpty ? null : query,
    );
    final result = await _request('GET', uri.toString());
    return result['data'] as List<dynamic>;
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<List<dynamic>> getStatsByCategory({
    String? range,
    String? walletId,
    String? from,
    String? to,
    String? type,
  }) async {
    final result = await _request(
      'GET',
      '/stats/by-category',
      queryParams: {
        if (range != null) 'range': range,
        if (walletId != null) 'walletId': walletId,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (type != null) 'type': type,
      },
    );
    return result['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getStatsByMonth({int? year, String? walletId}) async {
    final params = {
      if (year != null) 'year': year.toString(),
      if (walletId != null) 'walletId': walletId,
    };
    final result = await _request(
      'GET',
      '/stats/by-month',
      queryParams: params,
    );
    return result['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getStatsMoM({String? walletId}) async {
    final result = await _request(
      'GET',
      '/stats/mom',
      queryParams: {if (walletId != null) 'walletId': walletId},
    );
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getStatsCumulativeVsBudget({
    String? walletId,
    String? timeRange,
    int? periodOffset,
  }) async {
    final result = await _request(
      'GET',
      '/stats/cumulative-vs-budget',
      queryParams: {
        if (walletId != null) 'walletId': walletId,
        if (timeRange != null) 'timeRange': timeRange,
        if (periodOffset != null) 'periodOffset': periodOffset.toString(),
      },
    );
    return result['data'] as Map<String, dynamic>;
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<List<dynamic>> getWalletMembers(String walletId) async {
    final result = await _request('GET', '/wallets/$walletId/members');
    return result['data'] as List<dynamic>;
  }

  Future<List<dynamic>> inviteWalletMember(
    String walletId,
    String email, {
    String role = 'member',
  }) async {
    final result = await _request(
      'POST',
      '/wallets/$walletId/invite',
      body: {'email': email, 'role': role},
    );
    return result['data'] as List<dynamic>;
  }

  Future<void> removeWalletMember(String walletId, String memberId) async {
    await _request('DELETE', '/wallets/$walletId/members/$memberId');
  }

  // ————————————————————————————————————————————————————————————————————————————
  Future<List<dynamic>> getLoans() async {
    final result = await _request('GET', '/loans');
    return (result['data'] as List<dynamic>?) ?? [];
  }

  Future<Map<String, dynamic>> createLoan(Map<String, dynamic> body) async {
    final result = await _request('POST', '/loans', body: body);
    return (result['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<Map<String, dynamic>> updateLoan(
    String id,
    Map<String, dynamic> body,
  ) async {
    final result = await _request('PATCH', '/loans/$id', body: body);
    return (result['data'] as Map<String, dynamic>?) ?? {};
  }

  Future<void> deleteLoan(String id) async {
    await _request('DELETE', '/loans/$id');
  }

  Future<Map<String, dynamic>> getGoalRecap(Map<String, dynamic> body) async {
    return await _request('POST', '/ai/goal-recap', body: body);
  }

  // ————————————————————————————————————————————————————————————————————————————

  /// Tạo đơn hàng Premium mới.
  /// Trả về : { orderId, code, amount, transferContent, qrUrl, bank, accountNumber, accountName }
  Future<Map<String, dynamic>> createPaymentOrder() async {
    final result = await _request('POST', '/payments/create');
    return result['data'] as Map<String, dynamic>;
  }

  /// Polling: kiểm tra trạng thái đơn hàng gần nhất.
  /// Trả về null nếu chưa có đơn. Status: pending | completed | cancelled
  Future<Map<String, dynamic>?> getPaymentStatus() async {
    final result = await _request('GET', '/payments/status');
    return result['data'] as Map<String, dynamic>?;
  }

  /// Lấy trạng thái Premium của user hiện tại.
  Future<bool> getMyPremiumStatus() async {
    final result = await _request('GET', '/payments/my');
    final data = result['data'] as Map<String, dynamic>?;
    return data?['isPremium'] as bool? ?? false;
  }

  // ==========================================
  // Group Expenses (Chia Bill Nhóm)
  // ==========================================

  Future<List<dynamic>> getExpenseGroups() async {
    final response = await _request('GET', '/expense-groups');
    return response['data'] as List<dynamic>? ?? [];
  }

  Future<Map<String, dynamic>> createExpenseGroup({
    required String name,
    String? description,
    List<String>? members,
  }) async {
    final body = <String, dynamic>{'name': name};
    if (description != null && description.isNotEmpty) {
      body['description'] = description;
    }
    if (members != null && members.isNotEmpty) {
      body['members'] = members;
    }
    final response = await _request(
      'POST',
      '/expense-groups',
      body: body,
    );
    return response['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getExpenseGroupDetails(String groupId) async {
    final response = await _request('GET', '/expense-groups/$groupId');
    return response['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinExpenseGroup(String inviteCode, {String? memberId}) async {
    final body = <String, dynamic>{'inviteCode': inviteCode};
    if (memberId != null) {
      body['memberId'] = memberId;
    }
    final response = await _request(
      'POST',
      '/expense-groups/join',
      body: body,
    );
    return response['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> previewExpenseGroup(String inviteCode) async {
    final response = await _request('GET', '/expense-groups/preview/$inviteCode');
    return response['data'] as Map<String, dynamic>;
  }

  Future<void> removeGroupMember(String groupId, String memberId) async {
    await _request('DELETE', '/expense-groups/$groupId/members/$memberId');
  }

  Future<Map<String, dynamic>> addGroupTransaction(
    String groupId,
    Map<String, dynamic> data,
  ) async {
    final response = await _request(
      'POST',
      '/expense-groups/$groupId/transactions',
      body: data,
    );
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> updateGroupTransaction(
    String txId,
    Map<String, dynamic> data,
  ) async {
    final response = await _request(
      'PUT',
      '/expense-groups/transactions/$txId',
      body: data,
    );
    return response['data'] as Map<String, dynamic>? ?? {};
  }

  Future<Map<String, dynamic>> splitGroupBills(String groupId) async {
    final response = await _request('POST', '/expense-groups/$groupId/split');
    return response['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> settleGroupDebt(
    String groupId,
    String debtId,
  ) async {
    final response = await _request(
      'POST',
      '/expense-groups/$groupId/settle',
      body: {'debtId': debtId},
    );
    return response['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> uploadGroupBill({
    required String groupId,
    required String filePath,
    required String paidBy,
  }) async {
    final token = await accessToken;
    if (token == null) {
      throw ApiException(statusCode: 401, message: 'Vui lòng đăng nhập lại.');
    }

    final uri = Uri.parse(
      '$baseUrl/ai/expense/group-from-bill?groupId=$groupId',
    );
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['paidBy'] = paidBy;
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final decoded = jsonDecode(response.body);
      if (response.statusCode >= 400) {
        throw ApiException(
          statusCode: response.statusCode,
          message: decoded['message'] ?? 'Upload failed',
        );
      }
      return decoded['data'] as Map<String, dynamic>;
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(statusCode: 500, message: 'Network error: $e');
    }
  }
}

/// API exception with status code and message.
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;

  ApiException({required this.statusCode, required this.message, this.code});

  @override
  String toString() => 'ApiException($statusCode): $message';

  String get localizedMessage {
    switch (code) {
      case 'INVALID_CREDENTIALS':
        return 'Email hoặc mật khẩu không đúng';
      case 'EMAIL_EXISTS':
        return 'Email đã được đăng ký';
      case 'NOT_FOUND':
        return 'Không tìm thấy';
      case 'VALIDATION_ERROR':
        return '  Dữ liệu không hợp lệ';
      default:
        if (statusCode == 401) return 'Phiên đăng nhập hết hạn';
        if (statusCode == 403) return 'Không có quyền truy cập';
        if (statusCode == 500) return 'Lỗi hệ thống, vui lòng thử lại sau';
        return message;
    }
  }
}
