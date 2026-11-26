import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/services/mt5_candle_service.dart';
import 'package:trader_log/services/trade_chart_window.dart';

Trade _trade({
  String symbol = 'XAUUSD-ECNc',
  DateTime? open,
  DateTime? close,
}) {
  final entry = open ?? DateTime.utc(2026, 11, 24, 8, 15, 24, 500);
  return Trade(
    id: 't1',
    ticket: '1',
    positionId: 'p1',
    symbol: symbol,
    type: TradeType.buy,
    volume: 0.1,
    openPrice: 3584.166,
    closePrice: 3573.471,
    stoploss: 3570,
    takeProfit: 3630,
    openTime: entry,
    closeTime: close ?? entry.add(const Duration(minutes: 35)),
    profit: 10,
    commission: 0,
    swap: 0,
    fee: 0,
    netProfit: 10,
    closeReason: CloseReason.manual,
    createdAt: entry,
    accountId: 'a1',
  );
}

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

Map<String, dynamic> _candle(int time, double price) => <String, dynamic>{
      'timestamp': time,
      'time': DateTime.fromMillisecondsSinceEpoch(time * 1000, isUtc: true)
          .toIso8601String(),
      'open': price,
      'high': price + 2,
      'low': price - 2,
      'close': price + 1,
      'tickVolume': 6317,
      'spread': 240,
      'realVolume': 0.0,
    };

Map<String, dynamic> _mt5Response({
  required String symbol,
  required String timeframe,
  required List<Map<String, dynamic>> candles,
  String? reason,
  String broker = 'Exness Technologies Ltd',
  String sessionStart = '2026-11-23T23:00:00Z',
  String sessionEnd = '2026-11-24T21:45:00Z',
}) =>
    <String, dynamic>{
      'symbol': symbol,
      'date': '2026-11-24',
      'timeframe': timeframe,
      'source': 'mt5',
      'broker': broker,
      'timezone': 'UTC',
      'sessionStart': sessionStart,
      'sessionEnd': sessionEnd,
      'reason': reason,
      'count': candles.length,
      'candles': candles,
    };

