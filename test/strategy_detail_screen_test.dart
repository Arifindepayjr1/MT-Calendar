import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trader_log/model/strategy_detail.model.dart';
import 'package:trader_log/screens/strategy_detail.screen.dart';

import 'support/strategy_fixtures.dart';

Future<void> _pumpDetail(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    home: StrategyDetailScreen(
      strategyId: 'pb_silver_bullet',
      playbookName: 'ICT Silver Bullet',
      api: fakeStrategyApi(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('detail screen shows backend hero, telemetry and actions',
      (tester) async {
    await _pumpDetail(tester);

    expect(find.text('Strategy Details'), findsOneWidget);
    expect(find.text('ICT Silver Bullet'), findsOneWidget);
    expect(find.text('Live Rulebook Active'), findsOneWidget);
    expect(find.text('MT5 Synced · 2m ago'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('London & NY AM Macro'), findsOneWidget);
    expect(find.text(r'+$2,140.00'), findsOneWidget);
    expect(find.text('+7.2%'), findsOneWidget);

    for (final value in ['71.4%', '2.85', '+2.41 R', '-1.8%']) {
      expect(find.text(value), findsOneWidget, reason: value);
    }

    expect(find.text('Assigned MT5 Trades'), findsOneWidget);
    expect(find.text('Assign MT5 Trades'), findsOneWidget);
    expect(find.text('Export Strategy Audit Report'), findsOneWidget);
  });

  testWidgets('rules card collapses and expands', (tester) async {
    await _pumpDetail(tester);

    expect(find.text('Rules & Verification'), findsOneWidget);
    expect(find.text('92.8%'), findsOneWidget);
    const entryRule = 'Mark the London/NY AM macro window on the 15M chart.';
    expect(find.text(entryRule), findsOneWidget);

    await tester.ensureVisible(find.text('Rules & Verification'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rules & Verification'));
    await tester.pumpAndSettle();
    expect(find.text(entryRule), findsNothing);

    await tester.tap(find.text('Rules & Verification'));
    await tester.pumpAndSettle();
    expect(find.text(entryRule), findsOneWidget);
  });

  testWidgets('assigned trade filter switches between wins and losses',
      (tester) async {
    await _pumpDetail(tester);

    expect(find.text(r'+$215.00'), findsOneWidget);
    expect(find.text(r'-$49.50'), findsOneWidget);

    await tester.ensureVisible(find.text('Losses'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Losses'));
    await tester.pumpAndSettle();

    expect(find.text(r'-$49.50'), findsOneWidget);
    expect(find.text(r'-$102.00'), findsOneWidget);
    expect(find.text(r'+$215.00'), findsNothing);

    await tester.tap(find.text('Wins'));
    await tester.pumpAndSettle();
    expect(find.text(r'+$215.00'), findsOneWidget);
    expect(find.text(r'-$49.50'), findsNothing);
  });

  test('backend detail decodes with consistent filters and telemetry', () {
    final detail = StrategyDetail.fromJson(strategyDetailJson());
    expect(detail.trades, hasLength(6));
    expect(
      detail.filteredTrades(StrategyTradeFilter.wins),
      hasLength(4),
    );
    expect(
      detail.filteredTrades(StrategyTradeFilter.losses),
      hasLength(2),
    );
    expect(detail.adherence, 92.8);
    expect(detail.profitFactor, 2.85);
    expect(detail.avgRMultiple, 2.41);
    expect(detail.maxDrawdown, -1.8);
  });
}
