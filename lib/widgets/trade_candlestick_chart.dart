import 'package:flutter/material.dart';
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/services/yahoo_candle_service.dart';

import 'trade_chart_webview.dart';

enum _ChartMode { advanced, simple }

const _chartBg = Color(0xFF090D0B);
const _chartMint = Color(0xFFB7F7C4);
const _chartCoral = Color(0xFFFF7C7C);
const _chartMuted = Color(0xFF858D86);
const _chartBorder = Color(0xFF303832);
const _chartInk = Color(0xFFE8ECE8);

class TradeCandlestickChart extends StatefulWidget {
  final Trade trade;
  final List<String> strategyNames;
  const TradeCandlestickChart({
    super.key,
    required this.trade,
    required this.strategyNames,
  });

  @override
  State<TradeCandlestickChart> createState() => _TradeCandlestickChartState();
}

class _TradeCandlestickChartState extends State<TradeCandlestickChart> {
  late Future<YahooCandleSeries> _series;
  String? _timeframe;
  _ChartMode _mode = _ChartMode.advanced;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load({String? interval, bool live = false}) {
    if (interval != null) _timeframe = interval;
    final future = YahooCandleService().loadForTrade(
      widget.trade,
      interval: interval ?? _timeframe,
      live: live,
    );
    // The first load has no explicit timeframe; adopt the interval the service
    // actually found so inline and full-screen start from the same selection.
    if (interval == null && _timeframe == null) {
      future.then((series) {
        if (mounted) setState(() => _timeframe = series.interval);
      }).catchError((_) {});
    }
    _series = future;
  }

  void _retry() => setState(() => _load());

  void _refresh() => setState(() => _load(live: true));

  void _setMode(_ChartMode mode) => setState(() => _mode = mode);

  void _onTimeframeChanged(String timeframe) =>
      setState(() => _load(interval: timeframe));

  Widget _timeframeSelector() => DropdownButton<String?>(
    value: _timeframe,
    dropdownColor: const Color(0xFF121A14),
    style: const TextStyle(color: _chartMint, fontSize: 10),
    underline: const SizedBox.shrink(),
    onChanged: (value) => setState(() {
      if (value == null) _timeframe = null;
      _load(interval: value);
    }),
    items: [
      const DropdownMenuItem<String?>(value: null, child: Text('Auto')),
      for (final interval in chartTimeframes)
        DropdownMenuItem<String?>(
          value: interval,
          child: Text(chartTimeframeLabel(interval)),
        ),
    ],
  );

  Widget _modeChip(_ChartMode mode, String label) {
    final selected = _mode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => _setMode(mode),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF101310) : _chartMuted,
        fontSize: 10,
      ),
      selectedColor: _chartMint,
      backgroundColor: const Color(0xFF162319),
      side: const BorderSide(color: _chartBorder),
      padding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (widget.strategyNames.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 5,
          children: [
            for (final name in widget.strategyNames)
              Chip(
                label: Text(name),
                visualDensity: VisualDensity.compact,
                backgroundColor: const Color(0xFF162319),
                side: const BorderSide(color: _chartBorder),
                labelStyle: const TextStyle(color: _chartMint, fontSize: 10),
                padding: EdgeInsets.zero,
              ),
          ],
        ),
      ],
      const SizedBox(height: 10),
      Row(
        children: [
          const Text(
            'Chart engine',
            style: TextStyle(color: _chartMuted, fontSize: 10),
          ),
          const SizedBox(width: 8),
          _modeChip(_ChartMode.advanced, 'Advanced'),
          const SizedBox(width: 6),
          _modeChip(_ChartMode.simple, 'Simple'),
          const SizedBox(width: 6),
          _timeframeSelector(),
          const Spacer(),
          Tooltip(
            message: 'Fetch latest real candles',
            child: IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              color: _chartMint,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 26, height: 26),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 330,
          width: double.infinity,
          child: FutureBuilder<YahooCandleSeries>(
            future: _series,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _ChartMessage(
                  icon: Icons.candlestick_chart_rounded,
                  message: 'Loading historical candles…',
                  loading: true,
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                final message = snapshot.error is CandleDataException
                    ? (snapshot.error as CandleDataException).message
                    : 'Historical candles could not be loaded.';
                return _ChartMessage(
                  icon: Icons.show_chart_rounded,
                  message: message,
                  retry: _retry,
                );
              }
              final series = snapshot.requireData;
              return Stack(
                children: [
                  Positioned.fill(
                    child: _mode == _ChartMode.advanced
                        ? TradeChartWebView(
                            trade: widget.trade,
                            series: series,
                            timeframe: _timeframe,
                            onTimeframeChanged: _onTimeframeChanged,
                            onRefresh: _refresh,
                          )
                        : _InteractiveCandlestickChart(
                            trade: widget.trade,
                            candles: series.candles,
                          ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 6,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _chartBg.withValues(alpha: .88),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Text(
                            '${series.symbol} · ${series.interval} · ${series.sourceNote}',
                            style: const TextStyle(
                              color: _chartMuted,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          _ChartLegend(color: _chartInk, label: 'Entry'),
          _ChartLegend(color: _chartCoral, label: 'Stop loss / losing exit'),
          _ChartLegend(color: _chartMint, label: 'Take profit / winning exit'),
        ],
      ),
    ],
  );
}

class _ChartMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final bool loading;
  final VoidCallback? retry;
  const _ChartMessage({
    required this.icon,
    required this.message,
    this.loading = false,
    this.retry,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: _chartBg,
    padding: const EdgeInsets.all(18),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 310),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _chartMint,
                ),
              )
            else
              Icon(icon, color: _chartMuted, size: 24),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _chartMuted,
                fontSize: 11,
                height: 1.45,
              ),
            ),
            if (retry != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: TextButton.styleFrom(foregroundColor: _chartMint),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(color: _chartMuted, fontSize: 9)),
    ],
  );
}

