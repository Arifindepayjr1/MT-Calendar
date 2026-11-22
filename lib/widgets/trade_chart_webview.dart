import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/services/trade_chart_analysis.dart';
import 'package:trader_log/services/trade_chart_markers.dart';
import 'package:trader_log/services/trade_chart_window.dart';
import 'package:trader_log/services/trade_level_analysis.dart';
import 'package:trader_log/services/yahoo_candle_service.dart';

import 'trade_chart_platform.dart';

const _chartBg = Color(0xFF090D0B);
const _chartInk = Color(0xFFE8ECE8);
const _chartMint = Color(0xFFB7F7C4);
const _chartMuted = Color(0xFF858D86);
const _chartBorder = Color(0xFF303832);

/// Must stay in sync with TIMEFRAMES in chart_engine/src/main.js and the
/// proxy allowlist in functions/api/candles.js.
const chartTimeframes = ['1m', '5m', '15m', '30m', '1h', '4h', '1d'];

String chartTimeframeLabel(String interval) =>
    interval == '1h' ? '1H' : interval == '1d' ? '1D' : interval;

// Marker colours mirror TradeChartMarkers in trade_chart_markers.dart.
const _entryColor = Color(0xFFFFFFFF);
const _slColor = Color(0xFFFF4D4D);
const _tpColor = Color(0xFF2ED47A);

/// Hosts the TradeCanvas chart and bridges its messages to Flutter.
///
/// Candles come from [YahooCandleService]; user drawings are persisted per
/// trade through [TradeChartAnalysisStore] and restored on every open. The
/// chart is a plain historical view — no replay — with compact entry, exit and
/// TP/SL touch markers positioned at exact trade times and prices.
class TradeChartWebView extends StatefulWidget {
  final Trade trade;
  final YahooCandleSeries series;

  /// Explicitly selected interval, kept separate from the auto-detected one so
  /// inline and full-screen views stay in sync.
  final String? timeframe;
  final ValueChanged<TradeChartAnalysis>? onAnalysisSaved;
  final ValueChanged<String>? onTimeframeChanged;
  final VoidCallback? onRefresh;
  final bool allowFullscreen;

  const TradeChartWebView({
    super.key,
    required this.trade,
    required this.series,
    this.timeframe,
    this.onAnalysisSaved,
    this.onTimeframeChanged,
    this.onRefresh,
    this.allowFullscreen = true,
  });

  String get effectiveTimeframe =>
      TradeChartWindow.effective(timeframe, series.interval);

  @override
  State<TradeChartWebView> createState() => _TradeChartWebViewState();
}

class _TradeChartWebViewState extends State<TradeChartWebView> {
  static const _store = TradeChartAnalysisStore();

