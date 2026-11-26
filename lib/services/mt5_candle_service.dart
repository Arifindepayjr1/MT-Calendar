import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:trader_log/model/trade.model.dart';

import 'market_candle.dart';
import 'trade_chart_window.dart';

/// A broker/MT5-specific failure. The chart surfaces this directly: there is no
/// alternative provider to substitute when MT5 is unavailable.
class Mt5CandleException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;

  const Mt5CandleException(
    this.message, {
    this.code,
    this.statusCode,
  });

  @override
  String toString() => message;
}

/// Client for the NestJS-owned `/api/mt5/*` routes.
///
/// The broker symbol from the imported trade is sent verbatim: no ticker
/// rewriting, proxy symbol or futures substitution happens here. A full broker
/// session is returned by the worker; this client does not trim it to the
/// trade's duration.
class Mt5CandleService {
  static const timeframeByInterval = <String, String>{
    '1m': 'M1',
    '5m': 'M5',
    '15m': 'M15',
    '30m': 'M30',
    '1h': 'H1',
    '4h': 'H4',
    '1d': 'D1',
  };

  final http.Client? client;
  final String? baseUrl;

  const Mt5CandleService({this.client, this.baseUrl});

  /// Default resolution used when the chart is set to Auto.
  static String autoInterval(Trade trade) => TradeChartWindow.fallbacks(
        tradeDuration: trade.closeTime.difference(trade.openTime),
        age: DateTime.now().toUtc().difference(trade.openTime.toUtc()),
      ).first;

  static String timeframeFor(String interval) =>
      timeframeByInterval[interval] ?? 'M15';

  /// Loads every real broker bar in the session overlapping [date].
  ///
  /// [date] defaults to the trade's UTC execution date. Passing another date
  /// is supported for reviewing adjacent sessions from the chart controls.
  Future<MarketCandleSeries> loadForTrade(
    Trade trade, {
    String? interval,
    DateTime? date,
  }) async {
    final resolvedInterval = interval ?? autoInterval(trade);
    if (!TradeChartWindow.isSupported(resolvedInterval)) {
      throw Mt5CandleException(
        'Unsupported timeframe "$resolvedInterval". Choose 1m, 5m, 15m, 30m, 1H, 4H or 1D.',
        code: 'unsupported_timeframe',
      );
    }
    final symbol = trade.symbol.trim();
    if (symbol.isEmpty) {
      throw const Mt5CandleException(
        'This trade has no broker symbol, so MT5 history cannot be requested.',
        code: 'missing_symbol',
      );
    }
    final sessionDate = formatDate(date ?? trade.openTime);
    final payload = await _getJson('candles', <String, String>{
      'symbol': symbol,
      'date': sessionDate,
      'timeframe': timeframeFor(resolvedInterval),
    });
    if (payload['source'] != 'mt5') {
      throw const Mt5CandleException(
        'The history endpoint did not return MT5 data.',
        code: 'unexpected_source',
      );
    }
    final candles = _candlesFrom(payload['candles']);
    return MarketCandleSeries(
      symbol: symbol,
      ticker: symbol,
      interval: resolvedInterval,
      sourceNote: _sourceNote(payload['reason'], candles.length),
      candles: candles,
      source: 'mt5',
      sessionStart: parseUtc(payload['sessionStart']),
      sessionEnd: parseUtc(payload['sessionEnd']),
      sessionReason: payload['reason'] is String ? payload['reason'] as String : null,
      broker: payload['broker'] is String && (payload['broker'] as String).isNotEmpty
          ? payload['broker'] as String
          : null,
      date: sessionDate,
    );
  }

  /// Latest real candle from the same broker symbol, for the chart's
  /// "latest candle" control. This never mutates historical review data.
  Future<MarketCandle> latest({
    required String symbol,
    String interval = '15m',
  }) async {
    final brokerSymbol = symbol.trim();
    if (brokerSymbol.isEmpty) {
      throw const Mt5CandleException(
        'This trade has no broker symbol.',
        code: 'missing_symbol',
      );
    }
    if (!TradeChartWindow.isSupported(interval)) {
      throw Mt5CandleException('Unsupported timeframe "$interval".');
    }
    final payload = await _getJson('latest', <String, String>{
      'symbol': brokerSymbol,
      'timeframe': timeframeFor(interval),
      'count': '1',
    });
    if (payload['source'] != 'mt5') {
      throw const Mt5CandleException(
        'The latest-candle endpoint did not return MT5 data.',
        code: 'unexpected_source',
      );
    }
    final candles = _candlesFrom(payload['candles']);
    if (candles.isEmpty) {
      throw const Mt5CandleException('No latest MT5 candle is available.');
    }
    return candles.last;
  }

