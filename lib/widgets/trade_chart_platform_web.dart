// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:js_interop';

import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';

import 'trade_chart_platform.dart';

int _nextChartId = 0;

Future<TradeChartPlatform> createTradeChartPlatformImpl({
  required void Function(String message) onMessage,
}) async {
  final viewType = 'traderlog-trade-chart-${_nextChartId++}';
  final iframe = html.IFrameElement()
    ..src = Uri.base.resolve('trade_chart/index.html').toString()
    ..title = 'TraderLog advanced chart'
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.border = 'none'
    ..setAttribute('allow', 'fullscreen');

  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) => iframe,
  );

  void listener(html.Event event) {
    if (event is! html.MessageEvent) return;
    final data = event.data;
    if (data is String && data.startsWith('{')) onMessage(data);
  }

  html.window.addEventListener('message', listener);
  return TradeChartPlatform(
    view: HtmlElementView(viewType: viewType),
    handle: _WebChartHandle(iframe, listener),
  );
}

class _WebChartHandle implements TradeChartPlatformHandle {
  final html.IFrameElement _iframe;
  final void Function(html.Event) _listener;
  bool _disposed = false;

  _WebChartHandle(this._iframe, this._listener);

  @override
  void post(String jsonMessage) {
    if (_disposed) return;
    final command = <String, Object?>{
      'source': 'traderlog-chart-command',
      'message': jsonMessage,
    }.jsify();
    _iframe.contentWindow?.postMessage(command, html.window.location.origin);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    html.window.removeEventListener('message', _listener);
  }
}
