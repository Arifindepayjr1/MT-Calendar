import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trader_log/screens/create_strategy.screen.dart';
import 'package:trader_log/services/strategy_api_service.dart';

import 'support/strategy_fixtures.dart';

Future<void> _pumpCreateScreen(
  WidgetTester tester, {
  StrategyApiService? api,
}) async {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    home: CreateStrategyScreen(api: api ?? fakeStrategyApi()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('create form shows every section and sticky actions',
      (tester) async {
    await _pumpCreateScreen(tester);

    expect(find.text('Create Strategy'), findsOneWidget);
    expect(find.text('Draft auto-saved'), findsOneWidget);

    for (final section in [
      'Basic Setup',
      'Playbook Narrative',
      'Entry Conditions',
      'Risk & Exit Framework',
      'Pre-Flight Discipline',
      'Active Sessions & Timeframes',
    ]) {
      expect(find.text(section), findsOneWidget, reason: section);
    }

    expect(find.text('Strategy name'), findsOneWidget);
    expect(find.text('ICT / SMC'), findsOneWidget);
    expect(find.text('Markdown supported · 0/800'), findsOneWidget);
    expect(find.text('Take-profit rule'), findsOneWidget);
    expect(find.text('Stop-loss rule'), findsOneWidget);
    expect(find.text('Invalidation rule'), findsOneWidget);
    expect(find.text('+ Add Entry Condition'), findsOneWidget);
    expect(find.text('+ Add Custom Discipline Rule'), findsOneWidget);

    for (final chip in ['London', 'New York', '15M', '5M', '1M']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }

    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Save Strategy'), findsOneWidget);
  });

  testWidgets('entry conditions and custom discipline rules can be added',
      (tester) async {
    await _pumpCreateScreen(tester);

    expect(find.text('New entry trigger'), findsNothing);
    await tester.ensureVisible(find.text('+ Add Entry Condition'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Add Entry Condition'));
    await tester.pumpAndSettle();
    expect(find.text('New entry trigger'), findsOneWidget);

    await tester.ensureVisible(find.text('+ Add Custom Discipline Rule'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+ Add Custom Discipline Rule'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('custom-rule-field')),
      'No trading during news spike',
    );
    await tester.tap(find.byTooltip('Add rule'));
    await tester.pumpAndSettle();

    expect(find.text('No trading during news spike'), findsOneWidget);
    expect(find.byKey(const Key('custom-rule-field')), findsNothing);
  });

  testWidgets('narrative counter and save validation work', (tester) async {
    await _pumpCreateScreen(tester);

    await tester.enterText(
      find.byKey(const Key('strategy-narrative-field')),
      'abc',
    );
    await tester.pumpAndSettle();
    expect(find.text('Markdown supported · 3/800'), findsOneWidget);

    await tester.tap(find.text('Save Strategy'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a strategy name before saving.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('strategy-name-field')),
      'London Sweep',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Strategy'));
    await tester.pumpAndSettle();

    expect(
      find.text('Draft "London Sweep" saved to backend (draft_1).'),
      findsOneWidget,
    );
    expect(find.text('Saved to backend'), findsOneWidget);
  });

  testWidgets('save sends the complete draft to the backend', (tester) async {
    final requests = <http.Request>[];
    await _pumpCreateScreen(
      tester,
      api: fakeStrategyApi(requests: requests),
    );

    await tester.enterText(
      find.byKey(const Key('strategy-name-field')),
      'London Sweep',
    );
    await tester.enterText(
      find.byKey(const Key('strategy-narrative-field')),
      'Sweep the London low, then trade the displacement.',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Strategy'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, endsWith('/api/strategies'));

    final payload = jsonDecode(request.body) as Map<String, dynamic>;
    expect(payload['name'], 'London Sweep');
    expect(payload['category'], 'ictSmc');
    expect(payload['categories'], ['ictSmc']);
    expect(
      payload['narrative'],
      'Sweep the London low, then trade the displacement.',
    );
    expect(payload['entryConditions'], isA<List<dynamic>>());
    expect(
      (payload['entryConditions'] as List<dynamic>).first,
      containsPair('text', 'Mark the macro window on 15M'),
    );
    expect(payload['takeProfitRule'], contains('TP1 at 2R'));
    expect(payload['disciplineRules'], isA<List<dynamic>>());
    expect(payload['sessions'], contains('London'));
    expect(payload['intervals'], contains('15M'));
  });
}
