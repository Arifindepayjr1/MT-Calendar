import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trader_log/model/journal.model.dart';
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/screens/trade_detail.screen.dart';
import 'package:trader_log/services/mt5_candle_service.dart';

import 'support/strategy_fixtures.dart';

void main() {
  testWidgets(
    'trade detail lists the signed-in user saved strategies and stores their ids',
    (tester) async {
      final now = DateTime.now();
      final open = DateTime(now.year, now.month, now.day, 8, 15).toUtc();
      final close = open.add(const Duration(minutes: 35));
      final trade = Trade(
        id: 't-saved-strategy',
        ticket: '12345',
        positionId: 'p1',
        symbol: 'XAUUSD-ECNc',
        type: TradeType.buy,
        volume: 0.1,
        openPrice: 3584.166,
        closePrice: 3573.471,
        stoploss: 3570,
        takeProfit: 3630,
        openTime: open,
        closeTime: close,
        profit: 10,
        commission: 0,
        swap: 0,
        fee: 0,
        netProfit: 10,
        closeReason: CloseReason.manual,
        createdAt: open,
        accountId: 'a1',
      );

      final mt5Client = MockClient((request) async {
        expect(request.url.path, '/api/mt5/candles');
        return http.Response(
          jsonEncode(<String, dynamic>{
            'symbol': trade.symbol,
            'date': Mt5CandleService.formatDate(open),
            'timeframe': 'M15',
            'source': 'mt5',
            'broker': 'Exness Technologies Ltd',
            'timezone': 'UTC',
            'sessionStart': open.toIso8601String(),
            'sessionEnd': close.toIso8601String(),
            'reason': 'no_broker_history',
            'count': 0,
            'candles': const <dynamic>[],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      });

      Journal? saved;
      final strategyRequests = <http.Request>[];
      final strategyApi = fakeStrategyApi(
        token: 'test-token',
        requests: strategyRequests,
      );

      await tester.pumpWidget(MaterialApp(
        home: TradeDetailScreen(
          trade: trade,
          currency: 'USD',
          accountLabel: 'Exness 12345',
          initialJournal: null,
          client: mt5Client,
          strategyApi: strategyApi,
          onJournalSaved: (journal) => saved = journal,
        ),
      ));
      await tester.pumpAndSettle();

      expect(
        strategyRequests.any(
          (request) => request.url.path.endsWith('/api/strategies/drafts'),
        ),
        isTrue,
        reason: 'the trade detail must load the signed-in user saved setups',
      );

      await tester.tap(find.text('Edit Journal Entry'));
      await tester.pumpAndSettle();

      final savedChip = find.widgetWithText(FilterChip, 'London Sweep');
      await tester.scrollUntilVisible(savedChip, 300);
      await tester.pumpAndSettle();
      expect(savedChip, findsOneWidget);

      await tester.tap(savedChip);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Journal Entry'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      final journal = saved!;
      expect(journal.strategyNames, contains('London Sweep'));
      expect(journal.strategyIds, contains('draft_1'));
    },
  );
}
