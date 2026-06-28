import 'dart:async';

import 'package:flutter/foundation.dart';

import '../routes/app_routes.dart';
import '../utils/formatters.dart';
import '../utils/mimo_emotion.dart';
import '../widgets/mimo_overlay.dart';
import '../widgets/notification_overlay.dart';
import 'api_client.dart';
import 'push_notification_service.dart';
import 'transaction_notifier.dart';

enum BillJobPhase { uploading, processing, done, failed }

class BillJob {
  BillJob({
    required this.transactionId,
    required this.walletId,
    this.localImagePath,
  });

  String transactionId;
  final String walletId;
  final String? localImagePath;

  BillJobPhase phase = BillJobPhase.uploading;
  String? errorMessage;
  int elapsedSeconds = 0;
  double progress = 0.05;
  String? storyId;
  Map<String, dynamic>? result;
  Timer? _elapsedTimer;
  Timer? _pollTimer;
  int _pollAttempts = 0;

  static const _pollIntervalSeconds = 3;
  static const _maxPollAttempts = 100;

  bool get isActive =>
      phase == BillJobPhase.uploading || phase == BillJobPhase.processing;

  void disposeTimers() {
    _elapsedTimer?.cancel();
    _pollTimer?.cancel();
  }
}

class BillProcessingService extends ChangeNotifier {
  BillProcessingService._();
  static final BillProcessingService instance = BillProcessingService._();

  final _api = ApiClient();
  final List<BillJob> _jobs = [];

  void Function(String route, [Map<String, dynamic>? extra])? onNavigate;

  Map<String, dynamic>? _pendingReviewExtra;

  /// Extra cho màn confirm khi user bấm thông báo (push/deep link không kèm extra).
  Map<String, dynamic>? takePendingReviewExtra() {
    final extra = _pendingReviewExtra;
    _pendingReviewExtra = null;
    return extra;
  }

  void clearPendingReviewExtra() {
    _pendingReviewExtra = null;
  }

  List<BillJob> get jobs => List.unmodifiable(_jobs);
  List<BillJob> get activeJobs =>
      _jobs.where((j) => j.isActive).toList(growable: false);

  Future<void> submitBill({
    required String walletId,
    required String imagePath,
  }) async {
    BillJob? job;
    try {
      final uploadJob = BillJob(
        transactionId: 'uploading',
        walletId: walletId,
        localImagePath: imagePath,
      );
      job = uploadJob;
      _jobs.insert(0, uploadJob);
      notifyListeners();
      _startElapsedTimer(uploadJob);

      uploadJob.phase = BillJobPhase.uploading;
      uploadJob.progress = 0.08;
      notifyListeners();

      final result = await _api.aiExpenseFromBill(
        walletId: walletId,
        filePath: imagePath,
      );

      final txId = result['transactionId'] as String?;
      if (txId == null || txId.isEmpty) {
        throw ApiException(statusCode: 500, message: 'Thiếu transactionId từ server');
      }

      uploadJob.transactionId = txId;
      uploadJob.phase = BillJobPhase.processing;
      uploadJob.progress = 0.18;
      notifyListeners();
      _startPolling(uploadJob);
    } on ApiException catch (e) {
      if (job != null) _failJob(job, e.localizedMessage);
    } catch (e) {
      if (job != null) _failJob(job, 'Không thể gửi bill. Thử lại sau.');
    }
  }

  void trackExistingJob({
    required String transactionId,
    required String walletId,
    String? localImagePath,
  }) {
    if (_jobs.any((j) => j.transactionId == transactionId)) return;
    final job = BillJob(
      transactionId: transactionId,
      walletId: walletId,
      localImagePath: localImagePath,
    )..phase = BillJobPhase.processing
      ..progress = 0.2;
    _jobs.insert(0, job);
    notifyListeners();
    _startElapsedTimer(job);
    _startPolling(job);
  }

  void handleWsTransactionDone(String transactionId, Map<String, dynamic> data) {
    final job = _findJob(transactionId);
    if (job == null || job.phase == BillJobPhase.done) return;
    _completeJob(job, _normalizeResult(data));
  }

  void handleWsTransactionFailed(String transactionId, String? error) {
    final job = _findJob(transactionId);
    if (job == null || job.phase == BillJobPhase.done) return;
    _failJob(job, error ?? 'Xử lý bill thất bại');
  }

  BillJob? _findJob(String transactionId) {
    for (final j in _jobs) {
      if (j.transactionId == transactionId) return j;
    }
    return null;
  }

