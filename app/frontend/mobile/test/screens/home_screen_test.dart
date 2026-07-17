import 'package:flutter_test/flutter_test.dart';
import 'package:SpendingDiary/screens/home/home_screen.dart';
import 'package:SpendingDiary/widgets/skeleton.dart';

import '../helpers/test_app.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('renders loading skeleton on first paint', (tester) async {
      await tester.runAsync(() async {
        await pumpTestApp(tester, const HomeScreen());
        expect(find.byType(SkeletonCard), findsWidgets);
      });
    });

    testWidgets('tab bar has Story, Gallery, and Calendar tabs', (tester) async {
      await tester.runAsync(() async {
        await pumpTestApp(tester, const HomeScreen());

        expect(find.textContaining('Story'), findsAtLeast(1));
        expect(find.textContaining('Gallery'), findsAtLeast(1));
        expect(find.textContaining('Calendar'), findsAtLeast(1));
      });
    });
  });
}
