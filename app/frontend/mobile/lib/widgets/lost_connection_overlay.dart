import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../services/api_client.dart';
import '../services/connection_manager.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import 'mimo_snackbar.dart';

/// An overlay screen displayed when network connection or server access is lost.
/// It shows a rotating Lottie spinner and lets the user retry the connection.
class LostConnectionOverlay extends StatefulWidget {
  const LostConnectionOverlay({super.key});

  @override
  State<LostConnectionOverlay> createState() => _LostConnectionOverlayState();
}

class _LostConnectionOverlayState extends State<LostConnectionOverlay> {
  bool _checking = false;

  Future<void> _retry() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      // Test the network connection by firing a request to the server.
      // If the server returns any response (even HTTP errors/auth errors), it is reachable!
      await ApiClient().getStreak();
      ConnectionManager.instance.setLost(false);
    } on ApiException catch (_) {
      // If we got an ApiException, it means the API responded. The connection is back!
      ConnectionManager.instance.setLost(false);
    } catch (_) {
      // Still failed to connect (SocketException, timeout, etc.)
      if (mounted) {
        MimoSnackBar.showError(
          context,
          message: 'Vẫn không thể kết nối. Vui lòng thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent popping with back button
      child: Scaffold(
        backgroundColor: Colors.black54, // Dim background
        body: Center(
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.all(32),
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: kIsWeb
                        ? const Icon(
                            Icons.wifi_off_rounded,
                            size: 80,
                            color: AppColors.textSecondary,
                          )
                        : Lottie.asset(
                            'assets/animations/LostConnection.json',
                            repeat: true,
                            errorBuilder: (context, error, stack) => const Icon(
                              Icons.wifi_off_rounded,
                              size: 80,
                              color: AppColors.textSecondary,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Mất Kết Nối',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Không thể kết nối đến máy chủ. Vui lòng kiểm tra đường truyền mạng hoặc thử lại.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _checking ? null : _retry,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                        ),
                      ),
                      icon: _checking
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh, color: Colors.white),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _checking ? 'Đang thử lại...' : 'Thử lại',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
