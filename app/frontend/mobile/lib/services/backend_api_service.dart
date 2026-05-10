import 'dart:convert';

import 'package:http/http.dart' as http;

class BackendApiService {
  BackendApiService({String? baseUrl})
    : _baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://10.0.2.2:4000',
          );

  final String _baseUrl;

  Future<Map<String, dynamic>> postTextExpense({required String text}) async {
    return _post('/api/user/expense', {
      'userId': 1,
      'flow': 'text',
      'text': text,
    });
  }

  Future<Map<String, dynamic>> postStoryExpense({
    required String imageUrl,
    required String thumbnailUrl,
    required num amount,
    required String categoryName,
  }) async {
    return _post('/api/user/expense', {
      'userId': 1,
      'flow': 'story',
      'storyImageUrl': imageUrl,
      'storyThumbnailUrl': thumbnailUrl,
      'amount': amount,
      'categoryName': categoryName,
    });
  }

  Future<Map<String, dynamic>> scanBill({required String imageUrl}) async {
    return _post('/api/user/expense', {
      'userId': 1,
      'flow': 'bill',
      'billImageUrl': imageUrl,
      'confirm': false,
    });
  }

  Future<Map<String, dynamic>> confirmBill({
    required String imageUrl,
    required String thumbnailUrl,
    required num amount,
    required String categoryName,
  }) async {
    return _post('/api/user/expense', {
      'userId': 1,
      'flow': 'bill',
      'billImageUrl': imageUrl,
      'billThumbnailUrl': thumbnailUrl,
      'confirm': true,
      'amount': amount,
      'categoryName': categoryName,
    });
  }

  Future<Map<String, dynamic>> postChat({required String message}) async {
    return _post('/api/user/chat', {'userId': 1, 'message': message});
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 400) {
      throw Exception(payload['message'] ?? 'Request failed');
    }

    return payload;
  }
}
