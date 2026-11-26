import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trader_log/model/journal.model.dart';
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/screens/calendar.screen.dart';
import 'package:trader_log/services/mt5_candle_service.dart';

/// End-to-end widget test: tapping a completed trade in Trade History must
/// request real broker history from the NestJS MT5 endpoint, never a Yahoo
/// proxy, and must label the chart with the broker confirmed by MT5.
void main() {
  testWidgets('completed trade loads MT5 candles and shows the MT5 badge',
      (tester) async {
    final localNow = DateTime.now();
    final open = DateTime(
      localNow.year,
      localNow.month,
      localNow.day,
      8,
      15,
    ).toUtc();
    final close = open.add(const Duration(minutes: 35));
    final trade = Trade(
      id: 't-mt5',
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

    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      expect(request.url.path, '/api/mt5/candles');
      final beforeEntry = open.subtract(const Duration(minutes: 15));
      final afterExit = close.add(const Duration(minutes: 15));
      Map<String, dynamic> candle(DateTime time, double price) =>
          <String, dynamic>{
            'timestamp': time.millisecondsSinceEpoch ~/ 1000,
            'time': time.toIso8601String(),
            'open': price,
            'high': price + 2,
            'low': price - 2,
            'close': price + 1,
            'tickVolume': 6317,
            'spread': 240,
            'realVolume': 0,
          };
      return http.Response(
        jsonEncode(<String, dynamic>{
          'symbol': 'XAUUSD-ECNc',
          'date': Mt5CandleService.formatDate(open),
          'timeframe': 'M15',
          'source': 'mt5',
          'broker': 'Exness Technologies Ltd',
          'timezone': 'UTC',
          'sessionStart': beforeEntry.toIso8601String(),
          'sessionEnd': afterExit.toIso8601String(),
          'reason': null,
          'count': 2,
          'candles': [
            candle(beforeEntry, 3584.1),
            candle(afterExit, 3573.4),
          ],
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(MaterialApp(
      home: CalendarScreen(
        trades: [trade],
        accountName: 'Trader',
        brokerAndNumber: 'Exness 12345',
        currency: 'USD',
        initialDeposit: 1000,
        dayNotes: const <String, String>{},
        journals: const <String, Journal>{},
        onDayNoteChanged: (_, _) {},
        onJournalChanged: (_, _) {},
        onGoHome: () {},
        client: client,
      ),
    ));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Executions'),
      600,
      scrollable: scrollable,
    );
    final tradeCard = find.ancestor(
      of: find.textContaining('XAUUSD-ECNc · BUY'),
      matching: find.byType(InkWell),
    );
    await tester.scrollUntilVisible(tradeCard, 300, scrollable: scrollable);
    await tester.pumpAndSettle();
    expect(tradeCard, findsOneWidget,
        reason: 'the completed trade should be visible in Trade History');
    await tester.tap(tradeCard);
    await tester.pumpAndSettle();

    final mt5 = requests
        .where((request) => request.url.path == '/api/mt5/candles')
        .toList();
    expect(mt5, hasLength(1), reason: 'exactly one MT5 history request');
    expect(mt5.single.url.queryParameters['symbol'], 'XAUUSD-ECNc');
    expect(mt5.single.url.queryParameters['date'],
        Mt5CandleService.formatDate(open));
    expect(
      requests.map((request) => request.url.path),
      isNot(contains('/api/candles')),
      reason: 'the Yahoo proxy must never be called by the chart',
    );

    expect(
      find.text(
          'Data Source: MT5 | Broker: Exness Technologies Ltd | Symbol: XAUUSD-ECNc'),
      findsOneWidget,
    );
    expect(find.textContaining('Yahoo'), findsNothing);
    expect(find.textContaining('Loading MT5 broker session'), findsNothing);
  });
}
