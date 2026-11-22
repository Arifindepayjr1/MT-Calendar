import 'package:trader_log/model/trade.model.dart';

/// A single inspected candle, in seconds (the same unit Yahoo returns).
class AnalysisCandle {
  final int time;
  final double high;
  final double low;

  const AnalysisCandle({
    required this.time,
    required this.high,
    required this.low,
  });
}

/// OHLC-resolution evidence about where a trade's levels were touched.
///
/// A wick touching a level is not proof that the broker closed the trade
/// there; the broker's own [closeReason] is reported separately.
class TradeLevelAnalysis {
  final int? firstTpTime;
  final int? firstSlTime;
  final bool bothTouchedInSameCandle;
  final bool entryOutsideSeries;
  final bool exitOutsideSeries;

  const TradeLevelAnalysis({
    this.firstTpTime,
    this.firstSlTime,
    this.bothTouchedInSameCandle = false,
    this.entryOutsideSeries = false,
    this.exitOutsideSeries = false,
  });

  bool get tpTouched => firstTpTime != null;
  bool get slTouched => firstSlTime != null;

  /// No claim about order is made when one candle touched both levels.
  bool get orderKnown => !bothTouchedInSameCandle;
}

/// Pure, unit-testable analysis. No Flutter and no chart dependencies.
TradeLevelAnalysis analyseTradeLevels({
  required TradeType type,
  required DateTime openTime,
  required DateTime closeTime,
  required double? stoploss,
  required double? takeProfit,
  required List<AnalysisCandle> candles,
}) {
  if (candles.isEmpty) {
    return const TradeLevelAnalysis(
      entryOutsideSeries: true,
      exitOutsideSeries: true,
    );
  }

  final entry = openTime.toUtc().millisecondsSinceEpoch ~/ 1000;
  final exit = closeTime.toUtc().millisecondsSinceEpoch ~/ 1000;
  final first = candles.first.time;
  final last = candles.last.time;
  final entryOutsideSeries = entry < first || entry > last;
  final exitOutsideSeries = exit < first || exit > last;

  final buy = type == TradeType.buy;
  int? tpTime;
  int? slTime;
  var ambiguous = false;

  // The trade may have no overlapping evidence at all, for example when it is
  // older than Yahoo's retention for the selected interval.
  // A single candle has no measurable step, so treat it as potentially
  // containing the trade instead of assuming the trade is outside the series.
  final step = candles.length > 1 ? last - candles[candles.length - 2].time : 0;
  if (exit < first || (entry > last && step > 0 && entry - last > step)) {
    return TradeLevelAnalysis(
      entryOutsideSeries: entryOutsideSeries,
      exitOutsideSeries: exitOutsideSeries,
    );
  }

  // Candle times are bar starts. An execution at 10:35:24 belongs to the bar
  // labelled 10:35:00, so begin with the bar containing the entry rather than
  // skipping every bar whose label precedes the exact execution timestamp.
  var start = 0;
  for (var i = 0; i < candles.length; i++) {
    if (candles[i].time > entry) break;
    start = i;
  }

  for (var i = start; i < candles.length; i++) {
    final candle = candles[i];
    // Respect the actual exit timestamp: bars starting after it are not part
    // of the trade and must not be reported as TP/SL touches.
    if (candle.time > exit) break;

    final tp = takeProfit;
    final sl = stoploss;
    final tpTouched = tp != null && (buy ? candle.high >= tp : candle.low <= tp);
    final slTouched = sl != null && (buy ? candle.low <= sl : candle.high >= sl);

    if (tpTouched && slTouched) {
      // OHLC alone cannot order two touches inside the same candle, even when
      // one of the levels was already touched in an earlier candle.
      ambiguous = true;
      tpTime ??= candle.time;
      slTime ??= candle.time;
      break;
    }
    if (tpTouched && tpTime == null) tpTime = candle.time;
    if (slTouched && slTime == null) slTime = candle.time;
    if (tpTime != null && slTime != null) break;
  }

  return TradeLevelAnalysis(
    firstTpTime: tpTime,
    firstSlTime: slTime,
    bothTouchedInSameCandle: ambiguous,
    entryOutsideSeries: entryOutsideSeries,
    exitOutsideSeries: exitOutsideSeries,
  );
}

/// Human-readable broker close description, kept separate from touched levels.
String describeCloseReason(CloseReason reason) {
  switch (reason) {
    case CloseReason.takeProfit:
      return 'Broker closed at TP';
    case CloseReason.stopLoss:
      return 'Broker closed at SL';
    case CloseReason.manual:
      return 'Manual exit';
    case CloseReason.stopOut:
      return 'Stop out';
    case CloseReason.other:
    case CloseReason.unknown:
      return 'Unknown outcome';
  }
}
