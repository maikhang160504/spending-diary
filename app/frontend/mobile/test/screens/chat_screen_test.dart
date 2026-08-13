import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spending_diary/screens/chat/chat_screen.dart';

import '../helpers/test_app.dart';

void main() {
  group('ChatScreen', () {
    testWidgets('renders chat header and composer', (tester) async {
      await pumpTestApp(tester, const ChatScreen());

      expect(find.textContaining('Mimo'), findsAtLeast(1));
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('send button is present', (tester) async {
      await pumpTestApp(tester, const ChatScreen());

      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('quick-action chips are rendered', (tester) async {
      await pumpTestApp(tester, const ChatScreen());

      // Since suggestions are shuffled, we check if at least one common keyword is rendered.
      final keywords = ['chi tiêu', 'tháng', 'tiêu', 'hạn mức', 'mục tiêu', 'báo cáo', 'tuần', '35k', '45k', '50k'];
      bool foundAny = false;
      for (final kw in keywords) {
        if (tester.any(find.textContaining(kw))) {
          foundAny = true;
          break;
        }
      }
      expect(foundAny, isTrue);
    });

    testWidgets('typing a message updates the text field', (tester) async {
      await pumpTestApp(tester, const ChatScreen());

      final field = find.byType(TextField);
      await tester.enterText(field, 'cà phê 35k');
      expect(find.text('cà phê 35k'), findsOneWidget);
    });
  });
}