  void _startElapsedTimer(BillJob job) {
    job._elapsedTimer?.cancel();
    job._elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!job.isActive) return;
      job.elapsedSeconds++;
      if (job.phase == BillJobPhase.processing) {
        job.progress = (0.18 + (job.elapsedSeconds / 180) * 0.74).clamp(0.18, 0.92);
      }
      notifyListeners();
    });
  }

  void _startPolling(BillJob job) {
    job._pollTimer?.cancel();
    job._pollAttempts = 0;
    job._pollTimer = Timer.periodic(const Duration(seconds: BillJob._pollIntervalSeconds), (_) async {
      if (job.phase == BillJobPhase.done || job.phase == BillJobPhase.failed) {
        job._pollTimer?.cancel();
        return;
      }
      job._pollAttempts++;
      if (job._pollAttempts > BillJob._maxPollAttempts) {
        job._pollTimer?.cancel();
        _failJob(job, 'Bill vẫn đang xử lý — kiểm tra Story sau vài phút');
        return;
      }
      try {
        final tx = await _api.getTransaction(job.transactionId);
        final status = tx['processingStatus'] as String? ?? 'done';
        if (status == 'done') {
          job._pollTimer?.cancel();
          _completeJob(job, tx);
        } else if (status == 'failed') {
          job._pollTimer?.cancel();
          _failJob(job, 'Xử lý bill thất bại');
        }
      } catch (_) {}
    });
  }

  static const _confidenceThreshold = 0.9;

  Map<String, dynamic> _buildConfirmExtra(BillJob job, Map<String, dynamic> data) {
    final confidence = data['aiConfidence'] is num
        ? (data['aiConfidence'] as num).toDouble()
        : 0.0;
    final amount = data['amount'];
    return {
      'reviewBill': true,
      'transactionId': job.transactionId,
      'walletId': job.walletId,
      'storyId': data['storyId'],
      'imagePath': job.localImagePath,
      'localImagePath': job.localImagePath,
      'imageUrl': data['imageUrl'],
      'extracted': {
        'amount': amount is num ? amount.toInt() : 0,
        'category': data['categoryCode'] ?? 'Others',
        'note': data['note'] ?? '',
        'confidence': confidence,
        'record_type': 'Expense',
      },
    };
  }

  bool _needsReview(Map<String, dynamic> data) {
    final confidence = data['aiConfidence'] is num
        ? (data['aiConfidence'] as num).toDouble()
        : 0.0;
    final amount = data['amount'];
    if (confidence < _confidenceThreshold) return true;
    if (amount == null) return true;
    if (amount is num && amount <= 0) return true;
    return false;
  }

  Map<String, dynamic> _normalizeResult(Map<String, dynamic> data) {
    return {
      'amount': data['amount'],
      'categoryCode': data['categoryCode'] ?? data['category'],
      'note': data['note'],
      'storyId': data['storyId'],
      'imageUrl': data['imageUrl'],
      'aiComment': data['aiComment'] ?? data['story'] ?? data['ai_message'],
      'mascotMood': data['mascotMood'] ?? data['mascot_mood'],
      'aiConfidence': data['aiConfidence'] ?? data['ai_confidence'],
    };
  }

  void _completeJob(BillJob job, Map<String, dynamic> rawData) {
    final data = _normalizeResult(rawData);
    job.disposeTimers();
    job.phase = BillJobPhase.done;
    job.progress = 1.0;
    job.result = data;
    job.storyId = data['storyId'] as String?;
    notifyListeners();

    notifyTransactionChanged();

    final story = data['aiComment'] as String? ?? data['story'] as String?;
    final amount = data['amount'];
    final category = data['categoryCode'] as String? ?? 'Others';
    final mood = normalizeMimoAssetName(
      data['mascotMood'] as String?,
      fallback: 'Success',
    );
    final amountLabel = amount is num ? formatVnd(amount.toInt()) : null;
    final message = story != null && story.isNotEmpty
        ? story.substring(0, story.length.clamp(0, 80))
        : (amountLabel != null ? 'Đã ghi $amountLabel · $category' : 'Bill đã được thêm vào Story');

    final needsReview = _needsReview(data);
    final confirmExtra = needsReview ? _buildConfirmExtra(job, data) : null;
    if (confirmExtra != null) {
      _pendingReviewExtra = confirmExtra;
    }
    final storyRoute = job.storyId != null
        ? AppRoutes.storyDetailOf(job.storyId!)
        : AppRoutes.home;

    inAppNotificationController.show(
      InAppNotification(
        title: needsReview ? 'Bill cần kiểm tra lại' : 'Bill đã đọc xong',
        message: message,
        deepLink: needsReview ? AppRoutes.cameraConfirm : storyRoute,
        actionLabel: needsReview ? 'Kiểm tra lại' : 'Xem story',
        onAction: () {
          if (needsReview && confirmExtra != null) {
            clearPendingReviewExtra();
            onNavigate?.call(AppRoutes.cameraConfirm, confirmExtra);
          } else {
            onNavigate?.call(storyRoute);
          }
        },
      ),
    );

    PushNotificationService.instance.showNotification(
      id: job.transactionId.hashCode & 0x7fffffff,
      title: needsReview ? 'Bill cần kiểm tra lại' : 'Bill đã đọc xong',
      body: message,
      payload: needsReview ? AppRoutes.cameraConfirm : storyRoute,
    );

    mimoController.show(MiMoResponse(emotionAsset: mood, message: message));

    Timer(const Duration(seconds: 4), () {
      _jobs.remove(job);
      notifyListeners();
    });
  }

  void _failJob(BillJob job, String message) {
    job.disposeTimers();
    job.phase = BillJobPhase.failed;
    job.errorMessage = message;
    job.progress = 0;
    notifyListeners();

    inAppNotificationController.show(
      InAppNotification(
        title: 'Bill xử lý thất bại',
        message: message,
        actionLabel: 'Thử lại',
        onAction: () => onNavigate?.call(AppRoutes.camera),
      ),
    );

    Timer(const Duration(seconds: 6), () {
      _jobs.remove(job);
      notifyListeners();
    });
  }

  void dismissJob(String transactionId) {
    final job = _findJob(transactionId);
    if (job == null) return;
    job.disposeTimers();
    _jobs.remove(job);
    notifyListeners();
  }
}
