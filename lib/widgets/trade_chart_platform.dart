import 'package:flutter/widgets.dart';

import 'trade_chart_platform_stub.dart'
    if (dart.library.io) 'trade_chart_platform_io.dart'
    if (dart.library.html) 'trade_chart_platform_web.dart';

/// Handle used by the chart widget to send commands to the chart JavaScript.
abstract class TradeChartPlatformHandle {
  void post(String jsonMessage);
  Future<void> dispose();
}

class TradeChartPlatform {
  final Widget view;
  final TradeChartPlatformHandle handle;

  const TradeChartPlatform({required this.view, required this.handle});
}

Future<TradeChartPlatform> createTradeChartPlatform({
  required void Function(String message) onMessage,
}) {
  return createTradeChartPlatformImpl(onMessage: onMessage);
}
