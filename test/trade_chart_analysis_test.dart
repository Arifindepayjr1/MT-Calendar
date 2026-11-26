import 'package:flutter_test/flutter_test.dart';
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/services/trade_chart_message.dart';
import 'package:trader_log/services/trade_chart_markers.dart';
import 'package:trader_log/services/market_candle.dart';
import 'package:trader_log/services/mt5_candle_service.dart';
import 'package:trader_log/services/trade_chart_window.dart';
import 'package:trader_log/services/trade_level_analysis.dart';

Trade _trade({
  required TradeType type,
  required DateTime open,
  required DateTime close,
  double? sl,
  double? tp,
  CloseReason reason = CloseReason.unknown,
}) {
  return Trade(
    id: 't1',
    ticket: '1',
    positionId: 'p1',
    symbol: 'XAUUSD',
    type: type,
    volume: 0.1,
    openPrice: 2000,
    closePrice: 2010,
    stoploss: sl,
    takeProfit: tp,
    openTime: open,
    closeTime: close,
    profit: 10,
    commission: 0,
    swap: 0,
    fee: 0,
    netProfit: 10,
    closeReason: reason,
    createdAt: close,
    accountId: 'a1',
  );
}

TradeLevelAnalysis analyse(Trade trade, List<AnalysisCandle> candles) =>
    analyseTradeLevels(
      type: trade.type,
      openTime: trade.openTime,
      closeTime: trade.closeTime,
      stoploss: trade.stoploss,
      takeProfit: trade.takeProfit,
      candles: candles,
    );

