import 'package:flutter_test/flutter_test.dart';
import 'package:spending_diary/screens/onboarding/onboarding_screen_1.dart';

import 'helpers/test_app.dart';

void main() {
  testWidgets('App renders onboarding intro', (WidgetTester tester) async {
    await pumpTestApp(tester, const OnboardingStep1());

    expect(find.text('Xin chào! Mình là Mimo 😊'), findsOneWidget);
  });
}
