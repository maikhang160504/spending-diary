import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_diary/screens/auth/login_screen.dart';

import '../helpers/test_app.dart';

void main() {
  group('LoginScreen', () {
    testWidgets('renders email and password fields', (tester) async {
      await pumpTestApp(tester, const LoginScreen());

      expect(find.byType(TextField), findsAtLeast(2));
    });

    testWidgets('shows error when submitting empty fields', (tester) async {
      await pumpTestApp(tester, const LoginScreen());

      final loginBtn = find.widgetWithText(FilledButton, 'Đăng nhập');
      expect(loginBtn, findsOneWidget);

      await tester.tap(loginBtn);
      await tester.pump();

      expect(find.text('Vui lòng nhập email và mật khẩu'), findsOneWidget);
    });

    testWidgets('toggle password visibility button is present', (tester) async {
      await pumpTestApp(tester, const LoginScreen());

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('has link to register screen', (tester) async {
      await pumpTestApp(tester, const LoginScreen());

      expect(find.textContaining('Đăng ký'), findsAtLeast(1));
    });
  });
}
