import 'package:flutter_test/flutter_test.dart';
import 'package:trader_log/main.dart';

void main() {
  testWidgets('root navigation opens the Calendar section', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    for (final label in [
      'Home',
      'Calendar',
      'Strategies',
      'Statistics',
      'Settings',
    ]) {
      expect(
        find.text(label),
        findsWidgets,
        reason: '$label tab should be visible',
      );
    }

    await tester.tap(find.text('Calendar').first);
    await tester.pumpAndSettle();

    expect(find.text('Track your trading performance'), findsOneWidget);
  });
}