  Future<TradeChartPlatform>? _opening;
  TradeChartPlatform? _platform;
  String? _error;
  bool _chartReady = false;
  bool _seriesLoaded = false;
  Map<String, dynamic>? _crosshair;
  bool _crosshairVisible = true;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant TradeChartWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trade.id != widget.trade.id ||
        oldWidget.effectiveTimeframe != widget.effectiveTimeframe ||
        !identical(oldWidget.series, widget.series) ||
        oldWidget.series.ticker != widget.series.ticker ||
        oldWidget.series.interval != widget.series.interval ||
        oldWidget.series.candles.length != widget.series.candles.length) {
      _open();
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
        // Frame the real trade window; the series itself is never sliced.
        _postCommand('focusTrade');
        break;
      case 'crosshairMoved':
        setState(() => _crosshair = payload);
        break;
      case 'crosshairChanged':
        setState(() => _crosshairVisible = payload['visible'] as bool? ?? true);
        break;
      case 'chartError':
        setState(() {
          _error =
              payload['message'] as String? ?? 'The chart reported an error.';
        });
        break;
      case 'analysisChanged':
        _saveAnalysis(payload);
        break;
      case 'timeframeChanged':
        final timeframe = payload['timeframe'] as String?;
        if (timeframe != null && timeframe.isNotEmpty) {
          widget.onTimeframeChanged?.call(timeframe);
        }
        break;
    }
  }

  void _postCommand(String type, [Map<String, dynamic>? payload]) {
    _platform?.handle.post(
      jsonEncode(<String, dynamic>{
        'type': type,
        'payload': ?payload,
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

  TradeLevelAnalysis get _analysis => analyseTradeLevels(
    type: widget.trade.type,
    openTime: widget.trade.openTime,
    closeTime: widget.trade.closeTime,
    stoploss: widget.trade.stoploss,
    takeProfit: widget.trade.takeProfit,
    candles: widget.series.candles
        .map((c) => AnalysisCandle(time: c.time, high: c.high, low: c.low))
        .toList(growable: false),
  );

  void _openFullscreen() {
    final series = widget.series;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _FullscreenTradeChart(
          trade: widget.trade,
          series: series,
          initialTimeframe: widget.effectiveTimeframe,
          onTimeframeChanged: widget.onTimeframeChanged,
        ),
      ),
    );
  }

  Future<void> _sendSeries() async {
    final platform = _platform;
    if (platform == null) return;
    final saved = await _store.load(widget.trade.id);
    if (!mounted || _platform != platform) return;
    final markers = TradeChartMarkers.build(
      trade: widget.trade,
      analysis: _analysis,
    );

    platform.handle.post(
      jsonEncode(<String, dynamic>{
        'type': 'loadSeries',
        'payload': <String, dynamic>{
          'candles': widget.series.candles
              .map((candle) => candle.toChartJson())
              .toList(growable: false),
          'trade': widget.trade.toJson(),
          'markers': markers.map((marker) => marker.toJson()).toList(),
          'timeframe': widget.effectiveTimeframe,
          'drawings': saved?.drawings ?? const <dynamic>[],
          'dataSource': 'Yahoo Finance',
          'sourceNote': widget.series.sourceNote,
        },
      }),
    );
  }

  Future<void> _saveAnalysis(Map<String, dynamic> payload) async {
    final tradeId = widget.trade.id;
    final analysis = TradeChartAnalysis(
      tradeId: tradeId,
      timeframe: payload['timeframe'] as String? ?? widget.series.interval,
      drawings: (payload['drawings'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      settings: decodeChartMessage(payload['settings']),
      updatedAt: DateTime.now(),
    );
    await _store.save(analysis);
    if (!mounted) return;
    widget.onAnalysisSaved?.call(analysis);
  }

  Future<void> _clearAnalysis() async {
    await _store.clear(widget.trade.id);
    if (!mounted) return;
    _platform?.handle.post(
      jsonEncode(<String, dynamic>{
        'type': 'restoreAnalysis',
        'payload': <String, dynamic>{'drawings': const <dynamic>[]},
      }),
    );
    setState(() => _error = null);
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
            if (_seriesLoaded && _error == null) _chartActions(),
            if (_seriesLoaded && _error == null) _crosshairTooltip(),
            if (_seriesLoaded && _error == null) _levelLegend(),
            Positioned(
              right: 6,
              bottom: 6,
              child: Tooltip(
                message: 'Clear chart drawings',
                child: SizedBox(
                  width: 26,
                  height: 26,
                  child: IconButton(
                    onPressed: _clearAnalysis,
                    padding: EdgeInsets.zero,
                    iconSize: 14,
                    color: _chartMuted,
                    icon: const Icon(Icons.undo_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xD0090D0B),
                      side: const BorderSide(color: _chartBorder),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _chartActions() => Positioned(
    left: 6,
    top: 6,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xD0090D0B),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: _chartBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _controlButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Fetch latest candles',
            onPressed: widget.onRefresh ?? () {},
            enabled: widget.onRefresh != null,
          ),
          _controlButton(
            icon: Icons.fit_screen_rounded,
            tooltip: 'Zoom to trade window',
            onPressed: () => _postCommand('focusTrade'),
          ),
          _controlButton(
            icon: Icons.zoom_out_map_rounded,
            tooltip: 'Fit all loaded candles',
            onPressed: () => _postCommand('fitAll'),
          ),
          _controlButton(
            icon: _crosshairVisible
                ? Icons.center_focus_strong_rounded
                : Icons.center_focus_weak_rounded,
            tooltip: _crosshairVisible ? 'Hide crosshair' : 'Show crosshair',
            onPressed: () => _postCommand('toggleCrosshair'),
          ),
          if (widget.allowFullscreen)
            _controlButton(
              icon: Icons.fullscreen_rounded,
              tooltip: 'Open full-screen chart',
              onPressed: _openFullscreen,
            ),
        ],
      ),
    ),
  );

  Widget _controlButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool enabled = true,
  }) => Tooltip(
    message: tooltip,
    child: IconButton(
      onPressed: enabled ? onPressed : null,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
      iconSize: 14,
      color: enabled ? _chartMint : _chartMuted,
      icon: Icon(icon),
    ),
  );

  Widget _crosshairTooltip() {
    final data = _crosshair;
    if (data == null || !_crosshairVisible || data['time'] == null) {
      return const SizedBox.shrink();
    }
    final time = (data['time'] as num).toInt();
    final volume = data['volume'];
    return Positioned(
      right: 6,
      top: 38,
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
                  if (volume is num) Text('Vol ${_fmt(volume)}'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _fmt(dynamic value) {
    if (value is! num) return '—';
    final abs = value.abs();
    return value.toStringAsFixed(abs >= 100 ? 2 : abs >= 1 ? 4 : 5);
  }

  Widget _levelLegend() {
    final analysis = _analysis;
    final trade = widget.trade;
    final outcome = switch (trade.outcome) {
      TradeOutcome.win => 'Win',
      TradeOutcome.loss => 'Loss',
      TradeOutcome.breakeven => 'Breakeven',
    };
    final lines = <String>[
      if (widget.series.candles.isEmpty)
        'No candles available for this timeframe'
      else ...[
        'Entry ${formatTime(trade.openTime.toUtc().millisecondsSinceEpoch ~/ 1000)} '
            '@ ${_fmt(trade.openPrice)}',
        '${TradeChartMarkers.exitLabel(trade.closeReason)} '
            '${formatTime(trade.closeTime.toUtc().millisecondsSinceEpoch ~/ 1000)} '
            '@ ${_fmt(trade.closePrice)} · $outcome',
        if (analysis.tpTouched)
          'TP touched ${formatTime(analysis.firstTpTime!)}'
        else if (trade.takeProfit != null)
          'TP not touched in loaded data',
        if (analysis.slTouched)
          'SL touched ${formatTime(analysis.firstSlTime!)}'
        else if (trade.stoploss != null)
          'SL not touched in loaded data',
        describeCloseReason(trade.closeReason),
        if (analysis.bothTouchedInSameCandle)
          TradeChartMarkers.ambiguityMessage,
        if (analysis.entryOutsideSeries || analysis.exitOutsideSeries)
          'Trade time outside loaded candle range — increase context or try another timeframe.',
      ],
    ];
    return Positioned(
      left: 6,
      bottom: 6,
      child: IgnorePointer(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xD0090D0B),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _chartBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LegendItem(_entryColor, 'ENTRY'),
                    _LegendItem(_tpColor, 'TP TOUCH'),
                    _LegendItem(_slColor, 'SL TOUCH'),
                  ],
                ),
                const SizedBox(height: 2),
                ...lines.map(
                  (line) => Text(
                    line,
                    style: const TextStyle(color: _chartMuted, fontSize: 8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem(this.color, this.label);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(color: _chartMuted, fontSize: 8),
        ),
      ],
    ),
  );
}

/// A route-sized chart used by the full-screen button. It owns its own candle
/// fetch so refreshing or changing timeframe here also updates the inline
/// chart through [onTimeframeChanged].
class _FullscreenTradeChart extends StatefulWidget {
  final Trade trade;
  final YahooCandleSeries series;
  final String initialTimeframe;
  final ValueChanged<String>? onTimeframeChanged;

  const _FullscreenTradeChart({
    required this.trade,
    required this.series,
    required this.initialTimeframe,
    this.onTimeframeChanged,
  });

  @override
  State<_FullscreenTradeChart> createState() => _FullscreenTradeChartState();
}

class _FullscreenTradeChartState extends State<_FullscreenTradeChart> {
  late YahooCandleSeries _series;
  late String _interval;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _series = widget.series;
    _interval = widget.initialTimeframe;
  }

  Future<void> _reload({String? interval, bool live = false}) async {
    if (_refreshing) return;
    final requested = interval ?? _interval;
    setState(() => _refreshing = true);
    try {
      final next = await YahooCandleService().loadForTrade(
        widget.trade,
        interval: requested,
        live: live,
      );
      if (!mounted) return;
      setState(() {
        _series = next;
        _interval = requested;
      });
      if (interval != null) widget.onTimeframeChanged?.call(requested);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$error'),
          backgroundColor: const Color(0xFF202A22),
        ),
      );
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Widget _timeframeSelector() => DropdownButton<String>(
    value: _interval,
    dropdownColor: const Color(0xFF121A14),
    style: const TextStyle(color: _chartInk, fontSize: 12),
    underline: const SizedBox.shrink(),
    onChanged: _refreshing
        ? null
        : (value) {
            if (value != null) _reload(interval: value);
          },
    items: [
      for (final interval in chartTimeframes)
        DropdownMenuItem(
          value: interval,
          child: Text(chartTimeframeLabel(interval)),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _chartBg,
    appBar: AppBar(
      backgroundColor: _chartBg,
      foregroundColor: _chartInk,
      title: Text(
        '${widget.trade.symbol}  ·  ${chartTimeframeLabel(_interval)}',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      actions: [
        _timeframeSelector(),
        IconButton(
          tooltip: 'Fetch latest candles',
          onPressed: _refreshing ? null : () => _reload(live: true),
          icon: _refreshing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_rounded),
          color: _chartMint,
        ),
        IconButton(
          tooltip: 'Close full screen',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close_rounded),
          color: _chartMint,
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: TradeChartWebView(
              trade: widget.trade,
              series: _series,
              timeframe: _interval,
              allowFullscreen: false,
              onRefresh: () => _reload(live: true),
              onTimeframeChanged: (timeframe) {
                // Keep the inline chart on the same timeframe when the chart's
                // own toolbar is used inside full-screen mode.
                widget.onTimeframeChanged?.call(timeframe);
                _reload(interval: timeframe);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              '${_series.symbol} · ${_series.sourceNote} · ${_series.candles.length} real candles',
              style: const TextStyle(color: _chartMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    ),
  );
}
