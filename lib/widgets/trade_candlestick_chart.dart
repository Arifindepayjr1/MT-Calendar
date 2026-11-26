import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/services/market_candle.dart';
import 'package:trader_log/services/mt5_candle_service.dart';
import 'package:trader_log/services/trade_chart_markers.dart';

import 'trade_chart_webview.dart';

const _chartBg = Color(0xFF090D0B);
const _chartMint = Color(0xFFB7F7C4);
const _chartCoral = Color(0xFFFF7C7C);
const _chartManual = Color(0xFFF3B65B);
const _chartMuted = Color(0xFF858D86);
const _chartBorder = Color(0xFF303832);
const _chartInk = Color(0xFFE8ECE8);

Color _exitColorFor(CloseReason reason) => switch (reason) {
      CloseReason.takeProfit => _chartMint,
      CloseReason.stopLoss || CloseReason.stopOut => _chartCoral,
      CloseReason.manual => _chartManual,
      CloseReason.other || CloseReason.unknown => _chartInk,
    };

/// A plain MT5 broker-session chart. Opening a trade fetches candles for that
/// trade's exact broker symbol and UTC execution date, then frames the session.
/// There are no drawing tools, saved annotation layers or chart controls.
class TradeCandlestickChart extends StatefulWidget {
  final Trade trade;
  final List<String> strategyNames;

  /// Injectable only for tests that verify the real MT5 request path.
  final http.Client? client;

  const TradeCandlestickChart({
    super.key,
    required this.trade,
    required this.strategyNames,
    this.client,
  });

  @override
  State<TradeCandlestickChart> createState() => _TradeCandlestickChartState();
}

class _TradeCandlestickChartState extends State<TradeCandlestickChart> {
  late Future<MarketCandleSeries> _series;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _series = TradeCandleService(client: widget.client).loadForTrade(
        widget.trade,
        date: widget.trade.openTime.toUtc(),
      );
    });
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
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 330,
          width: double.infinity,
          child: FutureBuilder<MarketCandleSeries>(
            future: _series,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _ChartMessage(
                  icon: Icons.candlestick_chart_rounded,
                  message: 'Loading MT5 broker session…',
                  loading: true,
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                final error = snapshot.error;
                final message = error is Mt5CandleException
                    ? error.message
                    : error is CandleDataException
                        ? error.message
                        : 'MT5 broker session could not be loaded.';
                return _ChartMessage(
                  icon: Icons.show_chart_rounded,
                  message: 'No MT5 chart data: $message',
                  retry: _load,
                );
              }
              final series = snapshot.requireData;
              if (!series.isMt5) {
                return _ChartMessage(
                  icon: Icons.show_chart_rounded,
                  message: 'No MT5 chart data: the backend did not confirm an '
                      'MT5 source. No alternative feed will be substituted.',
                  retry: _load,
                );
              }
              if (series.candles.isEmpty) {
                final reason = series.sessionReason ?? 'no broker history';
                return _ChartMessage(
                  icon: Icons.candlestick_chart_rounded,
                  message: 'MT5 has no candles for this broker session '
                      '(${series.broker ?? 'unknown broker'} / ${series.ticker}): '
                      '$reason.',
                  retry: _load,
                );
              }
              return Stack(
                children: [
                  Positioned.fill(
                    child: TradeChartWebView(
                      trade: widget.trade,
                      series: series,
                      sessionDate: widget.trade.openTime.toUtc(),
                      client: widget.client,
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 6,
                    child: IgnorePointer(
                      child: _DataSourceBadge(series: series),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          const _ChartLegend(color: _chartInk, label: 'BUY / SELL entry'),
          _ChartLegend(
            color: _exitColorFor(widget.trade.closeReason),
            label: TradeChartMarkers.exitLabel(widget.trade.closeReason),
          ),
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

/// Visible proof of the real feed. Rendered only when the backend confirmed
/// `source: "mt5"` and supplied the connected broker's company name.
class _DataSourceBadge extends StatelessWidget {
  final MarketCandleSeries series;

  const _DataSourceBadge({required this.series});

  @override
  Widget build(BuildContext context) {
    if (!series.isMt5 || series.broker == null || series.broker!.isEmpty) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _chartBg.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: _chartBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Text(
          'Data Source: MT5 | Broker: ${series.broker} | Symbol: ${series.ticker}',
          style: const TextStyle(color: _chartMint, fontSize: 9),
        ),
      ),
    );
  }
}
