import 'dart:convert';

import 'package:flutter/foundation.dart';

// Mã giả các class phụ thuộc để minh họa
class LocalDatabase {
  Future<bool> checkExists(String id) async => false;
  Future<void> insertTransaction(Transaction tx) async {}
  Future<List<Transaction>> getUnsyncedTransactions() async => [];
  Future<void> markAsSynced(String id) async {}
}

class ApiClient {
  Future<void> postTransaction(Transaction tx) async {}
}

class WebSocketChannel {
  Stream<String> get stream => const Stream.empty();
}

class Transaction {
  final String id;
  Transaction({required this.id});
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(id: json['id']);
  }
}

class NotificationService {
  static void triggerMascotNotification(Transaction tx) {}
}

class SyncService {
  final LocalDatabase _localDb;
  final ApiClient _apiClient;
  final WebSocketChannel _wsChannel;

  SyncService(this._localDb, this._apiClient, this._wsChannel);

  // 1. Lắng nghe tín hiệu từ WebSocket
  void listenToRealtimeUpdates() {
    _wsChannel.stream.listen((message) {
      final data = jsonDecode(message);

      if (data['type'] == 'NEW_TRANSACTION') {
        _handleNewTransaction(data['payload']);
      }
    });
  }

  // 2. Xử lý dữ liệu mới đẩy xuống
  Future<void> _handleNewTransaction(Map<String, dynamic> payload) async {
    // Chuyển đổi JSON sang Model
    final newTx = Transaction.fromJson(payload);

    // Kiểm tra xem giao dịch đã tồn tại trong Local DB chưa (tránh trùng lặp)
    bool exists = await _localDb.checkExists(newTx.id);

    if (!exists) {
      // Lưu vào Local DB để cập nhật UI ngay lập tức
      await _localDb.insertTransaction(newTx);

      // Trigger thông báo Mascot cho thành viên khác
      NotificationService.triggerMascotNotification(newTx);
    }
  }

  // 3. Cơ chế đẩy dữ liệu Offline lên Cloud (Retry Mechanism)
  Future<void> syncPendingTransactions() async {
    final pendingTxs = await _localDb.getUnsyncedTransactions();

    for (var tx in pendingTxs) {
      try {
        await _apiClient.postTransaction(tx);
        await _localDb.markAsSynced(tx.id); // Đánh dấu đã đồng bộ thành công
      } catch (e) {
        // Nếu lỗi mạng, bỏ qua để lần sau thử lại
        debugPrint("Sync failed for ${tx.id}: $e");
      }
    }
  }
}
