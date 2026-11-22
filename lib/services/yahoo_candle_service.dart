import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:trader_log/model/trade.model.dart';

import 'trade_chart_window.dart';

class MarketCandle {
  final int time;
  final double open, high, low, close;

  /// Null when the provider did not supply volume. Never defaulted to zero,
  /// because a fabricated 0 would be displayed as real volume.
  final double? volume;

  const MarketCandle({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
  });

  Map<String, Object> toChartJson() => {
    'time': time,
    'open': open,
    'high': high,
    'low': low,
    'close': close,
    'volume': ?volume,
  };
}

class YahooCandleSeries {
  final String symbol, ticker, interval, sourceNote;
  final List<MarketCandle> candles;
  const YahooCandleSeries({
    required this.symbol,
    required this.ticker,
    required this.interval,
    required this.sourceNote,
    required this.candles,
  });
}

class CandleDataException implements Exception {
  final String message;
  const CandleDataException(this.message);
  @override
  String toString() => message;
}

class YahooCandleService {
  static const supportedIntervals = TradeChartWindow.intervals;

  const YahooCandleService();

  /// Loads the real OHLC window around a trade.
  ///
  /// [live] extends the right edge to "now" for recent trades and skips the
  /// proxy cache, which is what the full-screen chart's Refresh button uses.
  Future<YahooCandleSeries> loadForTrade(
    Trade trade, {
    String? interval,
    bool live = false,
  }) async {
    final instrument = _instrumentFor(trade.symbol);
    if (instrument == null) {
      throw const CandleDataException(
        'No Yahoo Finance symbol mapping is available for this instrument.',
      );
    }
    if (interval != null && !TradeChartWindow.isSupported(interval)) {
      throw CandleDataException(
        'Unsupported timeframe "$interval". Choose 1m, 5m, 15m, 30m, 1H, 4H or 1D.',
      );
    }
    final requested = interval != null
        ? <String>[interval]
        : TradeChartWindow.fallbacks(
            tradeDuration: trade.closeTime.difference(trade.openTime),
            age: DateTime.now().toUtc().difference(trade.openTime.toUtc()),
          );
    final isLive = live && TradeChartWindow.isRecent(trade.openTime);
    final now = DateTime.now().toUtc();
    final client = http.Client();
    CandleDataException? lastNoDataError;
    try {
      for (final candidate in requested) {
        try {
          final window = TradeChartWindow.config(candidate);
          var start = window.startFor(trade.openTime);
          var end = window.endFor(trade.closeTime);
          if (isLive && now.isAfter(end)) end = now.add(const Duration(minutes: 2));
          final candles = await _fetchInterval(
            client,
            instrument.ticker,
            candidate,
            start: start,
            end: end,
            live: isLive,
          );
          return YahooCandleSeries(
            symbol: instrument.label,
            ticker: instrument.ticker,
            interval: candidate,
            sourceNote: isLive
                ? '${instrument.sourceNote} · live refresh'
                : instrument.sourceNote,
            candles: candles,
          );
        } on _NoCandlesException catch (error) {
          lastNoDataError = CandleDataException(error.message);
        }
      }
    } finally {
      client.close();
    }
    throw lastNoDataError ??
        const CandleDataException('No historical candles are available.');
  }

