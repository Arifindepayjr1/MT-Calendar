import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/services/market_candle.dart';
import 'package:trader_log/services/mt5_candle_service.dart';
import 'package:trader_log/services/trade_chart_markers.dart';
import 'package:trader_log/services/trade_chart_message.dart';

import 'trade_chart_platform.dart';

const _chartBg = Color(0xFF090D0B);
const _chartInk = Color(0xFFE8ECE8);
const _chartMint = Color(0xFFB7F7C4);
const _chartMuted = Color(0xFF858D86);
const _chartBorder = Color(0xFF303832);

/// A plain historical TradeCanvas chart fed only by the NestJS MT5 bridge.
///
/// The chart opens framed on the trade's broker session. There are no drawing
/// tools, saved annotation layers, timeframe/date pickers or full-screen mode.
class TradeChartWebView extends StatefulWidget {
  final Trade trade;
  final MarketCandleSeries series;
  final DateTime sessionDate;

  /// Injectable only for tests that verify the MT5 request path.
  final http.Client? client;

  const TradeChartWebView({
    super.key,
    required this.trade,
    required this.series,
    required this.sessionDate,
    this.client,
  });

  @override
  State<TradeChartWebView> createState() => _TradeChartWebViewState();
}

class _TradeChartWebViewState extends State<TradeChartWebView> {
  Future<TradeChartPlatform>? _opening;
  TradeChartPlatform? _platform;
  String? _error;
  bool _chartReady = false;
  bool _seriesLoaded = false;
  Map<String, dynamic>? _crosshair;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant TradeChartWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trade.id != widget.trade.id) {
      _open();
      return;
    }
    final seriesChanged = !identical(oldWidget.series, widget.series) ||
        oldWidget.series.ticker != widget.series.ticker ||
        oldWidget.series.candles.length != widget.series.candles.length ||
        oldWidget.sessionDate != widget.sessionDate;
    if (seriesChanged) {
      if (_platform == null) {
        _open();
      } else {
        setState(() => _seriesLoaded = false);
        _sendSeries();
      }
    }
  }

  @override
  void dispose() {
    _platform?.handle.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    _platform?.handle.dispose();
    final opening = createTradeChartPlatform(onMessage: _handleMessage);
    setState(() {
      _opening = opening;
      _platform = null;
      _error = null;
      _chartReady = false;
      _seriesLoaded = false;
      _crosshair = null;
    });
    try {
      final platform = await opening;
      if (!mounted || _opening != opening) {
        await platform.handle.dispose();
        return;
      }
      setState(() => _platform = platform);
      if (_chartReady) _sendSeries();
    } catch (error) {
      if (mounted && _opening == opening) {
        setState(() => _error = 'The chart could not start: $error');
      }
    }
  }

  void _handleMessage(String raw) {
    if (!mounted) return;
    final envelope = decodeChartMessage(raw);
    final type = envelope['type'] as String?;
    if (type == null) return;
    final payload = decodeChartMessage(envelope['payload']);

    switch (type) {
      case 'chartReady':
        _chartReady = true;
        _sendSeries();
        break;
      case 'seriesLoaded':
        setState(() => _seriesLoaded = true);
        // Every load opens on the broker session for the trade's date.
        _postCommand('focusTrade');
        break;
      case 'crosshairMoved':
        setState(() => _crosshair = payload);
        break;
      case 'chartError':
        setState(() {
          _error =
              payload['message'] as String? ?? 'The chart reported an error.';
        });
        break;
    }
  }

  void _postCommand(String type) {
    _platform?.handle.post(jsonEncode(<String, dynamic>{
      'type': type,
      'payload': <String, dynamic>{},
    }));
  }

  void _sendSeries() {
    final platform = _platform;
    if (platform == null || !_chartReady) return;
    final markers = TradeChartMarkers.entryExit(widget.trade);

    platform.handle.post(
      jsonEncode(<String, dynamic>{
        'type': 'loadSeries',
        'payload': <String, dynamic>{
          'candles': widget.series.candles
              .map((candle) => candle.toChartJson())
              .toList(growable: false),
          'trade': widget.trade.toJson(),
          'markers': markers.map((marker) => marker.toJson()).toList(),
          'timeframe': widget.series.interval,
          // The JS chart only labels its feed MT5 when the backend confirmed
          // an MT5 series. An unconfirmed payload is never labelled as MT5.
          'dataSource': widget.series.source == 'mt5' ? 'MT5' : 'Unconfirmed',
          'sourceNote': widget.series.sourceNote,
          'source': widget.series.source,
          'sessionDate': Mt5CandleService.formatDate(widget.sessionDate),
          'sessionStart': widget.series.sessionStart?.toUtc().millisecondsSinceEpoch,
          'sessionEnd': widget.series.sessionEnd?.toUtc().millisecondsSinceEpoch,
          'sessionReason': widget.series.sessionReason,
        },
      }),
    );
  }

  static String formatTime(int seconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ).toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'
        ':${date.second.toString().padLeft(2, '0')}';
  }

  static String _fmt(dynamic value) {
    if (value is! num) return '—';
    final abs = value.abs();
    return value.toStringAsFixed(abs >= 100 ? 2 : abs >= 1 ? 4 : 5);
  }

  Widget _crosshairTooltip() {
    final data = _crosshair;
    if (data == null || data['time'] == null) {
      return const SizedBox.shrink();
    }
    final time = (data['time'] as num).toInt();
    final volume = data['volume'];
    return Positioned(
      right: 6,
      top: 6,
      child: IgnorePointer(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xF0090D0B),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _chartBorder),
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: _chartInk,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatTime(time)),
                  Text('O ${_fmt(data['open'])}  H ${_fmt(data['high'])}'),
                  Text('L ${_fmt(data['low'])}  C ${_fmt(data['close'])}'),
                  if (volume is num) Text('Real vol ${_fmt(volume)}'),
                  if (data['tickVolume'] is num)
                    Text('Tick vol ${(data['tickVolume'] as num).toInt()}'),
                  if (data['spread'] is num)
                    Text('Spread ${(data['spread'] as num).toInt()}'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TradeChartPlatform>(
      future: _opening,
      builder: (context, snapshot) {
        final platform = _platform ?? snapshot.data;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (snapshot.connectionState != ConnectionState.done ||
                platform == null)
              const Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _chartMint,
                  ),
                ),
              )
            else
              platform.view,
            if (!_seriesLoaded && _error == null && platform != null)
              const IgnorePointer(
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0x99090D0B),
                      borderRadius: BorderRadius.all(Radius.circular(6)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(
                        'Loading chart data…',
                        style: TextStyle(color: _chartMuted, fontSize: 10),
                      ),
                    ),
                  ),
                ),
              ),
            if (_error != null)
              Positioned.fill(
                child: ColoredBox(
                  color: _chartBg,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _chartMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_seriesLoaded && _error == null) _crosshairTooltip(),
          ],
        );
      },
    );
  }
}