  static String formatDate(DateTime value) {
    final utc = value.toUtc();
    return '${utc.year.toString().padLeft(4, '0')}-'
        '${utc.month.toString().padLeft(2, '0')}-'
        '${utc.day.toString().padLeft(2, '0')}';
  }

  static DateTime? parseUtc(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  static String _sourceNote(Object? reason, int count) {
    final detail = reason is String && reason.isNotEmpty ? ' · $reason' : '';
    return 'MT5 broker session · UTC · $count real bars$detail';
  }

  List<MarketCandle> _candlesFrom(Object? raw) {
    if (raw is! List) return const <MarketCandle>[];
    final result = <MarketCandle>[];
    final seen = <int>{};
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;
      final timestamp = item['timestamp'];
      final open = item['open'];
      final high = item['high'];
      final low = item['low'];
      final close = item['close'];
      if (timestamp is! num || open is! num || high is! num || low is! num || close is! num) {
        continue;
      }
      final time = timestamp.toInt();
      if (!seen.add(time)) continue;
      final rawRealVolume = item['realVolume'];
      final realVolume = rawRealVolume is num ? rawRealVolume.toDouble() : null;
      final rawTickVolume = item['tickVolume'];
      final spread = item['spread'];
      result.add(
        MarketCandle(
          time: time,
          open: open.toDouble(),
          high: high.toDouble(),
          low: low.toDouble(),
          close: close.toDouble(),
          // Only expose real volume if the broker actually supplied it; tick
          // volume is carried separately and shown in the chart tooltip.
          volume: realVolume != null && realVolume > 0 ? realVolume : null,
          tickVolume: rawTickVolume is num ? rawTickVolume.toInt() : null,
          spread: spread is num ? spread.toDouble() : null,
          realVolume: realVolume,
        ),
      );
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  List<Uri> _candidates(String path) {
    final suffix = 'api/mt5/$path';
    if (baseUrl != null) {
      final root = baseUrl!.replaceAll(RegExp(r'/+$'), '');
      return [Uri.parse('$root/$suffix')];
    }
    return [
      if (kIsWeb) Uri.base.resolve('/$suffix'),
      Uri.parse('http://127.0.0.1:3000/$suffix'),
    ];
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query,
  ) async {
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    Object? lastError;
    try {
      final candidates = _candidates(path)
          .map((uri) => uri.replace(queryParameters: query))
          .toList(growable: false);
      for (var i = 0; i < candidates.length; i++) {
        final uri = candidates[i];
        try {
          final response = await httpClient
              .get(uri, headers: const {'Accept': 'application/json'})
              .timeout(const Duration(seconds: 15));
          final body = response.body.trimLeft();
          if (!body.startsWith('{')) {
            if (kIsWeb && i == 0) {
              // `flutter run -d chrome` serves index.html for unknown paths.
              continue;
            }
            throw const Mt5CandleException(
              'The MT5 endpoint returned a non-JSON response.',
              code: 'invalid_response',
            );
          }
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) {
            throw const Mt5CandleException(
              'The MT5 endpoint returned an unreadable response.',
              code: 'invalid_response',
            );
          }
          if (response.statusCode < 200 || response.statusCode >= 300) {
            final message = decoded['message'] as String? ??
                decoded['error'] as String? ??
                'MT5 request failed (${response.statusCode}).';
            throw Mt5CandleException(
              message,
              code: decoded['code'] as String?,
              statusCode: response.statusCode,
            );
          }
          return decoded;
        } on Mt5CandleException {
          rethrow;
        } catch (error) {
          lastError = error;
        }
      }
    } finally {
      if (ownsClient) httpClient.close();
    }
    throw Mt5CandleException(
      'MT5 history API is unavailable. Start the backend on port 3000. $lastError',
      code: 'unavailable',
    );
  }
}

/// MT5-only facade kept as the single candle entry point for the chart.
///
/// It deliberately has no fallback provider: an MT5 failure is surfaced to the
/// user as a clear error instead of being replaced with another data source.
class TradeCandleService {
  final http.Client? client;
  final String? baseUrl;

  const TradeCandleService({this.client, this.baseUrl});

  Future<MarketCandleSeries> loadForTrade(
    Trade trade, {
    String? interval,
    DateTime? date,
  }) =>
      Mt5CandleService(client: client, baseUrl: baseUrl).loadForTrade(
        trade,
        interval: interval,
        date: date,
      );

  Future<MarketCandle> latest({
    required String symbol,
    String interval = '15m',
  }) =>
      Mt5CandleService(client: client, baseUrl: baseUrl)
          .latest(symbol: symbol, interval: interval);
}
