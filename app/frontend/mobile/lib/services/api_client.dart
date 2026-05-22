import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Centralized API client for all backend calls.
/// Replaces old `BackendApiService` with proper JWT auth flow.
class ApiClient {
  static const _defaultBaseUrl = 'http://10.0.2.2:4000/api/v1';

  final String baseUrl;
  final FlutterSecureStorage _storage;
  final http.Client _http;

  ApiClient({
    String? baseUrl,
    FlutterSecureStorage? storage,
    http.Client? httpClient,
  })  : baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL', defaultValue: _defaultBaseUrl),
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
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);
    final headers = requireAuth ? await _authHeaders() : {'Content-Type': 'application/json; charset=utf-8'};

    http.Response response;
    switch (method) {
      case 'GET':
        response = await _http.get(uri, headers: headers);
        break;
      case 'POST':
        response = await _http.post(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'PATCH':
        response = await _http.patch(uri, headers: headers, body: body != null ? jsonEncode(body) : null);
        break;
      case 'DELETE':
        response = await _http.delete(uri, headers: headers);
        break;
      default:
        throw UnsupportedError('HTTP method $method not supported');
    }

    // Handle 401 — try refresh
    if (response.statusCode == 401 && requireAuth) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        return _request(method, path, body: body, queryParams: queryParams, requireAuth: true);
      }
    }

    final jsonBody = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw ApiException(
        statusCode: response.statusCode,
        message: jsonBody['message'] as String? ?? 'Request failed',
        code: jsonBody['code'] as String?,
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
    } catch (_) {}

    await clearTokens();
    return false;
  }

  // ─── Auth ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    final result = await _request('POST', '/auth/login',
        body: {'email': email, 'password': password}, requireAuth: false);
    final data = result['data'] as Map<String, dynamic>;
    await _saveTokens(data['accessToken'], data['refreshToken']);
    return data;
  }

  Future<Map<String, dynamic>> register(String email, String password, String username) async {
    final result = await _request('POST', '/auth/register',
        body: {'email': email, 'password': password, 'username': username}, requireAuth: false);
    final data = result['data'] as Map<String, dynamic>;
    await _saveTokens(data['accessToken'], data['refreshToken']);
    return data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final result = await _request('GET', '/auth/me');
    return result['data'] as Map<String, dynamic>;
  }

  Future<void> logout() async {
    final rToken = await refreshToken;
    if (rToken != null) {
      try {
        await _request('POST', '/auth/logout', body: {'refreshToken': rToken});
      } catch (_) {}
    }
    await clearTokens();
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _request('POST', '/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> getStreak() async {
    final result = await _request('GET', '/users/me/streak');
    return result['data'] as Map<String, dynamic>;
  }

  // ─── Wallets ──────────────────────────────────────────────────────
  Future<List<dynamic>> getWallets() async {
    final result = await _request('GET', '/wallets');
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createWallet(Map<String, dynamic> body) async {
    final result = await _request('POST', '/wallets', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  // ─── Categories ───────────────────────────────────────────────────
  Future<List<dynamic>> getCategories() async {
    final result = await _request('GET', '/categories');
    return result['data'] as List<dynamic>;
  }

  // ─── Transactions ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> getTransactions({String? walletId, String? type, int pageSize = 20, int page = 1}) async {
    final result = await _request('GET', '/transactions', queryParams: {
      'walletId': ?walletId,
      'type': ?type,
      'pageSize': '$pageSize',
      'page': '$page',
    });
    return result;
  }

  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> body) async {
    final result = await _request('POST', '/transactions', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateTransaction(String id, Map<String, dynamic> body) async {
    final result = await _request('PATCH', '/transactions/$id', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<void> deleteTransaction(String id) async {
    await _request('DELETE', '/transactions/$id');
  }

  // ─── Stats ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getDashboard({String? walletId}) async {
    final result = await _request('GET', '/stats/dashboard', queryParams: {
      'walletId': ?walletId,
    });
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStatsByMonth({required int year}) async {
    final result = await _request('GET', '/stats/by-month', queryParams: {'year': '$year'});
    return result['data'] as Map<String, dynamic>;
  }

  // ─── Budgets ──────────────────────────────────────────────────────
  Future<List<dynamic>> getBudgets() async {
    final result = await _request('GET', '/budgets');
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getBudgetSummary() async {
    final result = await _request('GET', '/budgets/summary');
    return result;
  }

  Future<Map<String, dynamic>> createBudget(Map<String, dynamic> body) async {
    final result = await _request('POST', '/budgets', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  // ─── Goals ────────────────────────────────────────────────────────
  Future<List<dynamic>> getGoals() async {
    final result = await _request('GET', '/goals');
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createGoal(Map<String, dynamic> body) async {
    final result = await _request('POST', '/goals', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> contributeGoal(String id, double amount) async {
    final result = await _request('POST', '/goals/$id/contribute', body: {'amount': amount});
    return result['data'] as Map<String, dynamic>;
  }

  // ─── AI ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> aiNlu(String text, {bool runLlm = false}) async {
    final result = await _request('POST', '/ai/nlu', body: {'text': text, 'runLlm': runLlm});
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aiExpenseFromText({required String walletId, required String text, bool autoSave = false}) async {
    final result = await _request('POST', '/ai/expense/from-text', body: {
      'walletId': walletId, 'text': text, 'autoSave': autoSave,
    });
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aiCorrection(Map<String, dynamic> body) async {
    final result = await _request('POST', '/ai/corrections', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  // ─── User Settings ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getSettings() async {
    final result = await _request('GET', '/users/me/settings');
    return result['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> body) async {
    final result = await _request('PATCH', '/users/me/settings', body: body);
    return result['data'] as Map<String, dynamic>;
  }

  // ─── Chat ─────────────────────────────────────────────────────────
  Future<List<dynamic>> getChatSessions() async {
    final result = await _request('GET', '/chat/sessions');
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createChatSession({String? title}) async {
    final result = await _request('POST', '/chat/sessions', body: {'title': ?title});
    return result['data'] as Map<String, dynamic>;
  }

  Future<List<dynamic>> getChatMessages(String sessionId) async {
    final result = await _request('GET', '/chat/sessions/$sessionId/messages');
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> sendChatMessage(String sessionId, String content) async {
    final result = await _request('POST', '/chat/sessions/$sessionId/messages', body: {'content': content, 'role': 'user'});
    return result['data'] as Map<String, dynamic>;
  }

  // ─── Stories ──────────────────────────────────────────────────────
  Future<List<dynamic>> getStories({String? walletId}) async {
    final result = await _request('GET', '/stories', queryParams: {
      'walletId': ?walletId,
    });
    return result['data'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getStory(String id) async {
    final result = await _request('GET', '/stories/$id');
    return result['data'] as Map<String, dynamic>;
  }

  // ─── Stats ────────────────────────────────────────────────────────
  Future<List<dynamic>> getStatsByCategory({String? range}) async {
    final result = await _request('GET', '/stats/by-category', queryParams: {
      'range': ?range,
    });
    return result['data'] as List<dynamic>;
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
      case 'INVALID_CREDENTIALS': return 'Email hoặc mật khẩu không đúng';
      case 'EMAIL_EXISTS': return 'Email đã được đăng ký';
      case 'NOT_FOUND': return 'Không tìm thấy';
      case 'VALIDATION_ERROR': return 'Dữ liệu không hợp lệ';
      default:
        if (statusCode == 401) return 'Phiên đăng nhập hết hạn';
        if (statusCode == 403) return 'Không có quyền truy cập';
        if (statusCode == 500) return 'Lỗi hệ thống, vui lòng thử lại sau';
        return message;
    }
  }
}