  Future<List<MarketCandle>> _fetchInterval(
    http.Client client,
    String ticker,
    String interval, {
    required DateTime start,
    required DateTime end,
    bool live = false,
  }) async {
    final cacheBuster = live
        ? <String, String>{
            '_': DateTime.now().toUtc().millisecondsSinceEpoch.toString(),
          }
        : const <String, String>{};
    final yahooUri = Uri.https(
      'query1.finance.yahoo.com',
      '/v8/finance/chart/$ticker',
      {
        'period1': (start.millisecondsSinceEpoch ~/ 1000).toString(),
        'period2': (end.millisecondsSinceEpoch ~/ 1000).toString(),
        'interval': interval,
        'includePrePost': 'false',
        'events': 'div,splits',
        ...cacheBuster,
      },
    );
    final queryParameters = <String, String>{
      'symbol': ticker,
      'period1': (start.millisecondsSinceEpoch ~/ 1000).toString(),
      'period2': (end.millisecondsSinceEpoch ~/ 1000).toString(),
      'interval': interval,
      ...cacheBuster,
    };
    final candidates = <Uri>[
      if (kIsWeb)
        Uri.base
            .resolve('/api/candles')
            .replace(queryParameters: queryParameters)
      else
        yahooUri,
    ];
    if (kIsWeb) {
      // `flutter run -d chrome` only serves static files, so /api/candles is
      // absent. A local dev proxy can stand in for the Pages Function.
      candidates.add(
        Uri.parse('http://127.0.0.1:8787/api/candles')
            .replace(queryParameters: queryParameters),
      );
    }

    http.Response? response;
    var functionMissing = false;
    for (var i = 0; i < candidates.length; i++) {
      try {
        final attempt = await client
            .get(
              candidates[i],
              headers: {
                'Accept': 'application/json',
                if (!kIsWeb) 'User-Agent': 'Mozilla/5.0 TraderLog/1.0',
              },
            )
            .timeout(const Duration(seconds: 15));
        // Flutter's dev server may answer unknown paths with index.html
        // instead of a 404, so also treat a non-JSON body as "no function".
        if (i == 0 &&
            kIsWeb &&
            (attempt.statusCode == 404 ||
                !attempt.body.trimLeft().startsWith('{'))) {
          functionMissing = true;
          continue;
        }
        response = attempt;
        break;
      } on Exception {
        // Try the next candidate before giving up.
      }
    }
    if (response == null) {
      if (kIsWeb) {
        if (functionMissing) {
          throw const CandleDataException(
            'No /api/candles endpoint is available. Run "npx wrangler pages dev build/web", or start "npm run dev:proxy" in chart_engine/ before flutter run -d chrome.',
          );
        }
        throw const CandleDataException(
          'Could not reach a candle endpoint. Start the Cloudflare Pages function or the local dev proxy.',
        );
      }
      throw const CandleDataException(
        'Could not reach Yahoo Finance. Check your internet connection and try again.',
      );
    }
    if (response.statusCode == 429) {
      throw const CandleDataException(
        'Yahoo Finance is rate limiting chart requests. Try again later.',
      );
    }
    if (response.statusCode != 200) {
      throw CandleDataException(
        kIsWeb && response.statusCode == 404
            ? 'The /api/candles endpoint is missing. Deploy the web app with its candle function enabled.'
            : 'Yahoo Finance returned HTTP ${response.statusCode} for this symbol.',
      );
    }
    late Map<String, dynamic> payload;
    try {
      payload = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw const CandleDataException(
        'Yahoo Finance returned chart data in an unreadable format.',
      );
    }
    final chart = payload['chart'] as Map<String, dynamic>?;
    final error = chart?['error'];
    if (error != null) {
      final description = (error as Map<String, dynamic>)['description'];
      throw CandleDataException(
        description is String && description.isNotEmpty
            ? description
            : 'Yahoo Finance could not load chart data for this symbol.',
      );
    }
    final results = chart?['result'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw const _NoCandlesException(
        'No candles are available for this trade date and timeframe.',
      );
    }
    final result = results.first as Map<String, dynamic>;
    final timestamps = result['timestamp'] as List<dynamic>? ?? const [];
    final indicators = result['indicators'] as Map<String, dynamic>?;
    final quotes = indicators?['quote'] as List<dynamic>?;
    if (quotes == null || quotes.isEmpty) {
      throw const _NoCandlesException(
        'No candles are available for this trade date and timeframe.',
      );
    }
    final quote = quotes.first as Map<String, dynamic>;
    final opens = quote['open'] as List<dynamic>? ?? const [];
    final highs = quote['high'] as List<dynamic>? ?? const [];
    final lows = quote['low'] as List<dynamic>? ?? const [];
    final closes = quote['close'] as List<dynamic>? ?? const [];
    final volumes = quote['volume'] as List<dynamic>?;
    final candles = <MarketCandle>[];
    for (var i = 0; i < timestamps.length; i++) {
      if (i >= opens.length ||
          i >= highs.length ||
          i >= lows.length ||
          i >= closes.length) {
        continue;
      }
      final time = timestamps[i],
          open = opens[i],
          high = highs[i],
          low = lows[i],
          close = closes[i];
      if (time is! num ||
          open is! num ||
          high is! num ||
          low is! num ||
          close is! num) {
        continue;
      }
      final volumeList = volumes;
      final rawVolume = volumeList != null && i < volumeList.length
          ? volumeList[i]
          : null;
      candles.add(
        MarketCandle(
          time: time.toInt(),
          open: open.toDouble(),
          high: high.toDouble(),
          low: low.toDouble(),
          close: close.toDouble(),
          volume: rawVolume is num ? rawVolume.toDouble() : null,
        ),
      );
    }
    candles.sort((a, b) => a.time.compareTo(b.time));
    if (candles.isEmpty) {
      throw const _NoCandlesException(
        'No candles are available for this trade date and timeframe.',
      );
    }
    return candles;
  }

  _YahooInstrument? _instrumentFor(String input) {
    var symbol = input.trim().split(RegExp(r'[-.]')).first;
    symbol = symbol.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    if (RegExp(r'^[A-Z]{7}$').hasMatch(symbol)) symbol = symbol.substring(0, 6);
    switch (symbol) {
      case 'XAUUSD':
        return const _YahooInstrument(
          'Gold / US Dollar',
          'GC=F',
          'Gold futures proxy (not the MT5 spot feed)',
        );
      case 'XAGUSD':
        return const _YahooInstrument(
          'Silver / US Dollar',
          'SI=F',
          'Silver futures proxy (not the MT5 spot feed)',
        );
      case 'BTCUSD':
        return const _YahooInstrument(
          'Bitcoin / US Dollar',
          'BTC-USD',
          'Yahoo Finance crypto feed',
        );
      case 'ETHUSD':
        return const _YahooInstrument(
          'Ethereum / US Dollar',
          'ETH-USD',
          'Yahoo Finance crypto feed',
        );
      case 'US30':
        return const _YahooInstrument(
          'Dow Jones futures',
          'YM=F',
          'Dow futures proxy',
        );
      case 'NAS100':
      case 'US100':
        return const _YahooInstrument(
          'Nasdaq 100 futures',
          'NQ=F',
          'Nasdaq futures proxy',
        );
      case 'US500':
      case 'SPX500':
        return const _YahooInstrument(
          'S&P 500 futures',
          'ES=F',
          'S&P futures proxy',
        );
    }
    if (RegExp(r'^[A-Z]{6}$').hasMatch(symbol)) {
      return _YahooInstrument(
        '${symbol.substring(0, 3)}/${symbol.substring(3)}',
        '$symbol=X',
        'Yahoo Finance forex feed',
      );
    }
    if (RegExp(r'^[A-Z]{1,10}$').hasMatch(symbol)) {
      return _YahooInstrument(symbol, symbol, 'Yahoo Finance market feed');
    }
    return null;
  }
}

class _YahooInstrument {
  final String label, ticker, sourceNote;
  const _YahooInstrument(this.label, this.ticker, this.sourceNote);
}

class _NoCandlesException implements Exception {
  final String message;
  const _NoCandlesException(this.message);
}
