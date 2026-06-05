import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../widgets/loading_indicator.dart';

class CameraInputScreen extends StatefulWidget {
  final String? imagePath;
  final bool isBill;
  final String? walletId;
  const CameraInputScreen({super.key, this.imagePath, this.isBill = false, this.walletId});

  @override
  State<CameraInputScreen> createState() => _CameraInputScreenState();
}

class _CameraInputScreenState extends State<CameraInputScreen> {
  final _controller = TextEditingController();
  final _api = ApiClient();
  bool _isLoading = false;
  String? _error;
  bool get _hasText => _controller.text.trim().isNotEmpty;

  static const _suggestions = [
    'Phở sáng 45k',
    'Cafe 30k',
    'Grab đi làm 25k',
    'Mua sắm 200k',
    'Điện nước 500k',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_hasText) return;
    setState(() { _isLoading = true; _error = null; });
    try {
      // Get target wallet
      final wallets = await _api.getWallets();
      final targetId = widget.walletId ?? (wallets.isNotEmpty ? wallets[0]['id'] as String : '');

      final result = await _api.aiExpenseFromText(
        walletId: targetId,
        text: _controller.text.trim(),
        autoSave: false,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      // Pass extracted data to confirm screen via extra
      final extraData = Map<String, dynamic>.from(result);
      if (widget.imagePath != null) {
        extraData['imagePath'] = widget.imagePath;
      }
      extraData['walletId'] = targetId;
      context.push(AppRoutes.cameraConfirm, extra: extraData);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = e.localizedMessage; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = 'Không thể kết nối AI. Thử lại sau.'; });
    }
  }

  void _insertSuggestion(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Background photo
          Positioned.fill(
            child: widget.imagePath != null
                ? Image.file(File(widget.imagePath!), fit: BoxFit.cover)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      ),
                    ),
                  ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x66000000), Color(0xDD000000)],
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
                // Compact top bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.auto_awesome, color: AppColors.teal, size: 14),
                        const SizedBox(width: 4),
                        Text('AI Nhập liệu', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.teal, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const Spacer(),
                    const SizedBox(width: 44), // balance the close button
                  ]),
                ),
                const Spacer(),
                // Error banner
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 14),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.white, fontSize: 12))),
                      ]),
                    ),
                  ),
                // Quick chips
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: _suggestions.map((s) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => _insertSuggestion(s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Text(s, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    )).toList()),
                  ),
                ),
                const SizedBox(height: 12),
                // Input area — compact
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          const Icon(Icons.edit_note_rounded, color: AppColors.teal, size: 18),
                          const SizedBox(width: 6),
                          Text('Mô tả chi tiêu',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 10),
                        ListenableBuilder(
                          listenable: _controller,
                          builder: (ctx, child) => TextField(
                            controller: _controller,
                            maxLines: 2,
                            autofocus: true,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'VD: Ăn phở 50k, mua cà phê 30k...',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.08),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: const BorderSide(color: AppColors.teal, width: 1.5)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Submit button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: ListenableBuilder(
                    listenable: _controller,
                    builder: (ctx, child) => SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _hasText && !_isLoading ? _submit : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _hasText ? AppColors.teal : Colors.white.withValues(alpha: 0.15),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(_hasText ? Icons.auto_awesome : Icons.keyboard_alt_outlined, size: 16),
                          const SizedBox(width: 6),
                          Text(_hasText ? 'Phân tích ✨' : 'Nhập mô tả...',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        ]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Loading overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.75),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const LoadingIndicator(size: 120),
                  const SizedBox(height: 14),
                  Text('AI đang phân tích...', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Vui lòng chờ giây lát', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60)),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

