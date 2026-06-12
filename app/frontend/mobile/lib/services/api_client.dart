import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../utils/image_compressor.dart';
import 'connection_manager.dart';

/// Centralized API client for all backend calls.
/// Replaces old `BackendApiService` with proper JWT auth flow.
class ApiClient {
  static const _defaultBaseUrl = 'http://10.0.2.2:4000';

  final String baseUrl;
  final FlutterSecureStorage _storage;
  final http.Client _http;

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

  // ─── Token Management ─────────────────────────────────────────────
  Future<String?> get accessToken => _storage.read(key: 'access_token');
  Future<String?> get refreshToken => _storage.read(key: 'refresh_token');

  Future<void> _saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  Future<bool> get isLoggedIn async => (await accessToken) != null;

  // ─── HTTP Helpers ─────────────────────────────────────────────────
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

    // Handle 401 — try refresh
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

    final jsonBody =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      final errMap = jsonBody['error'] as Map<String, dynamic>?;
      throw ApiException(
        statusCode: response.statusCode,
        message:
            errMap?['message'] as String? ??
            jsonBody['message'] as String? ??
            'Request failed',
        code: errMap?['code'] as String? ?? jsonBody['code'] as String?,
      );
    }

    return jsonBody;
  }

  Future<bool> _tryRefresh() async {
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
      if (response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 403) {
        await clearTokens();
      }
    } catch (_) {
      // Bỏ qua lỗi kết nối (SocketException/Timeout) để không tự động logout khi mất mạng
    }

    return false;
  }

  // ─── Auth ─────────────────────────────────────────────────────────
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
    await _request(
      'DELETE',
      '/users/me/fcm/token',
      body: {'token': token},
    );
  }

  // ─── Wallets ──────────────────────────────────────────────────────
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

  Future<Map<String, dynamic>> generateWalletInviteCode(String walletId) async {
    final result = await _request('POST', '/wallets/$walletId/generate-code');
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinWalletByCode(String code) async {
    final result = await _request('POST', '/wallets/join', body: {'code': code});
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> transferBetweenWallets({
    required String fromWalletId,
    required String toWalletId,
    required int amount,
  }) async {
    final result = await _request('POST', '/wallets/transfer', body: {
      'fromWalletId': fromWalletId,
      'toWalletId': toWalletId,
      'amount': amount,
    });
    return result['data'] as Map<String, dynamic>;
  }

  // ─── Categories ───────────────────────────────────────────────────
  Future<List<dynamic>> getCategories() async {
    final result = await _request('GET', '/categories');
    return result['data'] as List<dynamic>;
  }

  // ─── Transactions ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> getTransactions({
    String? walletId,
    String? type,
    int pageSize = 20,
    int page = 1,
    String? from,
    String? to,
  }) async {
    final result = await _request(
      'GET',
      '/transactions',
      queryParams: {
        'walletId': ?walletId,
        'type': ?type,
        'pageSize': '$pageSize',
        'page': '$page',
        'from': ?from,
        'to': ?to,
      },
    );
    return result;
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

  // ─── Stats ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard({
    String? walletId,
    String? from,
    String? to,
  }) async {
    final result = await _request(
      'GET',
      '/stats/dashboard',
      queryParams: {
        'walletId': ?walletId,
        'from': ?from,
        'to': ?to,
      },
    );
    return result['data'] as Map<String, dynamic>;
  }

  // ─── Budgets ──────────────────────────────────────────────────────
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

  // ─── Goals ────────────────────────────────────────────────────────
  Future<List<dynamic>> getGoals() async {
    final result = await _request('GET', '/goals');
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

  Future<Map<String, dynamic>> updateGoal(String id, Map<String, dynamic> body) async {
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

  // ─── Recurring Rules ──────────────────────────────────────────────
  Future<List<dynamic>> getRecurringRules() async {
    final result = await _request('GET', '/recurring');
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createRecurringRule(Map<String, dynamic> body) async {
    final result = await _request('POST', '/recurring', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateRecurringRule(String id, Map<String, dynamic> body) async {
    final result = await _request('PATCH', '/recurring/$id', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<void> deleteRecurringRule(String id) async {
    await _request('DELETE', '/recurring/$id');
  }

  // ─── AI ───────────────────────────────────────────────────────────
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
      body: {'actionSignature': actionSignature, 'actionType': ?actionType},
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
      body: {'text': ?text, 'predicted': ?predicted},
    );
  }

  // ─── User Settings ────────────────────────────────────────────────
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

  // ─── Chat ─────────────────────────────────────────────────────────
  Future<List<dynamic>> getChatSessions() async {
    final result = await _request('GET', '/chat/sessions');
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createChatSession({String? title, String? walletId}) async {
    final result = await _request(
      'POST',
      '/chat/sessions',
      body: {
        'title': ?title,
        'walletId': ?walletId,
      },
    );
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aiChat(String sessionId, String content) async {
    final result = await _request(
      'POST',
      '/ai/chat/$sessionId',
      body: {'content': content},
    );
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

  // ─── Stories ──────────────────────────────────────────────────────
  Future<List<dynamic>> getStories({String? walletId}) async {
    final result = await _request(
      'GET',
      '/stories',
      queryParams: {'walletId': ?walletId},
    );
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getStory(String id) async {
    final result = await _request('GET', '/stories/$id');
    return result['data'] as Map<String, dynamic>;
  }

  // ─── Stats ────────────────────────────────────────────────────────
  Future<List<dynamic>> getStatsByCategory({
    String? range,
    String? walletId,
    String? from,
    String? to,
  }) async {
    final result = await _request(
      'GET',
      '/stats/by-category',
      queryParams: {
        'range': ?range,
        'walletId': ?walletId,
        'from': ?from,
        'to': ?to,
      },
    );
    return result['data'] as List<dynamic>;
  }

  Future<List<dynamic>> getStatsByMonth({int? year, String? walletId}) async {
    final params = {
      'year': ?year?.toString(),
      'walletId': ?walletId,
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
      queryParams: {
        'walletId':? walletId,
      },
    );
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getStatsCumulativeVsBudget({String? walletId}) async {
    final result = await _request(
      'GET',
      '/stats/cumulative-vs-budget',
      queryParams: {
        'walletId':? walletId,
      },
    );
    return result['data'] as Map<String, dynamic>;
  }

  // ─── Wallet Members ───────────────────────────────────────────────
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
        return 'Dữ liệu không hợp lệ';
      default:
        if (statusCode == 401) return 'Phiên đăng nhập hết hạn';
        if (statusCode == 403) return 'Không có quyền truy cập';
        if (statusCode == 500) return 'Lỗi hệ thống, vui lòng thử lại sau';
        return message;
    }
  }
}
