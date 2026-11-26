/// Pure timeframe/window helpers used by the candle service and tests.
///
/// These values are starting defaults, not limits. The chart can zoom out over
/// every bar that was actually loaded.
class TradeChartWindow {
  const TradeChartWindow._();

  static const intervals = ['1m', '5m', '15m', '30m', '1h', '4h', '1d'];

  /// Context kept around a trade for each real OHLC interval.
  static const context = <String, TradeChartWindowConfig>{
    '1m': TradeChartWindowConfig(Duration(hours: 2), Duration(hours: 1)),
    '5m': TradeChartWindowConfig(Duration(hours: 6), Duration(hours: 2)),
    '15m': TradeChartWindowConfig(Duration(hours: 24), Duration(hours: 4)),
    '30m': TradeChartWindowConfig(Duration(days: 2), Duration(hours: 8)),
    '1h': TradeChartWindowConfig(Duration(days: 3), Duration(days: 1)),
    '4h': TradeChartWindowConfig(Duration(days: 14), Duration(days: 3)),
    '1d': TradeChartWindowConfig(Duration(days: 60), Duration(days: 10)),
  };

  static bool isSupported(String interval) => context.containsKey(interval);

  /// One source of truth for the interval shown by inline and full-screen
  /// charts. An explicit user selection always wins over the auto-detected one.
  static String effective(String? selected, String seriesInterval) =>
      selected ?? seriesInterval;

  static TradeChartWindowConfig config(String interval) =>
      context[interval] ?? context['1h']!;

  /// Intervals to try when no explicit timeframe was requested.
  /// Short recent trades get fine-grained data; old/long trades use hourly bars
  /// so a single bounded MT5 session request is sufficient.
  static List<String> fallbacks({
    required Duration tradeDuration,
    required Duration age,
  }) {
    if (tradeDuration < const Duration(minutes: 30)) {
      if (age <= const Duration(days: 7)) return ['1m', '5m', '15m', '30m', '1h'];
      if (age <= const Duration(days: 60)) return ['5m', '15m', '30m', '1h'];
      return ['1h'];
    }
    if (tradeDuration < const Duration(hours: 6)) {
      return age <= const Duration(days: 60)
          ? ['5m', '15m', '30m', '1h']
          : ['1h'];
    }
    return ['1h', '4h'];
  }

  static bool isRecent(DateTime openTime, {Duration maxAge = const Duration(days: 7)}) =>
      DateTime.now().toUtc().difference(openTime.toUtc()) <= maxAge;
}

class TradeChartWindowConfig {
  final Duration beforeEntry;
  final Duration afterExit;

  const TradeChartWindowConfig(this.beforeEntry, this.afterExit);

  DateTime startFor(DateTime openTime) =>
      openTime.toUtc().subtract(beforeEntry);

  DateTime endFor(DateTime closeTime) => closeTime.toUtc().add(afterExit);
}