void main() {
  group('Mt5CandleService', () {
    test('sends the exact broker symbol, execution date and M15 timeframe',
        () async {
      final trade = _trade();
      final client = MockClient((request) async {
        expect(request.url.host, '127.0.0.1');
        expect(request.url.path, '/api/mt5/candles');
        expect(request.url.queryParameters['symbol'], 'XAUUSD-ECNc');
        expect(request.url.queryParameters['date'], '2026-11-24');
        expect(request.url.queryParameters['timeframe'], 'M15');
        return _json(_mt5Response(
          symbol: 'XAUUSD-ECNc',
          timeframe: 'M15',
          candles: [_candle(1795392000, 3584.166)],
        ));
      });

      final series = await Mt5CandleService(
        baseUrl: 'http://127.0.0.1:3000',
        client: client,
      ).loadForTrade(trade, interval: '15m');

      expect(series.symbol, 'XAUUSD-ECNc');
      expect(series.ticker, 'XAUUSD-ECNc');
      expect(series.source, 'mt5');
      expect(series.broker, 'Exness Technologies Ltd');
      expect(series.date, '2026-11-24');
      expect(series.sessionStart, DateTime.utc(2026, 11, 23, 23));
      expect(series.sessionEnd, DateTime.utc(2026, 11, 24, 21, 45));
      expect(series.sessionReason, isNull);
    });

    test('keeps the whole broker session and MT5 volume details', () async {
      final trade = _trade();
      // Deliberately unsorted and duplicated: the real worker sorts/dedupes,
      // and the client applies the same guarantee before handing data to chart.
      final candles = [
        _candle(1795448700, 3573.4), // after exit
        _candle(1795402500, 3584.1), // entry bar
        _candle(1795392000, 3584.166), // before entry
        _candle(1795402500, 3584.1), // duplicate
      ];
      final client = MockClient((_) async => _json(_mt5Response(
            symbol: trade.symbol,
            timeframe: 'M15',
            candles: candles,
          )));

      final series = await Mt5CandleService(client: client).loadForTrade(
        trade,
        interval: '15m',
      );

      expect(series.candles.map((c) => c.time).toList(), [
        1795392000,
        1795402500,
        1795448700,
      ]);
      expect(series.candles.first.tickVolume, 6317);
      expect(series.candles.first.spread, 240);
      expect(series.candles.first.realVolume, 0.0);
      // A broker-reported 0 is not fabricated real volume.
      expect(series.candles.first.volume, isNull);
      expect(series.candles.first.toChartJson()['tickVolume'], 6317);
      expect(series.candles.first.toChartJson()['spread'], 240.0);
      expect(series.candles.first.toChartJson()['realVolume'], 0.0);
    });

    test('maps every chart interval to the exact MT5 timeframe', () async {
      final expected = <String, String>{
        '1m': 'M1',
        '5m': 'M5',
        '15m': 'M15',
        '30m': 'M30',
        '1h': 'H1',
        '4h': 'H4',
        '1d': 'D1',
      };
      for (final entry in expected.entries) {
        final client = MockClient((request) async {
          expect(request.url.queryParameters['timeframe'], entry.value);
          return _json(_mt5Response(
            symbol: 'XAUUSD-ECNc',
            timeframe: entry.value,
            candles: [_candle(1795392000, 1)],
          ));
        });
        final series = await Mt5CandleService(client: client).loadForTrade(
          _trade(),
          interval: entry.key,
        );
        expect(series.interval, entry.key);
      }
    });

    test('supports an adjacent session date override', () async {
      final client = MockClient((request) async {
        expect(request.url.queryParameters['date'], '2026-11-25');
        return _json(_mt5Response(
          symbol: 'XAUUSD-ECNc',
          timeframe: 'M15',
          candles: [_candle(1795392000, 1)],
        ));
      });
      final series = await Mt5CandleService(client: client).loadForTrade(
        _trade(),
        interval: '15m',
        date: DateTime.utc(2026, 11, 25, 3),
      );
      expect(series.date, '2026-11-25');
    });

    test('invalid intervals fail before any request', () async {
      final client = MockClient((_) async => _json(<String, dynamic>{}));
      await expectLater(
        Mt5CandleService(client: client)
            .loadForTrade(_trade(), interval: '2h'),
        throwsA(
          isA<Mt5CandleException>().having(
            (error) => error.code,
            'code',
            'unsupported_timeframe',
          ),
        ),
      );
    });

    test('surfaces broker-specific HTTP errors', () async {
      final client = MockClient((_) async => _json(<String, dynamic>{
            'statusCode': 404,
            'code': 'unknown_symbol',
            'message': 'Broker symbol was not found.',
          }, status: 404));
      await expectLater(
        Mt5CandleService(client: client)
            .loadForTrade(_trade(), interval: '15m'),
        throwsA(
          isA<Mt5CandleException>()
              .having((error) => error.code, 'code', 'unknown_symbol')
              .having(
                (error) => error.message,
                'message',
                'Broker symbol was not found.',
              ),
        ),
      );
    });

    test('exposes a clean empty result with a weekend reason', () async {
      final client = MockClient((_) async => _json(_mt5Response(
            symbol: 'XAUUSD-ECNc',
            timeframe: 'M15',
            candles: const [],
            reason: 'no_data_for_date',
          )));
      final series = await Mt5CandleService(client: client).loadForTrade(
        _trade(),
        interval: '15m',
      );
      expect(series.candles, isEmpty);
      expect(series.sessionReason, 'no_data_for_date');
      expect(series.sourceNote, contains('no_data_for_date'));
    });

    test('latest maps one real broker candle', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/mt5/latest');
        expect(request.url.queryParameters['count'], '1');
        return _json(_mt5Response(
          symbol: 'XAUUSDc',
          timeframe: 'M15',
          candles: [_candle(1795392000, 3584.166)],
        ));
      });
      final candle = await Mt5CandleService(client: client).latest(
        symbol: 'XAUUSDc',
        interval: '15m',
      );
      expect(candle.time, 1795392000);
      expect(candle.tickVolume, 6317);
    });
  });

  group('TradeCandleService is MT5-only', () {
    test('returns the confirmed MT5 series and broker metadata', () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        return _json(_mt5Response(
          symbol: 'XAUUSD-ECNc',
          timeframe: 'M15',
          candles: [_candle(1795392000, 3584.166)],
        ));
      });

      final series = await TradeCandleService(client: client)
          .loadForTrade(_trade(), interval: '15m');

      expect(paths, <String>['/api/mt5/candles']);
      expect(series.source, 'mt5');
      expect(series.broker, 'Exness Technologies Ltd');
      expect(series.ticker, 'XAUUSD-ECNc');
    });

    test('propagates MT5 failures without requesting another provider', () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        return _json(<String, dynamic>{
          'statusCode': 503,
          'code': 'mt5_disconnected',
          'message': 'MT5 terminal is disconnected.',
        }, status: 503);
      });

      await expectLater(
        TradeCandleService(client: client)
            .loadForTrade(_trade(), interval: '15m'),
        throwsA(
          isA<Mt5CandleException>()
              .having((error) => error.code, 'code', 'mt5_disconnected')
              .having((error) => error.message, 'message',
                  'MT5 terminal is disconnected.'),
        ),
      );
      expect(paths, <String>['/api/mt5/candles']);
    });

    test('rejects a response that is not confirmed as MT5', () async {
      final client = MockClient((_) async => _json(<String, dynamic>{
            'source': 'other',
            'candles': <dynamic>[],
          }));
      await expectLater(
        TradeCandleService(client: client)
            .loadForTrade(_trade(), interval: '15m'),
        throwsA(
          isA<Mt5CandleException>()
              .having((error) => error.code, 'code', 'unexpected_source'),
        ),
      );
    });
  });

  test('auto interval stays inside the chart timeframe allowlist', () {
    expect(TradeChartWindow.isSupported(Mt5CandleService.autoInterval(_trade())), isTrue);
  });
}
