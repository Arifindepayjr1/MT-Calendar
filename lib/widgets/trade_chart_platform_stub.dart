import 'package:flutter/material.dart';

import 'trade_chart_platform.dart';

Future<TradeChartPlatform> createTradeChartPlatformImpl({
  required void Function(String message) onMessage,
}) async {
  return TradeChartPlatform(
    view: const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'The advanced chart is not available on this platform.',
          textAlign: TextAlign.center,
        ),
      ),
    ),
    handle: const _NoopChartHandle(),
  );
}

class _NoopChartHandle implements TradeChartPlatformHandle {
  const _NoopChartHandle();

  @override
  void post(String jsonMessage) {}

  @override
  Future<void> dispose() async {}
}
