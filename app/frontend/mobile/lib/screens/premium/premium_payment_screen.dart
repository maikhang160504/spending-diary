import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/api_client.dart';
import '../../services/ads_service.dart';
import '../../theme/app_colors.dart';

/// Màn hình thanh toán Premium qua VietQR / SePay.
///
/// Flow:
///  1. Gọi POST /payments/create → nhận qrUrl, code, amount
///  2. Hiển thị QR image + thông tin chuyển khoản
///  3. Polling GET /payments/status mỗi 5 giây
///  4. Khi status = completed → cập nhật AdsService.isPremium = true → show success
class PremiumPaymentScreen extends StatefulWidget {
  const PremiumPaymentScreen({super.key});

  @override
  State<PremiumPaymentScreen> createState() => _PremiumPaymentScreenState();
}

class _PremiumPaymentScreenState extends State<PremiumPaymentScreen> {
  final _api = ApiClient();

  // State
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _orderData;
  bool _paid = false;
  Timer? _pollTimer;
  bool _isDownloadingQR = false;

  Future<void> _shareQR(String url) async {
    setState(() => _isDownloadingQR = true);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/spenddiary_premium_qr.jpg');
        await file.writeAsBytes(response.bodyBytes);
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(file.path)], text: 'Mã QR thanh toán Premium SpendDiary');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể tải mã QR, vui lòng thử lại!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Có lỗi xảy ra khi tải/chia sẻ mã QR!')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloadingQR = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _createOrder();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _createOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.createPaymentOrder();
      if (!mounted) return;
      setState(() {
        _orderData = result;
        _loading = false;
      });
      _startPolling();
    } catch (e) {
      if (!mounted) return;
      // Nếu đã Premium
      if (e is ApiException && e.code == 'ALREADY_PREMIUM') {
        setState(() {
          _paid = true;
          _loading = false;
        });
        AdsService.instance.setPremium(true);
        return;
      }
      setState(() {
        _error = e is ApiException ? e.localizedMessage : e.toString();
        _loading = false;
      });
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _paid) return;
      try {
        final status = await _api.getPaymentStatus();
        if (status == null) return;
        if (status['status'] == 'completed') {
          _pollTimer?.cancel();
          if (!mounted) return;
          setState(() => _paid = true);
          AdsService.instance.setPremium(true);
        }
      } catch (_) {
        // Ignore polling errors
      }
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã copy vào clipboard ✓'),
        duration: Duration(seconds: 1),
        backgroundColor: AppColors.teal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final card = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Nâng cấp Premium',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
      ),
      body: _paid
          ? _buildSuccess(isDark)
          : _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.teal))
              : _error != null
                  ? _buildError(isDark)
                  : _buildQRScreen(isDark, card),
    );
  }

  Widget _buildQRScreen(bool isDark, Color card) {
    final order = _orderData!;
    final qrUrl = order['qrUrl'] as String? ?? '';
    final code  = order['code'] as String? ?? '';
    final amount = order['amount'] as num? ?? 5000;
    final transferContent = order['transferContent'] as String? ?? code;
    final bank    = order['bank'] as String? ?? '';
    final accNum  = order['accountNumber'] as String? ?? '';
    final accName = order['accountName'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // QR Card
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFB347), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'SpendDiary Premium',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Thanh toán một lần · Vĩnh viễn',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 20),

                // QR Image
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.teal.withValues(alpha: 0.15),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: qrUrl.isNotEmpty
                          ? Image.network(
                              qrUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (_, child, progress) =>
                                  progress == null ? child : const Center(child: CircularProgressIndicator()),
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.qr_code_2, size: 80, color: AppColors.teal),
                              ),
                            )
                          : const Center(child: Icon(Icons.qr_code_2, size: 80, color: AppColors.teal)),
                    ),
                    if (qrUrl.isNotEmpty)
                      Positioned(
                        bottom: -10,
                        child: _isDownloadingQR
                            ? const CircleAvatar(
                                backgroundColor: AppColors.teal,
                                radius: 20,
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                              )
                            : ElevatedButton.icon(
                                onPressed: () => _shareQR(qrUrl),
                                icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                                label: const Text('Lưu mã', style: TextStyle(color: Colors.white, fontSize: 13)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.teal,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  elevation: 4,
                                ),
                              ),
                      ),
                  ],
                ),

                const SizedBox(height: 28),

                // Amount
                Text(
                  _formatVND(amount.toDouble()),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.teal,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Bank info card
          Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _InfoRow(
                  label: 'Ngân hàng',
                  value: bank.toUpperCase(),
                  isDark: isDark,
                ),
                _InfoRow(
                  label: 'Số tài khoản',
                  value: accNum,
                  isDark: isDark,
                  onCopy: () => _copyToClipboard(accNum),
                ),
                _InfoRow(
                  label: 'Tên TK',
                  value: accName,
                  isDark: isDark,
                ),
                _InfoRow(
                  label: 'Số tiền',
                  value: _formatVND(amount.toDouble()),
                  isDark: isDark,
                  highlight: true,
                  onCopy: () => _copyToClipboard(amount.toString()),
                ),
                _InfoRow(
                  label: 'Nội dung CK',
                  value: transferContent,
                  isDark: isDark,
                  highlight: true,
                  onCopy: () => _copyToClipboard(transferContent),
                  isLast: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Polling indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Đang chờ xác nhận thanh toán... Tự động cập nhật sau vài giây.',
                    style: TextStyle(fontSize: 12, color: AppColors.teal),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Instructions
          Container(
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hướng dẫn',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildSteps(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSteps(bool isDark) {
    final steps = [
      'Mở App ngân hàng trên điện thoại của bạn.',
      'Quét mã QR phía trên hoặc chuyển khoản thủ công.',
      'Nhập đúng nội dung chuyển khoản như hiển thị (bắt buộc).',
      'Xác nhận chuyển khoản và chờ hệ thống tự động kích hoạt.',
    ];
    return steps.asMap().entries.map((e) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: AppColors.teal,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${e.key + 1}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              e.value,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    )).toList();
  }

  Widget _buildSuccess(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFB347).withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Image.asset(
                'assets/MiMo/emotions/Thankful.png',
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFB347), size: 64),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              '🎉 Cảm ơn bạn!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tài khoản của bạn đã được nâng cấp\nlên SpendDiary Premium vĩnh viễn!\nHãy tận hưởng trải nghiệm không quảng cáo.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Bắt đầu trải nghiệm Premium ✨',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.redAccent.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Đã có lỗi xảy ra',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _createOrder,
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
              child: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatVND(double amount) {
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '$formatted đ';
  }
}

// ─── Info Row Widget ──────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.onCopy,
    this.highlight = false,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isDark;
  final VoidCallback? onCopy;
  final bool highlight;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: highlight
                        ? AppColors.teal
                        : (isDark ? Colors.white : const Color(0xFF1E293B)),
                  ),
                ),
              ),
              if (onCopy != null)
                GestureDetector(
                  onTap: onCopy,
                  child: const Icon(Icons.copy_outlined, size: 16, color: AppColors.teal),
                ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
      ],
    );
  }
}
