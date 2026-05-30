import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Wraps [child] in a [MaterialApp.router] with a minimal [GoRouter]
/// that renders [child] at '/test'.
Widget testApp(Widget child) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (context, state) => child),
      GoRoute(path: '/login', builder: (context, state) => const Scaffold(body: Text('Login'))),
      GoRoute(path: '/app/home', builder: (context, state) => const Scaffold(body: Text('Home'))),
      GoRoute(path: '/onboarding/step-5', builder: (context, state) => const Scaffold(body: Text('Step5'))),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

/// Pumps [child] inside a [testApp] and waits for the first frame.
Future<void> pumpTestApp(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(testApp(child));
  await tester.pump();
}
