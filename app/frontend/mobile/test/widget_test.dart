import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app.dart';

void main() {
  testWidgets('App renders onboarding intro', (WidgetTester tester) async {
    await tester.pumpWidget(const SpendDiaryApp());

    expect(find.text('Xin chao! Minh la Mimo 😊'), findsOneWidget);
  });
}