void main() {
  final base = DateTime.utc(2026, 1, 1, 12);

  group('timeframe windows', () {
    test('all requested intervals resolve to real context windows', () {
      expect(TradeChartWindow.intervals, [
        '1m', '5m', '15m', '30m', '1h', '4h', '1d',
      ]);
      for (final interval in TradeChartWindow.intervals) {
        expect(TradeChartWindow.isSupported(interval), isTrue, reason: interval);
        final config = TradeChartWindow.config(interval);
        expect(config.startFor(base).isBefore(base), isTrue);
        expect(
          config.endFor(base.add(const Duration(minutes: 5))).isAfter(base),
          isTrue,
        );
      }
      expect(TradeChartWindow.isSupported('2h'), isFalse);
      expect(
        TradeChartWindow.config('1m').beforeEntry,
        const Duration(hours: 2),
      );
      expect(
        TradeChartWindow.config('1d').afterExit,
        const Duration(days: 10),
      );
    });

    test('fallback intervals depend on trade age and duration', () {
      final recent = TradeChartWindow.fallbacks(
        tradeDuration: const Duration(minutes: 5),
        age: const Duration(hours: 2),
      );
      final old = TradeChartWindow.fallbacks(
        tradeDuration: const Duration(minutes: 5),
        age: const Duration(days: 200),
      );
      expect(recent.first, '1m');
      expect(old, ['1h']);
    });
  });

  group('hit detection', () {
    final candles = <AnalysisCandle>[
      const AnalysisCandle(time: 1000, high: 2005, low: 1995),
      const AnalysisCandle(time: 1060, high: 2025, low: 1998),
      const AnalysisCandle(time: 1120, high: 2030, low: 2000),
    ];
    final open = DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true);
    final close = DateTime.fromMillisecondsSinceEpoch(1120 * 1000, isUtc: true);

    test('buy TP uses high and SL uses low', () {
      final buy = _trade(
        type: TradeType.buy,
        open: open,
        close: close,
        sl: 1997,
        tp: 2020,
      );
      final result = analyse(buy, candles);
      expect(result.firstTpTime, 1060);
      expect(result.firstSlTime, 1000);
      expect(result.bothTouchedInSameCandle, isFalse);
    });

    test('sell TP uses low and SL uses high', () {
      final sell = _trade(
        type: TradeType.sell,
        open: open,
        close: close,
        sl: 2020,
        tp: 1998,
      );
      final result = analyse(sell, candles);
      expect(result.firstTpTime, 1000);
      expect(result.firstSlTime, 1060);
    });

    test('one candle touching both levels is ambiguous', () {
      final buy = _trade(
        type: TradeType.buy,
        open: open,
        close: close,
        sl: 1996,
        tp: 2004,
      );
      final result = analyse(buy, candles);
      expect(result.firstTpTime, 1000);
      expect(result.firstSlTime, 1000);
      expect(result.bothTouchedInSameCandle, isTrue);
      expect(result.orderKnown, isFalse);
    });

    test('a later same-candle double touch is still ambiguous', () {
      final laterCandles = <AnalysisCandle>[
        const AnalysisCandle(time: 1000, high: 2010, low: 1999),
        const AnalysisCandle(time: 1060, high: 2025, low: 1990),
      ];
      final buy = _trade(
        type: TradeType.buy,
        open: open,
        close: close,
        sl: 1995,
        tp: 2020,
      );
      final result = analyse(buy, laterCandles);
      expect(result.firstTpTime, 1060);
      expect(result.firstSlTime, 1060);
      expect(result.bothTouchedInSameCandle, isTrue);
    });

    test('trades without SL or TP never report touches', () {
      final buy = _trade(type: TradeType.buy, open: open, close: close);
      final result = analyse(buy, candles);
      expect(result.tpTouched, isFalse);
      expect(result.slTouched, isFalse);
    });

    test('candles after the actual exit are ignored', () {
      final earlyClose = DateTime.fromMillisecondsSinceEpoch(
        1000 * 1000,
        isUtc: true,
      );
      final buy = _trade(
        type: TradeType.buy,
        open: open,
        close: earlyClose,
        tp: 2020,
      );
      final result = analyse(buy, candles);
      expect(result.firstTpTime, isNull);
    });

    test('entry outside the series is flagged instead of guessed', () {
      final lateOpen = DateTime.fromMillisecondsSinceEpoch(
        9000 * 1000,
        isUtc: true,
      );
      final buy = _trade(
        type: TradeType.buy,
        open: lateOpen,
        close: lateOpen.add(const Duration(minutes: 5)),
      );
      final result = analyse(buy, candles);
      expect(result.entryOutsideSeries, isTrue);
      expect(result.exitOutsideSeries, isTrue);
    });

    test('empty series reports missing data', () {
      final result = analyse(
        _trade(type: TradeType.buy, open: open, close: close),
        const [],
      );
      expect(result.entryOutsideSeries, isTrue);
      expect(result.tpTouched, isFalse);
    });
  });

  test('broker close reason stays distinct from level touches', () {
    expect(describeCloseReason(CloseReason.takeProfit), 'Broker closed at TP');
    expect(describeCloseReason(CloseReason.stopLoss), 'Broker closed at SL');
    expect(describeCloseReason(CloseReason.stopOut), 'Stop out');
    expect(describeCloseReason(CloseReason.manual), 'Manual exit');
    expect(describeCloseReason(CloseReason.unknown), 'Unknown outcome');
  });

  test('chart bridge messages decode nested payloads', () {
    final envelope = decodeChartMessage(
      '{"type":"crosshairMoved","payload":{"time":123,"volume":null}}',
    );
    final payload = decodeChartMessage(envelope['payload']);
    expect(envelope['type'], 'crosshairMoved');
    expect(payload['time'], 123);
    expect(payload['volume'], isNull);
    expect(decodeChartMessage('not json'), isEmpty);
  });

  group('timeframe selection and payload integrity', () {
    test('explicit timeframe is used by inline and full-screen charts', () {
      expect(TradeChartWindow.effective('15m', '1h'), '15m');
      expect(TradeChartWindow.effective(null, '4h'), '4h');
    });

    test('unsupported timeframe fails clearly before any network request', () async {
      final trade = _trade(
        type: TradeType.buy,
        open: base,
        close: base.add(const Duration(minutes: 5)),
      );
      await expectLater(
        const Mt5CandleService().loadForTrade(trade, interval: '2h'),
        throwsA(
          isA<Mt5CandleException>()
              .having((error) => error.code, 'code', 'unsupported_timeframe')
              .having(
                (error) => error.message,
                'message',
                contains('Unsupported timeframe'),
              ),
        ),
      );
    });

    test('imported trade prices and close reason stay authoritative', () {
      final trade = _trade(
        type: TradeType.sell,
        open: base,
        close: base.add(const Duration(minutes: 5)),
        sl: 2005,
        tp: 1980,
        reason: CloseReason.manual,
      );
      final json = trade.toJson();
      expect(json['openPrice'], 2000.0);
      expect(json['closePrice'], 2010.0);
      expect(json['stoploss'], 2005.0);
      expect(json['takeProfit'], 1980.0);
      expect(json['closeReason'], 'manual');
    });

    test('volume is omitted from the chart when the provider omits it', () {
      const withoutVolume = MarketCandle(
        time: 1000,
        open: 1,
        high: 2,
        low: 0.5,
        close: 1.5,
      );
      const withVolume = MarketCandle(
        time: 1000,
        open: 1,
        high: 2,
        low: 0.5,
        close: 1.5,
        volume: 42,
      );
      expect(withoutVolume.toChartJson().containsKey('volume'), isFalse);
      expect(withVolume.toChartJson()['volume'], 42.0);
    });
  });

  group('exact chart markers', () {
    final entry = DateTime.utc(2026, 1, 1, 10, 35, 24, 500);
    final exit = DateTime.utc(2026, 1, 1, 10, 48, 12, 250);
    final entryBar = DateTime.utc(2026, 1, 1, 10, 35, 24);

    int seconds(DateTime value) => value.millisecondsSinceEpoch ~/ 1000;

    List<TradeChartMarker> markersFor(
      Trade trade, {
      List<AnalysisCandle> candles = const [],
    }) =>
        TradeChartMarkers.build(
          trade: trade,
          analysis: analyse(trade, candles),
        );

    TradeChartMarker only(List<TradeChartMarker> markers, String kind) =>
        markers.singleWhere((marker) => marker.kind == kind);

    test('BUY entry uses the exact execution time and price', () {
      final marker = only(
        markersFor(
          _trade(type: TradeType.buy, open: entry, close: exit),
        ),
        'entry',
      );
      expect(marker.timeMs, entry.millisecondsSinceEpoch);
      expect(marker.price, 2000.0);
      expect(marker.direction, 'long');
      expect(marker.label, 'BUY');
      expect(marker.color, TradeChartMarkers.entryColor);
    });

    test('SELL entry uses the exact execution time and price', () {
      final marker = only(
        markersFor(
          _trade(type: TradeType.sell, open: entry, close: exit),
        ),
        'entry',
      );
      expect(marker.timeMs, entry.millisecondsSinceEpoch);
      expect(marker.price, 2000.0);
      expect(marker.direction, 'short');
      expect(marker.label, 'SELL');
    });

    test('TP exit marker is green and labelled TP', () {
      final marker = only(
        markersFor(
          _trade(
            type: TradeType.buy,
            open: entry,
            close: exit,
            reason: CloseReason.takeProfit,
          ),
        ),
        'exit',
      );
      expect(marker.timeMs, exit.millisecondsSinceEpoch);
      expect(marker.price, 2010.0);
      expect(marker.label, 'TP');
      expect(marker.color, TradeChartMarkers.tpColor);
    });

    test('SL exit marker is red and labelled SL', () {
      final marker = only(
        markersFor(
          _trade(
            type: TradeType.buy,
            open: entry,
            close: exit,
            reason: CloseReason.stopLoss,
          ),
        ),
        'exit',
      );
      expect(marker.label, 'SL');
      expect(marker.color, TradeChartMarkers.slColor);
      expect(marker.timeMs, exit.millisecondsSinceEpoch);
    });

    test('manual exit stays manual even when a level was touched', () {
      final trade = _trade(
        type: TradeType.buy,
        open: entry,
        close: exit,
        sl: 1990,
        tp: 2020,
        reason: CloseReason.manual,
      );
      final markers = markersFor(trade, candles: [
        AnalysisCandle(time: seconds(entryBar), high: 2025, low: 1995),
      ]);
      final exitMarker = only(markers, 'exit');
      expect(exitMarker.label, 'MANUAL EXIT');
      expect(exitMarker.color, TradeChartMarkers.manualColor);
      expect(exitMarker.price, trade.closePrice);
      // A touch is evidence, not a broker fill: both may legitimately show.
      expect(markers.any((marker) => marker.kind == 'tpTouch'), isTrue);
      expect(TradeChartMarkers.exitLabel(CloseReason.manual), 'MANUAL EXIT');
    });

    test('unknown exit reason is never guessed', () {
      final marker = only(
        markersFor(
          _trade(type: TradeType.buy, open: entry, close: exit),
        ),
        'exit',
      );
      expect(marker.label, 'EXIT');
      expect(marker.color, TradeChartMarkers.neutralColor);
    });

    test('sub-candle execution times and prices are never snapped to OHLC', () {
      final json = markersFor(
        _trade(type: TradeType.buy, open: entry, close: exit),
      ).map((marker) => marker.toJson()).toList();
      final entryJson = json.singleWhere((item) => item['kind'] == 'entry');
      expect(entryJson['time'], entry.millisecondsSinceEpoch);
      expect(entryJson['price'], 2000.0);
      for (final key in ['open', 'high', 'low', 'close', 'anchors', 'type']) {
        expect(entryJson.containsKey(key), isFalse, reason: key);
      }
      expect(entryJson['meta']['traderLogAutomatic'], isTrue);
      expect(json.every((item) => item['confidence'] == 1), isTrue);
    });

    test('markers use absolute coordinates, independent of zoom or scroll', () {
      final json = markersFor(
        _trade(type: TradeType.sell, open: entry, close: exit),
      ).map((marker) => marker.toJson()).toList();
      expect(json.every((item) => item['time'] is int), isTrue);
      expect(json.every((item) => item['price'] is num), isTrue);
      expect(
        json.every((item) => !item.containsKey('x') &&
            !item.containsKey('y') &&
            !item.containsKey('index')),
        isTrue,
      );
    });

    test('touch markers sit at the level price on the first touching candle', () {
      final trade = _trade(
        type: TradeType.buy,
        open: entry,
        close: exit,
        sl: 1997,
        tp: 2005,
      );
      final firstTouch = seconds(entryBar).withSecondsAdded(60);
      final secondTouch = seconds(entryBar).withSecondsAdded(120);
      final markers = markersFor(trade, candles: [
        AnalysisCandle(time: seconds(entryBar), high: 2000, low: 1999),
        AnalysisCandle(time: firstTouch, high: 2010, low: 1999),
        AnalysisCandle(time: secondTouch, high: 2010, low: 1996),
      ]);
      final tp = only(markers, 'tpTouch');
      final sl = only(markers, 'slTouch');
      expect(tp.timeMs, firstTouch * 1000);
      expect(tp.price, 2005.0);
      expect(tp.direction, 'neutral');
      expect(tp.label, 'TP TOUCHED');
      expect(tp.color, TradeChartMarkers.tpColor);
      expect(sl.timeMs, secondTouch * 1000);
      expect(sl.price, 1997.0);
      expect(sl.label, 'SL TOUCHED');
    });

    test('touch detection includes the bar containing a sub-candle entry', () {
      final trade = _trade(
        type: TradeType.buy,
        open: entry,
        close: exit,
        tp: 2005,
      );
      final barStart = seconds(DateTime.utc(2026, 1, 1, 10, 35));
      final result = analyse(trade, [
        AnalysisCandle(time: barStart, high: 2010, low: 1999),
      ]);
      expect(result.firstTpTime, barStart);
      expect(only(markersFor(trade, candles: [
        AnalysisCandle(time: barStart, high: 2010, low: 1999),
      ]), 'tpTouch').timeMs, barStart * 1000);
    });

    test('same-candle ambiguity is reported without assuming an order', () {
      final trade = _trade(
        type: TradeType.buy,
        open: entry,
        close: exit,
        sl: 1997,
        tp: 2004,
      );
      final both = seconds(entryBar).withSecondsAdded(60);
      final markers = markersFor(trade, candles: [
        AnalysisCandle(time: both, high: 2005, low: 1996),
      ]);
      expect(only(markers, 'tpTouch').timeMs, both * 1000);
      expect(only(markers, 'slTouch').timeMs, both * 1000);
      expect(analyse(trade, [
        AnalysisCandle(time: both, high: 2005, low: 1996),
      ]).bothTouchedInSameCandle, isTrue);
      expect(
        TradeChartMarkers.ambiguityMessage,
        'SL and TP touched in the same candle — exact order unknown.',
      );
    });

    test('manual exit stops touch scanning at the real exit time', () {
      final earlyExit = DateTime.utc(2026, 1, 1, 10, 36);
      final trade = _trade(
        type: TradeType.buy,
        open: entry,
        close: earlyExit,
        tp: 2005,
        reason: CloseReason.manual,
      );
      final markers = markersFor(trade, candles: [
        AnalysisCandle(
          time: seconds(earlyExit).withSecondsAdded(120),
          high: 2010,
          low: 1999,
        ),
      ]);
      expect(markers.any((marker) => marker.kind == 'tpTouch'), isFalse);
      expect(only(markers, 'exit').label, 'MANUAL EXIT');
    });

    test('timeframe reload keeps execution markers and recalculates touches', () {
      final trade = _trade(
        type: TradeType.buy,
        open: entry,
        close: exit,
        tp: 2005,
      );
      final oneMinuteTouch = seconds(entryBar).withSecondsAdded(60);
      final oneMinute = markersFor(trade, candles: [
        AnalysisCandle(time: seconds(entryBar), high: 2000, low: 1999),
        AnalysisCandle(time: oneMinuteTouch, high: 2010, low: 1999),
      ]);
      final fiveMinute = markersFor(trade, candles: [
        AnalysisCandle(time: seconds(entryBar), high: 2010, low: 1999),
      ]);
      expect(only(oneMinute, 'entry').toJson(), only(fiveMinute, 'entry').toJson());
      expect(only(oneMinute, 'exit').toJson(), only(fiveMinute, 'exit').toJson());
      expect(only(oneMinute, 'tpTouch').timeMs, oneMinuteTouch * 1000);
      expect(only(fiveMinute, 'tpTouch').timeMs, seconds(entryBar) * 1000);
      expect(only(oneMinute, 'tpTouch').price, only(fiveMinute, 'tpTouch').price);
    });

    test('inline and full-screen charts receive the same marker payload', () {
      final trade = _trade(
        type: TradeType.sell,
        open: entry,
        close: exit,
        reason: CloseReason.manual,
      );
      final inline = markersFor(trade).map((m) => m.toJson()).toList();
      final fullscreen = markersFor(trade).map((m) => m.toJson()).toList();
      expect(fullscreen, inline);
      expect(TradeChartWindow.effective('15m', '1h'), '15m');
    });
  });
}

extension on int {
  int withSecondsAdded(int seconds) => this + seconds;
}
