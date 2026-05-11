import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../routes/app_routes.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_spacing.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
                const SizedBox(height: 48),
                // App icon
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
                const SizedBox(height: 20),
                Text('SpendDiary', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('Nhật ký chi tiêu của bạn ✨', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
                const SizedBox(height: 40),
                // Login card
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
                      const TextField(
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'your@email.com',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text('Mật khẩu', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const TextField(
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text('Quên mật khẩu?', style: TextStyle(color: AppColors.teal)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => context.go(AppRoutes.home),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          child: const Text('Đăng nhập', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 20),
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
                              Text('Đăng nhập với Google', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Chưa có tài khoản? ', style: Theme.of(context).textTheme.bodySmall),
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.register),
                            child: const Text('Đăng ký ngay', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600, fontSize: 12)),
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