class _InteractiveCandlestickChart extends StatefulWidget {
  final Trade trade;
  final List<MarketCandle> candles;

  const _InteractiveCandlestickChart({
    required this.trade,
    required this.candles,
  });

  @override
  State<_InteractiveCandlestickChart> createState() =>
      _InteractiveCandlestickChartState();
}

class _InteractiveCandlestickChartState
    extends State<_InteractiveCandlestickChart> {
  double _zoom = 1;
  double _startIndex = 0;
  double _gestureZoom = 1;
  double _gestureStartIndex = 0;
  double _gestureFocalX = 0;
  int? _selectedIndex;

  double get _maxZoom =>
      widget.candles.length > 8 ? widget.candles.length / 8 : 1;

  double _visibleCount(double zoom) => widget.candles.length / zoom;

  double _clampStart(double start, double visibleCount) =>
      start.clamp(0.0, widget.candles.length - visibleCount).toDouble();

  double _plotFraction(double x, double width) {
    final plotWidth = width - 72;
    if (plotWidth <= 0) return 0;
    return ((x - 8) / plotWidth).clamp(0.0, 1.0).toDouble();
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureZoom = _zoom;
    _gestureStartIndex = _startIndex;
    _gestureFocalX = details.localFocalPoint.dx;
  }

  void _onScaleUpdate(ScaleUpdateDetails details, double width) {
    final count = widget.candles.length;
    if (count == 0) return;
    final zoom = (_gestureZoom * details.scale).clamp(1.0, _maxZoom).toDouble();
    final initialCount = _visibleCount(_gestureZoom);
    final visibleCount = _visibleCount(zoom);
    final focusIndex =
        _gestureStartIndex +
        _plotFraction(_gestureFocalX, width) * initialCount;
    final start =
        focusIndex -
        _plotFraction(details.localFocalPoint.dx, width) * visibleCount;
    setState(() {
      _zoom = zoom;
      _startIndex = _clampStart(start, visibleCount);
    });
  }

  void _onTapUp(TapUpDetails details, double width) {
    if (widget.candles.isEmpty) return;
    final rawIndex =
        _startIndex +
        _plotFraction(details.localPosition.dx, width) * _visibleCount(_zoom);
    setState(() {
      _selectedIndex = rawIndex.floor().clamp(0, widget.candles.length - 1);
    });
  }

  void _zoomBy(double factor) {
    final center = _startIndex + _visibleCount(_zoom) / 2;
    final nextZoom = (_zoom * factor).clamp(1.0, _maxZoom).toDouble();
    final nextCount = _visibleCount(nextZoom);
    setState(() {
      _zoom = nextZoom;
      _startIndex = _clampStart(center - nextCount / 2, nextCount);
    });
  }

  void _resetView() {
    setState(() {
      _zoom = 1;
      _startIndex = 0;
      _selectedIndex = null;
    });
  }

  String _price(double value) {
    final abs = value.abs();
    return value.toStringAsFixed(
      abs >= 100
          ? 2
          : abs >= 1
          ? 4
          : 5,
    );
  }

  String _time(int seconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ).toLocal();
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final selected = _selectedIndex == null
          ? null
          : widget.candles[_selectedIndex!.clamp(0, widget.candles.length - 1)];
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _onTapUp(details, constraints.maxWidth),
        onDoubleTap: _resetView,
        onScaleStart: _onScaleStart,
        onScaleUpdate: (details) =>
            _onScaleUpdate(details, constraints.maxWidth),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _CandlestickPainter(
                trade: widget.trade,
                candles: widget.candles,
                startIndex: _startIndex,
                visibleCount: _visibleCount(_zoom),
                selectedIndex: _selectedIndex,
              ),
            ),
            Positioned(
              top: 7,
              left: 8,
              right: 104,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _chartBg.withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: selected == null
                      ? const Text(
                          'Tap a candle to inspect OHLC',
                          style: TextStyle(color: _chartMuted, fontSize: 9),
                        )
                      : Wrap(
                          spacing: 7,
                          runSpacing: 2,
                          children: [
                            Text(
                              _time(selected.time),
                              style: const TextStyle(
                                color: _chartMuted,
                                fontSize: 9,
                              ),
                            ),
                            Text(
                              'O ${_price(selected.open)}',
                              style: const TextStyle(
                                color: _chartInk,
                                fontSize: 9,
                              ),
                            ),
                            Text(
                              'H ${_price(selected.high)}',
                              style: const TextStyle(
                                color: _chartMint,
                                fontSize: 9,
                              ),
                            ),
                            Text(
                              'L ${_price(selected.low)}',
                              style: const TextStyle(
                                color: _chartCoral,
                                fontSize: 9,
                              ),
                            ),
                            Text(
                              'C ${_price(selected.close)}',
                              style: const TextStyle(
                                color: _chartInk,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _chartBg.withValues(alpha: .92),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _chartBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ChartControl(
                      icon: Icons.remove_rounded,
                      tooltip: 'Zoom out',
                      onPressed: () => _zoomBy(.8),
                    ),
                    _ChartControl(
                      icon: Icons.add_rounded,
                      tooltip: 'Zoom in',
                      onPressed: () => _zoomBy(1.25),
                    ),
                    _ChartControl(
                      icon: Icons.fit_screen_rounded,
                      tooltip: 'Reset chart view',
                      onPressed: _resetView,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _ChartControl extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ChartControl({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 28,
    height: 28,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      iconSize: 15,
      color: _chartMuted,
      icon: Icon(icon),
    ),
  );
}

class _CandlestickPainter extends CustomPainter {
  final Trade trade;
  final List<MarketCandle> candles;
  final double startIndex;
  final double visibleCount;
  final int? selectedIndex;

  _CandlestickPainter({
    required this.trade,
    required this.candles,
    required this.startIndex,
    required this.visibleCount,
    required this.selectedIndex,
  });

  static const _plotLeft = 8.0;
  static const _plotTop = 12.0;
  static const _axisWidth = 64.0;
  static const _timeAxisHeight = 24.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(_chartBg, BlendMode.src);
    if (candles.isEmpty || size.width <= _axisWidth + 16 || size.height <= 60) {
      return;
    }

    final plot = Rect.fromLTRB(
      _plotLeft,
      _plotTop,
      size.width - _axisWidth,
      size.height - _timeAxisHeight,
    );
    final viewStart = startIndex
        .clamp(0.0, (candles.length - 1).toDouble())
        .toDouble();
    final viewCount = visibleCount
        .clamp(1.0, candles.length.toDouble())
        .toDouble();
    final firstVisible = viewStart.floor().clamp(0, candles.length - 1);
    final lastVisible = (viewStart + viewCount).ceil().clamp(1, candles.length);
    final visibleCandles = candles.sublist(firstVisible, lastVisible);
    final prices = <double>[
      for (final candle in visibleCandles) ...[candle.high, candle.low],
      trade.openPrice,
      trade.closePrice,
      if (trade.stoploss != null) trade.stoploss!,
      if (trade.takeProfit != null) trade.takeProfit!,
    ].where((price) => price.isFinite).toList();
    if (prices.isEmpty) return;
    var minPrice = prices.reduce((a, b) => a < b ? a : b);
    var maxPrice = prices.reduce((a, b) => a > b ? a : b);
    if (maxPrice == minPrice) {
      final pad = maxPrice.abs() * 0.005 + 0.00001;
      minPrice -= pad;
      maxPrice += pad;
    } else {
      final pad = (maxPrice - minPrice) * 0.08;
      minPrice -= pad;
      maxPrice += pad;
    }
    double yFor(double price) =>
        plot.bottom - (price - minPrice) / (maxPrice - minPrice) * plot.height;

    final gridPaint = Paint()
      ..color = const Color(0xFF1A1F1B)
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = _chartBorder
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = plot.top + plot.height * i / 4;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final price = maxPrice - (maxPrice - minPrice) * i / 4;
      _drawText(
        canvas,
        _formatPrice(price),
        Offset(plot.right + 5, y - 6),
        color: _chartMuted,
        fontSize: 9,
        maxWidth: _axisWidth - 9,
      );
    }
    canvas.drawLine(
      Offset(plot.right, plot.top),
      Offset(plot.right, plot.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      axisPaint,
    );

    int indexForTime(int time) {
      var nearest = 0;
      var distance = (candles.first.time - time).abs();
      for (var i = 1; i < candles.length; i++) {
        final nextDistance = (candles[i].time - time).abs();
        if (nextDistance < distance) {
          nearest = i;
          distance = nextDistance;
        }
      }
      return nearest;
    }

    double xForIndex(int index) =>
        plot.left + ((index + 0.5 - viewStart) / viewCount) * plot.width;

    final entryTime = trade.openTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    final exitTime = trade.closeTime.toUtc().millisecondsSinceEpoch ~/ 1000;
    final entryIndex = indexForTime(entryTime);
    final exitIndex = indexForTime(exitTime);
    final entryX = xForIndex(entryIndex);
    final exitX = xForIndex(exitIndex);
    final zoneLeft = (entryX < exitX ? entryX : exitX)
        .clamp(plot.left, plot.right)
        .toDouble();
    final zoneRight = (entryX > exitX ? entryX : exitX)
        .clamp(plot.left, plot.right)
        .toDouble();
    final zoneWidth = (zoneRight - zoneLeft).clamp(2.0, plot.width).toDouble();
    canvas.save();
    canvas.clipRect(plot);
    if (trade.stoploss != null) {
      final y1 = yFor(trade.openPrice);
      final y2 = yFor(trade.stoploss!);
      canvas.drawRect(
        Rect.fromLTRB(
          zoneLeft,
          y1 < y2 ? y1 : y2,
          zoneLeft + zoneWidth,
          y1 > y2 ? y1 : y2,
        ),
        Paint()..color = _chartCoral.withValues(alpha: .09),
      );
    }
    if (trade.takeProfit != null) {
      final y1 = yFor(trade.openPrice);
      final y2 = yFor(trade.takeProfit!);
      canvas.drawRect(
        Rect.fromLTRB(
          zoneLeft,
          y1 < y2 ? y1 : y2,
          zoneLeft + zoneWidth,
          y1 > y2 ? y1 : y2,
        ),
        Paint()..color = _chartMint.withValues(alpha: .09),
      );
    }

    final step = plot.width / viewCount;
    final candlePaint = Paint()..strokeWidth = 1;
    final bodyWidth = (step * 0.62).clamp(1.0, 8.0).toDouble();
    if (selectedIndex != null &&
        selectedIndex! >= firstVisible &&
        selectedIndex! < lastVisible) {
      final selectedX = xForIndex(selectedIndex!);
      canvas.drawLine(
        Offset(selectedX, plot.top),
        Offset(selectedX, plot.bottom),
        Paint()
          ..color = _chartInk.withValues(alpha: .32)
          ..strokeWidth = 1,
      );
    }
    for (var i = firstVisible; i < lastVisible; i++) {
      final candle = candles[i];
      if (![
        candle.open,
        candle.high,
        candle.low,
        candle.close,
      ].every((v) => v.isFinite)) {
        continue;
      }
      final x = xForIndex(i);
      final rising = candle.close >= candle.open;
      final color = rising ? _chartMint : _chartCoral;
      candlePaint.color = color;
      canvas.drawLine(
        Offset(x, yFor(candle.high)),
        Offset(x, yFor(candle.low)),
        candlePaint,
      );
      final openY = yFor(candle.open);
      final closeY = yFor(candle.close);
      final body = Rect.fromLTRB(
        x - bodyWidth / 2,
        openY < closeY ? openY : closeY,
        x + bodyWidth / 2,
        (openY - closeY).abs() < 1
            ? (openY < closeY ? openY : closeY) + 1
            : (openY > closeY ? openY : closeY),
      );
      canvas.drawRect(body, Paint()..color = color);
    }

    _drawPriceLine(
      canvas,
      plot,
      yFor,
      trade.openPrice,
      _chartInk,
      'ENTRY',
      dashed: false,
    );
    _drawPriceLine(
      canvas,
      plot,
      yFor,
      trade.closePrice,
      trade.outcome == TradeOutcome.win ? _chartMint : _chartCoral,
      'EXIT',
      dashed: true,
    );
    if (trade.stoploss != null) {
      _drawPriceLine(
        canvas,
        plot,
        yFor,
        trade.stoploss!,
        _chartCoral,
        'SL',
        dashed: true,
      );
    }
    if (trade.takeProfit != null) {
      _drawPriceLine(
        canvas,
        plot,
        yFor,
        trade.takeProfit!,
        _chartMint,
        'TP',
        dashed: true,
      );
    }
    canvas.restore();
    _drawTimeMarker(
      canvas,
      plot,
      entryX,
      yFor(
        trade.type == TradeType.buy
            ? candles[entryIndex].low
            : candles[entryIndex].high,
      ),
      'ENTRY',
      _chartInk,
      above: trade.type == TradeType.sell,
    );
    _drawTimeMarker(
      canvas,
      plot,
      exitX,
      yFor(
        trade.outcome == TradeOutcome.win
            ? candles[exitIndex].high
            : candles[exitIndex].low,
      ),
      'CLOSE',
      trade.outcome == TradeOutcome.win ? _chartMint : _chartCoral,
      above: trade.outcome == TradeOutcome.win,
    );

    for (var i = 0; i <= 2; i++) {
      final candleIndex = (viewStart + (viewCount - 1) * i / 2).round().clamp(
        0,
        candles.length - 1,
      );
      final time = candles[candleIndex].time;
      final x = plot.left + plot.width * i / 2;
      final date = DateTime.fromMillisecondsSinceEpoch(
        time * 1000,
        isUtc: true,
      ).toLocal();
      final label =
          '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      final labelWidth = 80.0;
      final labelX = (x - labelWidth / 2)
          .clamp(plot.left, plot.right - labelWidth)
          .toDouble();
      _drawText(
        canvas,
        label,
        Offset(labelX, plot.bottom + 6),
        color: _chartMuted,
        fontSize: 8,
        maxWidth: labelWidth,
      );
    }
  }

  void _drawPriceLine(
    Canvas canvas,
    Rect plot,
    double Function(double) yFor,
    double price,
    Color color,
    String label, {
    required bool dashed,
  }) {
    final y = yFor(price);
    if (y < plot.top || y > plot.bottom) return;
    final paint = Paint()
      ..color = color.withValues(alpha: .82)
      ..strokeWidth = 1;
    if (dashed) {
      const dash = 5.0;
      var x = plot.left;
      while (x < plot.right) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + dash).clamp(plot.left, plot.right).toDouble(), y),
          paint,
        );
        x += dash * 2;
      }
    } else {
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), paint);
    }
    final tagWidth = label == 'ENTRY' ? 36.0 : 28.0;
    final tagRect = Rect.fromLTWH(
      plot.left + 3,
      (y - 7).clamp(plot.top, plot.bottom - 14).toDouble(),
      tagWidth,
      13,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tagRect, const Radius.circular(3)),
      Paint()..color = _chartBg.withValues(alpha: .9),
    );
    _drawText(
      canvas,
      label,
      Offset(tagRect.left + 3, tagRect.top + 1),
      color: color,
      fontSize: 8,
      maxWidth: tagWidth - 5,
    );
  }

  void _drawTimeMarker(
    Canvas canvas,
    Rect plot,
    double x,
    double candleY,
    String label,
    Color color, {
    required bool above,
  }) {
    if (x < plot.left || x > plot.right) return;
    final markerY = (candleY + (above ? -7 : 7))
        .clamp(plot.top + 4, plot.bottom - 4)
        .toDouble();
    canvas.drawCircle(Offset(x, markerY), 3, Paint()..color = color);
    final width = label == 'CLOSE' ? 36.0 : 35.0;
    final left = (x - width / 2)
        .clamp(plot.left, plot.right - width)
        .toDouble();
    final labelY = (markerY + (above ? -16 : 5))
        .clamp(plot.top + 1, plot.bottom - 13)
        .toDouble();
    final rect = Rect.fromLTWH(left, labelY, width, 12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = _chartBg.withValues(alpha: .9),
    );
    _drawText(
      canvas,
      label,
      Offset(left + 3, labelY + 1),
      color: color,
      fontSize: 8,
      maxWidth: width - 5,
    );
  }

  String _formatPrice(double value) {
    final abs = value.abs();
    final decimals = abs >= 100
        ? 2
        : abs >= 1
        ? 4
        : 5;
    return value.toStringAsFixed(decimals);
  }

  void _drawText(
    Canvas canvas,
    String value,
    Offset offset, {
    required Color color,
    required double fontSize,
    required double maxWidth,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) => true;
}
