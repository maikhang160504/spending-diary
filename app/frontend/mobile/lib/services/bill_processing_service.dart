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
    this.isText = false,
    this.isGroupBill = false,
  });

  String transactionId;
  final String walletId;
  final String? localImagePath;
  final bool isText;
  final bool isGroupBill;

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
        throw ApiException(
          statusCode: 500,
          message: 'Thiếu transactionId từ server',
        );
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

  Future<void> submitGroupBill({
    required String groupId,
    required String imagePath,
    required String paidBy,
  }) async {
    BillJob? job;
    try {
      final uploadJob = BillJob(
        transactionId: 'uploading',
        walletId: groupId, // Reusing walletId field to store groupId
        localImagePath: imagePath,
        isGroupBill: true,
      );
      // Lữu tạm paidBy vào localImagePath hoặc thêm properties mới.
      // Tuy nhiên tạm thời chưa cần thiết lắm nếu backend tự gán. 
      // Nhưng để nhất quán, ta truyền paidBy lên api.
      
      job = uploadJob;
      _jobs.insert(0, uploadJob);
      notifyListeners();
      _startElapsedTimer(uploadJob);

      uploadJob.phase = BillJobPhase.uploading;
      uploadJob.progress = 0.08;
      notifyListeners();

      final result = await _api.uploadGroupBill(
        groupId: groupId,
        filePath: imagePath,
        paidBy: paidBy,
      );

      final txId = result['transactionId'] as String?;
      if (txId == null || txId.isEmpty) {
        throw ApiException(
          statusCode: 500,
          message: 'Thiếu transactionId từ server',
        );
      }

      uploadJob.transactionId = txId;
      uploadJob.phase = BillJobPhase.processing;
      uploadJob.progress = 0.18;
      notifyListeners();
      _startPolling(uploadJob);
    } on ApiException catch (e) {
      if (job != null) _failJob(job, e.localizedMessage);
    } catch (e) {
      if (job != null) _failJob(job, 'Không thể gửi bill nhóm. Thử lại sau.');
    }
  }

  void trackExistingJob({
    required String transactionId,
    required String walletId,
    String? localImagePath,
    bool isText = false,
  }) {
    if (_jobs.any((j) => j.transactionId == transactionId)) return;
    final job =
        BillJob(
            transactionId: transactionId,
            walletId: walletId,
            localImagePath: localImagePath,
            isText: isText,
          )
          ..phase = BillJobPhase.processing
          ..progress = 0.2;
    _jobs.insert(0, job);
    notifyListeners();
    _startElapsedTimer(job);
    _startPolling(job);
  }

  void handleWsTransactionDone(
    String transactionId,
    Map<String, dynamic> data,
  ) {
    final job = _findJob(transactionId);
    if (job == null || job.phase == BillJobPhase.done) return;
    _completeJob(job, _normalizeResult(data));
  }

  void handleWsTransactionFailed(String transactionId, String? error) {
    final job = _findJob(transactionId);
    if (job == null || job.phase == BillJobPhase.done) return;
    _failJob(
      job,
      error ?? (job.isText ? 'Xử lý story thất bại' : 'Xử lý bill thất bại'),
    );
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
        job.progress = (0.18 + (job.elapsedSeconds / 180) * 0.74).clamp(
          0.18,
          0.92,
        );
      }
      notifyListeners();
    });
  }

  void _startPolling(BillJob job) {
    job._pollTimer?.cancel();
    job._pollAttempts = 0;
    job._pollTimer = Timer.periodic(
      const Duration(seconds: BillJob._pollIntervalSeconds),
      (_) async {
        if (job.phase == BillJobPhase.done ||
            job.phase == BillJobPhase.failed) {
          job._pollTimer?.cancel();
          return;
        }
        job._pollAttempts++;
        if (job._pollAttempts > BillJob._maxPollAttempts) {
          job._pollTimer?.cancel();
          _failJob(
            job,
            job.isText
                ? 'Đang xử lý — kiểm tra Story sau vài phút'
                : 'Bill vẫn đang xử lý — kiểm tra Story sau vài phút',
          );
          return;
        }
        try {
          final Map<String, dynamic> tx;
          if (job.isGroupBill) {
            // Group bill dùng endpoint riêng của nhóm
            tx = await _api.getGroupTransaction(job.transactionId);
          } else {
            tx = await _api.getTransaction(job.transactionId);
          }
          final status = tx['processingStatus'] as String? ?? 'done';
          if (status == 'done') {
            job._pollTimer?.cancel();
            _completeJob(job, tx);
          } else if (status == 'failed') {
            job._pollTimer?.cancel();
            _failJob(
              job,
              job.isText ? 'Xử lý story thất bại' : 'Xử lý bill thất bại',
            );
          }
        } catch (_) {}
      },
    );
  }

  Map<String, dynamic> _buildConfirmExtra(
    BillJob job,
    Map<String, dynamic> data,
  ) {
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
      'amount': amount is num ? amount.toInt() : 0,
      'note': data['note'] ?? '',
      'paidBy': data['paidBy'],
      'extracted': {
        'amount': amount is num ? amount.toInt() : 0,
        'category': data['categoryCode'] ?? 'Others',
        'note': data['note'] ?? '',
        'confidence': confidence,
        'record_type': 'Expense',
        'aiComment': data['aiComment'],
        'mascotMood': data['mascotMood'],
      },
      'nlu': data['nlu'] ?? data['aiMeta']?['nlu'],
      'aiComment': data['aiComment'],
      'mascotMood': data['mascotMood'],
    };
  }

  bool _needsReview(Map<String, dynamic> data) {
    // Always require review for bills per user request
    return true;
  }

  Map<String, dynamic> _normalizeResult(Map<String, dynamic> data) {
    final aiMeta = data['aiMeta'] as Map<String, dynamic>?;
    final nlu =
        (aiMeta?['nlu'] as Map<String, dynamic>?) ??
        (data['nlu'] as Map<String, dynamic>?);
    String? aiComment =
        data['aiComment'] as String? ??
        data['story'] as String? ??
        data['ai_message'] as String?;
    String? mascotMood =
        data['mascotMood'] as String? ?? data['mascot_mood'] as String?;

    if (nlu != null) {
      final llm = LlmMimoReply.fromNlu(
        nlu,
        intent: 'Record',
        logEmotion: false,
      );
      if (aiComment == null || aiComment.isEmpty) {
        aiComment = llm.text;
      }
      if (mascotMood == null || mascotMood.isEmpty) {
        mascotMood = llm.emotionAsset;
      }
    }

    // Chuỗi fallback đầy đủ cho aiComment từ mọi nơi LLM có thể trả về
    aiComment ??= nlu?['gemini_json'] is Map
        ? (nlu!['gemini_json'] as Map)['response'] as String?
        : null;
    aiComment ??= nlu?['gemini_json'] is Map
        ? (nlu!['gemini_json'] as Map)['story'] as String?
        : null;
    aiComment ??= nlu?['nlg_response'] as String?;
    aiComment ??= nlu?['response'] as String?;
    aiComment ??= nlu?['llama_json'] is Map
        ? (nlu!['llama_json'] as Map)['response'] as String?
        : null;
    aiComment ??= nlu?['llama_json'] is Map
        ? (nlu!['llama_json'] as Map)['story'] as String?
        : null;
    mascotMood ??=
        nlu?['mimo_emotion'] as String? ??
        nlu?['llm_emotion'] as String? ??
        nlu?['mascot_mood'] as String? ??
        (nlu?['gemini_json'] as Map<String, dynamic>?)?['mimo_emotion']
            as String? ??
        (nlu?['gemini_json'] as Map<String, dynamic>?)?['emotion'] as String? ??
        (nlu?['llama_json'] as Map<String, dynamic>?)?['mimo_emotion']
            as String? ??
        (nlu?['llama_json'] as Map<String, dynamic>?)?['emotion'] as String?;

    return {
      'amount': data['amount'],
      'categoryCode': data['categoryCode'] ?? data['category'],
      'note': data['note'],
      'paidBy': data['paidBy'],
      'storyId': data['storyId'],
      'imageUrl': data['imageUrl'],
      'aiComment': aiComment,
      'mascotMood': mascotMood,
      'aiConfidence': data['aiConfidence'] ?? data['ai_confidence'],
      'needsReview': data['needsReview'],
      'aiMeta': aiMeta ?? (nlu != null ? {'nlu': nlu} : null),
      'nlu': ?nlu,
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
        ? story
        : (amountLabel != null
              ? 'Đã ghi $amountLabel · $category'
              : 'Bill đã được thêm vào Story');

    final needsReview = _needsReview(data);
    final confirmExtra = needsReview ? _buildConfirmExtra(job, data) : null;
    if (confirmExtra != null) {
      _pendingReviewExtra = confirmExtra;
    }
    
    var storyRoute = job.storyId != null
        ? AppRoutes.storyDetailOf(job.storyId!)
        : AppRoutes.home;
    var reviewRoute = AppRoutes.cameraConfirm;
    
    if (job.isGroupBill) {
      storyRoute = AppRoutes.groupDetailOf(job.walletId);
      reviewRoute = AppRoutes.groupDetailOf(job.walletId);
      if (confirmExtra != null) {
        confirmExtra['reviewGroupBill'] = true;
      }
    }

    if (needsReview) {
      inAppNotificationController.show(
        InAppNotification(
          title: job.isGroupBill 
              ? 'Bill nhóm cần kiểm tra lại' 
              : (job.isText ? 'Story cần kiểm tra lại' : 'Bill cần kiểm tra lại'),
          message: message,
          deepLink: reviewRoute,
          actionLabel: 'Kiểm tra lại',
          onAction: () {
            if (confirmExtra != null) {
              clearPendingReviewExtra();
              onNavigate?.call(reviewRoute, confirmExtra);
            }
          },
        ),
      );
    }

    PushNotificationService.instance.showNotification(
      id: job.transactionId.hashCode & 0x7fffffff,
      title: needsReview
          ? (job.isGroupBill ? 'Bill nhóm cần kiểm tra' : (job.isText ? 'Story cần kiểm tra lại' : 'Bill cần kiểm tra lại'))
          : (job.isGroupBill ? 'Bill nhóm đã quét xong' : (job.isText ? 'Story đã lưu thành công' : 'Bill đã đọc xong')),
      body: message,
      payload: needsReview ? reviewRoute : storyRoute,
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
