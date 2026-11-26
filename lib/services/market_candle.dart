// Provider-neutral candle models used by the trade-history chart.
//
// In this app the only producer is the MT5 broker bridge. These types carry no
// provider-specific requests: they are just the OHLC payload and the metadata
// the chart needs to label its real data source.

class MarketCandle {
  final int time;
  final double open, high, low, close;

  /// Null when the broker did not supply real volume. Never defaulted to zero,
  /// because a fabricated 0 would be displayed as real volume.
  final double? volume;

  /// MT5 fields reported by the broker for this bar.
  final int? tickVolume;
  final double? spread;
  final double? realVolume;

  const MarketCandle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
    this.tickVolume,
    this.spread,
    this.realVolume,
  });

  Map<String, Object> toChartJson() => {
        'time': time,
        'open': open,
        'high': high,
        'low': low,
        'close': close,
        'volume': ?volume,
        'tickVolume': ?tickVolume,
        'spread': ?spread,
        'realVolume': ?realVolume,
      };
}

/// A full broker session returned by `/api/mt5/candles`.
///
/// [ticker] is the exact broker symbol from the imported trade. [broker] is the
/// connected broker's company name, echoed by the backend from MT5; the chart's
/// data-source badge is only rendered when it is present and [source] is `mt5`.
class MarketCandleSeries {
  final String symbol, ticker, interval, sourceNote;
  final List<MarketCandle> candles;

  final String source;
  final DateTime? sessionStart;
  final DateTime? sessionEnd;
  final String? sessionReason;
  final String? broker;
  final String? date;

  const MarketCandleSeries({
    required this.symbol,
    required this.ticker,
    required this.interval,
    required this.sourceNote,
    required this.candles,
    this.source = 'mt5',
    this.sessionStart,
    this.sessionEnd,
    this.sessionReason,
    this.broker,
    this.date,
  });

  bool get isMt5 => source == 'mt5';

  MarketCandleSeries copyWith({
    String? symbol,
    String? ticker,
    String? interval,
    String? sourceNote,
    List<MarketCandle>? candles,
    String? source,
    DateTime? sessionStart,
    DateTime? sessionEnd,
    String? sessionReason,
    String? broker,
    String? date,
  }) =>
      MarketCandleSeries(
        symbol: symbol ?? this.symbol,
        ticker: ticker ?? this.ticker,
        interval: interval ?? this.interval,
        sourceNote: sourceNote ?? this.sourceNote,
        candles: candles ?? this.candles,
        source: source ?? this.source,
        sessionStart: sessionStart ?? this.sessionStart,
        sessionEnd: sessionEnd ?? this.sessionEnd,
        sessionReason: sessionReason ?? this.sessionReason,
        broker: broker ?? this.broker,
        date: date ?? this.date,
      );
}

class CandleDataException implements Exception {
  final String message;
  const CandleDataException(this.message);
  @override
  String toString() => message;
}
