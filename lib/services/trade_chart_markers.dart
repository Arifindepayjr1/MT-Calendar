import 'package:trader_log/model/trade.model.dart';

import 'trade_level_analysis.dart';

/// A compact chart marker built from an imported trade event.
///
/// [timeMs] and [price] are absolute chart coordinates. They are never candle
/// OHLC values: the marker stays at the execution time/price through zoom,
/// scroll, reload and timeframe changes.
class TradeChartMarker {
  final String id;
  final String kind;
  final int timeMs;
  final double price;
  final String direction;
  final String color;
  final String label;

  const TradeChartMarker({
    required this.id,
    required this.kind,
    required this.timeMs,
    required this.price,
    required this.direction,
    required this.color,
    required this.label,
  });

  /// Shape expected by TradeCanvas `chart.setSignalMarkers()`.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind,
        'time': timeMs,
        'price': price,
        'direction': direction,
        'confidence': 1,
        'source': 'TraderLog $kind',
        'label': label,
        'color': color,
        'meta': <String, dynamic>{
          'traderLogAutomatic': true,
          'kind': kind,
        },
      };
}

/// Pure builder for the automatic trade markers. No Flutter or chart imports.
class TradeChartMarkers {
  const TradeChartMarkers._();

  static const entryColor = '#FFFFFF';
  static const tpColor = '#2ED47A';
  static const slColor = '#FF4D4D';
  static const manualColor = '#F3B65B';
  static const neutralColor = '#B9C3BC';

  /// Exact wording used when OHLC cannot order two same-candle touches.
  static const ambiguityMessage =
      'SL and TP touched in the same candle — exact order unknown.';

  /// Only the imported entry and exit events. No inferred level touches,
  /// zones or analysis state — used by the plain MT5 session chart.
  static List<TradeChartMarker> entryExit(Trade trade) {
    final prefix = 'traderlog:auto:${trade.id}';
    final buy = trade.type == TradeType.buy;
    return <TradeChartMarker>[
      TradeChartMarker(
        id: '$prefix:entry',
        kind: 'entry',
        timeMs: trade.openTime.toUtc().millisecondsSinceEpoch,
        price: trade.openPrice,
        direction: buy ? 'long' : 'short',
        color: entryColor,
        label: buy ? 'BUY' : 'SELL',
      ),
      TradeChartMarker(
        id: '$prefix:exit',
        kind: 'exit',
        timeMs: trade.closeTime.toUtc().millisecondsSinceEpoch,
        price: trade.closePrice,
        direction: buy ? 'short' : 'long',
        color: exitColor(trade.closeReason),
        label: exitLabel(trade.closeReason),
      ),
    ];
  }

  static List<TradeChartMarker> build({
    required Trade trade,
    required TradeLevelAnalysis analysis,
  }) {
    final prefix = 'traderlog:auto:${trade.id}';
    final buy = trade.type == TradeType.buy;
    final markers = <TradeChartMarker>[
      TradeChartMarker(
        id: '$prefix:entry',
        kind: 'entry',
        // Millisecond precision is preserved: 10:35:24 stays 10:35:24 even
        // when the containing candle starts at 10:35:00.
        timeMs: trade.openTime.toUtc().millisecondsSinceEpoch,
        price: trade.openPrice,
        direction: buy ? 'long' : 'short',
        color: entryColor,
        label: buy ? 'BUY' : 'SELL',
      ),
      TradeChartMarker(
        id: '$prefix:exit',
        kind: 'exit',
        timeMs: trade.closeTime.toUtc().millisecondsSinceEpoch,
        price: trade.closePrice,
        direction: buy ? 'short' : 'long',
        color: exitColor(trade.closeReason),
        label: exitLabel(trade.closeReason),
      ),
    ];

    // Touch evidence is bounded by analyseTradeLevels() to the window from
    // entry through the actual exit, so a manual close stops the scan there.
    final tpTime = analysis.firstTpTime;
    if (tpTime != null && trade.takeProfit != null) {
      markers.add(TradeChartMarker(
        id: '$prefix:tp-touch',
        kind: 'tpTouch',
        timeMs: tpTime * 1000,
        price: trade.takeProfit ?? 0,
        direction: 'neutral',
        color: tpColor,
        label: 'TP TOUCHED',
      ));
    }
    final slTime = analysis.firstSlTime;
    if (slTime != null && trade.stoploss != null) {
      markers.add(TradeChartMarker(
        id: '$prefix:sl-touch',
        kind: 'slTouch',
        timeMs: slTime * 1000,
        price: trade.stoploss ?? 0,
        direction: 'neutral',
        color: slColor,
        label: 'SL TOUCHED',
      ));
    }
    return markers;
  }

  /// The broker's close reason, never inferred from a level touch.
  static String exitLabel(CloseReason reason) => switch (reason) {
        CloseReason.takeProfit => 'TP',
        CloseReason.stopLoss => 'SL',
        CloseReason.stopOut => 'STOP OUT',
        CloseReason.manual => 'MANUAL EXIT',
        CloseReason.other || CloseReason.unknown => 'EXIT',
      };

  static String exitColor(CloseReason reason) => switch (reason) {
        CloseReason.takeProfit => tpColor,
        CloseReason.stopLoss || CloseReason.stopOut => slColor,
        CloseReason.manual => manualColor,
        CloseReason.other || CloseReason.unknown => neutralColor,
      };
}
