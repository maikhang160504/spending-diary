import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _emailError;
  String? _passError;
  String? _confirmError;
  String? _generalError;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    bool valid = true;
    setState(() {
      _emailError = null;
      _passError = null;
      _confirmError = null;
      _generalError = null;
    });

    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailError = 'Email không hợp lệ');
      valid = false;
    }
    if (_passCtrl.text.length < 8) {
      setState(() => _passError = 'Mật khẩu phải có ít nhất 8 ký tự');
      valid = false;
    }
    if (_confirmCtrl.text != _passCtrl.text) {
      setState(() => _confirmError = 'Mật khẩu xác nhận không khớp');
      valid = false;
    }
    return valid;
  }

  Future<void> _register() async {
    if (!_validate()) return;
    setState(() { _loading = true; _generalError = null; });
    try {
      final api = ApiClient();
      await api.register(_emailCtrl.text.trim(), _passCtrl.text, _emailCtrl.text.split('@')[0]);
      if (!mounted) return;
      context.go(AppRoutes.onboarding);
    } on ApiException catch (e) {
      setState(() => _generalError = e.localizedMessage);
    } catch (e) {
      setState(() => _generalError = 'Không thể kết nối đến máy chủ');
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
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 8))],
                  ),
                  child: const Center(child: Text('✨', style: TextStyle(fontSize: 36))),
                ),
                const SizedBox(height: 16),
                Text('Tạo tài khoản',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Bắt đầu quản lý chi tiêu thôi! 🚀',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 20))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Email', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'your@email.com',
                          prefixIcon: const Icon(Icons.mail_outline),
                          errorText: _emailError,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Mật khẩu', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline),
                          errorText: _passError,
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Xác nhận mật khẩu', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _confirmCtrl,
                        obscureText: _obscureConfirm,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _register(),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline),
                          errorText: _confirmError,
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                            onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Mật khẩu phải có ít nhất 8 ký tự',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                      // General error
                      if (_generalError != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                            const SizedBox(width: 6),
                            Expanded(child: Text(_generalError!, style: const TextStyle(color: AppColors.danger, fontSize: 12))),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _register,
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: _loading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Đăng ký', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(child: Divider(color: AppColors.border)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('hoặc', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                          ),
                          const Expanded(child: Divider(color: AppColors.border)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF4285F4))),
                              const SizedBox(width: 8),
                              Text('Đăng ký với Google', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Đã có tài khoản? ', style: Theme.of(context).textTheme.bodySmall),
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.login),
                            child: const Text('Đăng nhập', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600, fontSize: 12)),
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