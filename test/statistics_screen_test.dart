import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trader_log/screens/statistics.screen.dart';

void main() {
  testWidgets('statistics shows an honest empty audit state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StatisticsScreen(
          trades: [],
          accountName: 'Test Account',
          brokerAndNumber: 'Exness-MT5Real37',
          currency: 'USD',
          initialDeposit: 0,
          journals: {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Performance Analytics'), findsOneWidget);
    expect(find.text('Disciplined execution audit'), findsOneWidget);
    expect(find.text('No closed trades in this range'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.text('No rules logged yet'), findsOneWidget);
    expect(find.text('+\$4,820.50'), findsNothing);
    expect(find.text('66.7%'), findsNothing);
  });
}
