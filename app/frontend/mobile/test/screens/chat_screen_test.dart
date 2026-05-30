import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/chat/chat_screen.dart';

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

      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('quick-action chips are rendered', (tester) async {
      await pumpTestApp(tester, const ChatScreen());

      expect(find.textContaining('Tuần'), findsOneWidget);
      expect(find.textContaining('Phở'), findsOneWidget);
    });

    testWidgets('typing a message updates the text field', (tester) async {
      await pumpTestApp(tester, const ChatScreen());

      final field = find.byType(TextField);
      await tester.enterText(field, 'cà phê 35k');
      expect(find.text('cà phê 35k'), findsOneWidget);
    });
  });
}
