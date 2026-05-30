import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/home/home_screen.dart';
import 'package:mobile/widgets/skeleton.dart';

import '../helpers/test_app.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('renders loading skeleton on first paint', (tester) async {
      await pumpTestApp(tester, const HomeScreen());

      expect(find.byType(SkeletonCard), findsWidgets);
    });

    testWidgets('tab bar has Story and Giao dịch tabs', (tester) async {
      await pumpTestApp(tester, const HomeScreen());

      expect(find.textContaining('Story'), findsAtLeast(1));
      expect(find.textContaining('Giao dịch'), findsAtLeast(1));
    });

    testWidgets('does not throw on initial render', (tester) async {
      await expectLater(
        () => pumpTestApp(tester, const HomeScreen()),
        returnsNormally,
      );
    });
  });
}
