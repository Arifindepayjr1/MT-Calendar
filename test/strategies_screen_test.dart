import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:trader_log/main.dart';
import 'package:trader_log/model/strategy_playbook.model.dart';
import 'package:trader_log/screens/strategies.screen.dart';
import 'package:trader_log/services/strategy_api_service.dart';

import 'support/strategy_fixtures.dart';

Future<void> _pumpStrategiesScreen(
  WidgetTester tester, {
  StrategyApiService? api,
}) async {
  // A 390px-wide, tall viewport matches the target phone while keeping every
  // lazily built ListView card available for assertions.
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(
    home: StrategiesScreen(
      accountName: 'Alex',
      api: api ?? fakeStrategyApi(),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('strategies screen shows the playbook overview', (tester) async {
    await _pumpStrategiesScreen(tester);

    expect(find.text('My Strategies'), findsOneWidget);
    expect(find.text('Manage your trading setups and rules'), findsOneWidget);
    expect(find.text('+ Create'), findsOneWidget);
    expect(find.text('Setups'), findsOneWidget);
    expect(find.text('Active Sets'), findsOneWidget);
    expect(find.text('Executions'), findsOneWidget);
    expect(find.text('Logged'), findsOneWidget);
    expect(find.text('Net Return'), findsOneWidget);
    expect(find.text(r'+$4,820.50'), findsOneWidget);
    expect(find.text('66.7% Win'), findsOneWidget);

    for (final name in [
      'ICT Silver Bullet',
      'London Breakout',
      'ICT Judas Swing',
      'ICT OTE',
    ]) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
    expect(find.text(r'+$2,140'), findsOneWidget);
    expect(find.text(r'+$2,840'), findsOneWidget);
    expect(find.text(r'+$380'), findsOneWidget);
    final negativePnl = tester.widget<Text>(find.text(r'-$539.50'));
    expect(negativePnl.style?.color, const Color(0xFFFF7C7C));
    expect(find.textContaining('DISCIPLINE RULE:'), findsOneWidget);
  });

  testWidgets('saved setups appear inside All Setups for their owner',
      (tester) async {
    final requests = <http.Request>[];
    final api = fakeStrategyApi(
      token: 'jwt-from-auth-store',
      requests: requests,
    );
    await _pumpStrategiesScreen(tester, api: api);

    expect(find.textContaining('All Setups (6)'), findsOneWidget);
    expect(find.textContaining('ICT / SMC (5)'), findsOneWidget);
    expect(find.textContaining('YOUR SAVED STRATEGIES'), findsNothing);
    expect(find.text('YOUR SETUP'), findsNWidgets(2));
    expect(find.text('London Sweep'), findsOneWidget);
    expect(find.text('NY Opening Drive'), findsOneWidget);

    final drafts = requests
        .where(
          (request) => request.url.path.endsWith('/api/strategies/drafts'),
        )
        .toList();
    expect(drafts, hasLength(1));
    expect(drafts.single.headers['authorization'],
        'Bearer jwt-from-auth-store');

    // The saved setup opens the exact same detail screen as a shared playbook.
    await tester.tap(find.text('London Sweep'));
    await tester.pumpAndSettle();
    expect(find.text('Strategy Details'), findsOneWidget);
    expect(find.text('Your Setup'), findsOneWidget);
    expect(find.text('Win Rate'), findsOneWidget);
    expect(find.text('Profit Factor'), findsOneWidget);
    expect(find.text('Assigned MT5 Trades'), findsOneWidget);
    expect(find.text('Wait for the sweep, then enter on displacement.'),
        findsOneWidget);
    expect(find.text('TP1 at 2R'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('Price Action (1)'));
    await tester.tap(find.textContaining('Price Action (1)'));
    await tester.pumpAndSettle();
    expect(find.text('London Breakout'), findsOneWidget);
    expect(find.text('London Sweep'), findsNothing);
  });

  testWidgets('saving returns to the list with the new draft visible',
      (tester) async {
    final requests = <http.Request>[];
    final api = fakeStrategyApi(
      token: 'jwt-from-auth-store',
      requests: requests,
      drafts: <Map<String, dynamic>>[],
    );
    await _pumpStrategiesScreen(tester, api: api);
    expect(find.textContaining('All Setups (4)'), findsOneWidget);
    expect(find.textContaining('YOUR SAVED STRATEGIES'), findsNothing);

    await tester.tap(find.text('+ Create'));
    await tester.pumpAndSettle();
    expect(find.text('Create Strategy'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('strategy-name-field')),
      'Fresh Draft',
    );
    await tester.tap(find.text('Save Strategy'));
    await tester.pumpAndSettle();

    expect(find.text('Create Strategy'), findsNothing);
    expect(find.text('My Strategies'), findsOneWidget);
    expect(find.textContaining('All Setups (5)'), findsOneWidget);
    expect(find.textContaining('YOUR SAVED STRATEGIES'), findsNothing);
    expect(find.text('YOUR SETUP'), findsOneWidget);
    expect(find.text('Fresh Draft'), findsOneWidget);
    expect(find.text('Strategy saved to your account.'), findsOneWidget);

    expect(
      requests
          .where((request) => request.url.path.endsWith('/api/strategies/drafts'))
          .length,
      2,
      reason: 'drafts reload once on open and once after the save result',
    );
  });

  testWidgets('category chips filter the visible playbooks', (tester) async {
    await _pumpStrategiesScreen(tester);

    expect(find.textContaining('All Setups (4)'), findsOneWidget);
    expect(find.textContaining('ICT / SMC (3)'), findsOneWidget);
    expect(find.textContaining('Price Action (1)'), findsOneWidget);

    await tester.tap(find.textContaining('ICT / SMC (3)'));
    await tester.pumpAndSettle();
    expect(find.text('ICT Silver Bullet'), findsOneWidget);
    expect(find.text('ICT Judas Swing'), findsOneWidget);
    expect(find.text('ICT OTE'), findsOneWidget);
    expect(find.text('London Breakout'), findsNothing);

    // The third chip sits just beyond a 390px viewport and must be scrolled
    // into view inside the horizontal filter strip.
    await tester.ensureVisible(find.textContaining('Price Action (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Price Action (1)'));
    await tester.pumpAndSettle();
    expect(find.text('London Breakout'), findsOneWidget);
    expect(find.text('ICT Silver Bullet'), findsNothing);
  });

  testWidgets('empty state preview can be expanded', (tester) async {
    await _pumpStrategiesScreen(tester);

    expect(find.text('No playbooks yet'), findsNothing);
    await tester.tap(find.textContaining('View Empty State Preview').first);
    await tester.pumpAndSettle();
    expect(find.text('No playbooks yet'), findsOneWidget);

    await tester.tap(find.textContaining('Hide Empty State Preview').first);
    await tester.pumpAndSettle();
    expect(find.text('No playbooks yet'), findsNothing);
  });

  testWidgets('strategies root tab opens the new screen', (tester) async {
    await tester.pumpWidget(MyApp(strategyApi: fakeStrategyApi()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Strategies').first);
    await tester.pumpAndSettle();

    expect(find.text('My Strategies'), findsOneWidget);
    expect(find.text('Manage your trading setups and rules'), findsOneWidget);
  });

  testWidgets('tapping a playbook card opens its detail screen', (tester) async {
    await _pumpStrategiesScreen(tester);

    await tester.tap(find.text('ICT Silver Bullet'));
    await tester.pumpAndSettle();

    expect(find.text('Strategy Details'), findsOneWidget);
    expect(find.text('Live Rulebook Active'), findsOneWidget);
    expect(find.text(r'+$2,140.00'), findsOneWidget);
  });

  testWidgets('create button opens the strategy form', (tester) async {
    await _pumpStrategiesScreen(tester);

    await tester.tap(find.text('+ Create'));
    await tester.pumpAndSettle();

    expect(find.text('Create Strategy'), findsOneWidget);
    expect(find.text('Save Strategy'), findsOneWidget);
  });

  test('backend overview decodes with consistent filters and data', () {
    final overview = StrategyOverview.fromJson(strategyOverviewJson());
    expect(overview.playbooks, hasLength(4));
    expect(overview.executions, 42);
    expect(overview.netReturn, 4820.5);
    expect(
      overview.playbooks
          .where((playbook) => playbook.matches(PlaybookFilter.ictSmc))
          .length,
      3,
    );
    expect(
      overview.playbooks
          .where((playbook) => playbook.matches(PlaybookFilter.priceAction))
          .length,
      1,
    );
    final ote = overview.playbooks.last;
    expect(ote.reviewNeeded, isTrue);
    expect(ote.netPnl, -539.50);
    expect(ote.tags, contains('● 67% • Review Needed'));
    expect(
      overview.playbooks.where((playbook) => playbook.favorite).map((p) => p.name),
      ['London Breakout'],
    );
  });
}
