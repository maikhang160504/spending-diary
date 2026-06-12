import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _googleLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    String? idToken;
    bool isFallbackUsed = false;

    debugPrint('[GoogleSignIn LOG] Bắt đầu đăng nhập bằng Google...');
    try {
      debugPrint(
        '[GoogleSignIn LOG] Cấu hình GoogleSignIn với scopes: [email, profile] và serverClientId: 388012082045-3t6pakclihrq25focvubq4eb6t2fbnap.apps.googleusercontent.com',
      );
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        serverClientId:
            '388012082045-g1ctihjmrv6i478p4ceqjo8nia6r3fma.apps.googleusercontent.com',
      );

      debugPrint('[GoogleSignIn LOG] Gọi googleSignIn.signIn()...');
      final account = await googleSignIn.signIn();

      if (account == null) {
        debugPrint(
          '[GoogleSignIn LOG] googleSignIn.signIn() trả về null (Có thể do người dùng hủy/back, hoặc lỗi cấu hình thầm lặng)',
        );
        setState(() => _googleLoading = false);
        return;
      }

      debugPrint('[GoogleSignIn LOG] Đăng nhập tài khoản Google thành công!');
      debugPrint('[GoogleSignIn LOG] Email: ${account.email}');
      debugPrint('[GoogleSignIn LOG] Tên hiển thị: ${account.displayName}');
      debugPrint('[GoogleSignIn LOG] ID người dùng: ${account.id}');

      debugPrint('[GoogleSignIn LOG] Yêu cầu thông tin Authentication...');
      final auth = await account.authentication;

      idToken = auth.idToken;
      final accessToken = auth.accessToken;

      debugPrint('[GoogleSignIn LOG] Đã lấy được Authentication:');
      debugPrint(
        ' - idToken: ${idToken != null ? "Độ dài ${idToken.length} ký tự (OK)" : "NULL"}',
      );
      debugPrint(
        ' - accessToken: ${accessToken != null ? "Độ dài ${accessToken.length} ký tự (OK)" : "NULL"}',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '[GoogleSignIn LOG] BỊ LỖI ở bước xác thực Google (signIn hoặc authentication):',
      );
      if (e is PlatformException) {
        debugPrint(' - Loại lỗi: PlatformException');
        debugPrint(' - Mã lỗi (code): ${e.code}');
        debugPrint(' - Tin nhắn (message): ${e.message}');
        debugPrint(' - Chi tiết (details): ${e.details}');

        // Hướng dẫn khắc phục lỗi phổ biến
        if (e.code == '10' || e.code == 'DEVELOPER_ERROR') {
          debugPrint('[GoogleSignIn TIP] Lỗi 10 / DEVELOPER_ERROR thường do:');
          debugPrint(
            ' 1. Chưa cấu hình SHA-1 của máy debug này vào Firebase / Google Cloud Console.',
          );
          debugPrint(
            ' 2. serverClientId (Web Client ID) bị cấu hình sai (đang dùng Android Client ID thay vì Web Client ID).',
          );
          debugPrint(
            ' 3. Tên package name của ứng dụng không khớp với cấu hình.',
          );
        } else if (e.code == '7') {
          debugPrint(
            '[GoogleSignIn TIP] Lỗi 7 (NETWORK_ERROR): Vui lòng kiểm tra lại kết nối mạng trên thiết bị/giả lập.',
          );
        }
      } else {
        debugPrint(' - Lỗi chung: $e');
      }
      debugPrint('[GoogleSignIn LOG] Stacktrace:\n$stackTrace');

      idToken = 'mock-google-token';
      isFallbackUsed = true;
    }

    if (idToken == null) {
      debugPrint(
        '[GoogleSignIn LOG] idToken bị NULL, tự động fallback sang tài khoản dev mock.',
      );
      idToken = 'mock-google-token';
      isFallbackUsed = true;
    }

    try {
      final api = ApiClient();
      await api.loginWithGoogle(idToken);
      if (!mounted) return;

      if (isFallbackUsed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Google Sign-In lỗi (SHA-1/Emulator). Đã tự động dùng tài khoản Dev Thử nghiệm!',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }

      try {
        final settings = await api.getSettings();
        if (!mounted) return;
        final ageGroup =
            settings['ageGroup'] as String? ?? settings['age_group'] as String?;
        final jobType =
            settings['jobType'] as String? ?? settings['job_type'] as String?;
        if ((ageGroup != null && ageGroup.isNotEmpty) ||
            (jobType != null && jobType.isNotEmpty)) {
          context.go(AppRoutes.home);
          return;
        }
      } catch (_) {}

      if (!mounted) return;
      context.go(AppRoutes.onboarding);
    } on ApiException catch (e) {
      setState(() => _error = e.localizedMessage);
    } catch (e) {
      setState(() => _error = 'Đăng nhập Google thất bại, thử lại sau');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Vui lòng nhập email và mật khẩu');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ApiClient();
      await api.login(email, pass);
      if (!mounted) return;

      try {
        final settings = await api.getSettings();
        if (!mounted) return;
        final ageGroup =
            settings['ageGroup'] as String? ?? settings['age_group'] as String?;
        final jobType =
            settings['jobType'] as String? ?? settings['job_type'] as String?;
        if ((ageGroup != null && ageGroup.isNotEmpty) ||
            (jobType != null && jobType.isNotEmpty)) {
          context.go(AppRoutes.home);
          return;
        }
      } catch (_) {}

      if (!mounted) return;
      context.go(AppRoutes.onboarding);
    } on ApiException catch (e) {
      setState(() => _error = e.localizedMessage);
    } catch (e) {
      setState(() => _error = 'Không thể kết nối đến máy chủ');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.teal),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              children: [
                const SizedBox(height: 32),
                // Logo + Title card (white bg so logo is visible on teal)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/logo/Logo.png',
                        width: 88,
                        height: 88,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => const Icon(
                          Icons.savings_outlined,
                          color: AppColors.teal,
                          size: 72,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Image.asset(
                        'assets/logo/Title.png',
                        height: 40,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stack) => const Text(
                          'Spending Diary',
                          style: TextStyle(
                            color: AppColors.teal,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Login card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 30,
                        offset: Offset(0, 20),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Email',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'your@email.com',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Mật khẩu',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _login(),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                      // Error message
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.danger,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {
                            // TODO: implement forgot password flow
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tính năng đang phát triển'),
                              ),
                            );
                          },
                          child: const Text(
                            'Quên mật khẩu?',
                            style: TextStyle(color: AppColors.teal),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _login,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Đăng nhập',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: AppColors.border),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'hoặc',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.muted),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: AppColors.border),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _googleLoading ? null : _loginWithGoogle,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: _googleLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'G',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF4285F4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Đăng nhập với Google',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Chưa có tài khoản? ',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.register),
                            child: const Text(
                              'Đăng ký ngay',
                              style: TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
