import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:trader_log/services/local_chart_server.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as win;

import 'trade_chart_platform.dart';

Future<TradeChartPlatform> createTradeChartPlatformImpl({
  required void Function(String message) onMessage,
}) async {
  late Uri url;
  try {
    final base = await LocalChartServer.instance.start();
    url = Uri.parse('$base/index.html');
  } catch (_) {
    return _unavailable('The chart assets could not be prepared.');
  }

  if (defaultTargetPlatform == TargetPlatform.windows) {
    return _createWindows(url, onMessage);
  }
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS) {
    return _createMobile(url, onMessage);
  }
  return _unavailable('The advanced chart is not available on this platform.');
}

Future<TradeChartPlatform> _createMobile(
  Uri url,
  void Function(String message) onMessage,
) async {
  try {
    final controller = WebViewController();
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setBackgroundColor(const Color(0xFF090D0B));
    await controller.addJavaScriptChannel(
      'TraderLogChartBridge',
      onMessageReceived: (JavaScriptMessage message) =>
          onMessage(message.message),
    );
    await controller.loadRequest(url);
    return TradeChartPlatform(
      view: WebViewWidget(controller: controller),
      handle: _MobileChartHandle(controller),
    );
  } catch (error) {
    return _unavailable('The chart could not start: $error');
  }
}

Future<TradeChartPlatform> _createWindows(
  Uri url,
  void Function(String message) onMessage,
) async {
  win.WebviewController? controller;
  StreamSubscription<dynamic>? subscription;
  try {
    controller = win.WebviewController();
    await controller.initialize();
    // The chart script looks for this bridge before falling back to
    // postMessage. Map it onto WebView2's host message channel.
    await controller.addScriptToExecuteOnDocumentCreated(
      'window.TraderLogChartBridge = { postMessage: function (message) { '
      'window.chrome.webview.postMessage(message); } };',
    );
    await controller.setBackgroundColor(const Color(0xFF090D0B));
    subscription = controller.webMessage.listen((message) {
      onMessage(message is String ? message : jsonEncode(message));
    });
    await controller.loadUrl(url.toString());
    return TradeChartPlatform(
      view: win.Webview(controller),
      handle: _WindowsChartHandle(controller, subscription),
    );
  } catch (error) {
    await subscription?.cancel();
    try {
      await controller?.dispose();
    } catch (_) {}
    return _unavailable('The chart could not start: $error');
  }
}

TradeChartPlatform _unavailable(String message) {
  return TradeChartPlatform(
    view: Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF858D86), fontSize: 11),
        ),
      ),
    ),
    handle: const _NoopChartHandle(),
  );
}

String _commandScript(String jsonMessage) =>
    'window.TraderLogChartApi?.dispatch($jsonMessage);';

class _MobileChartHandle implements TradeChartPlatformHandle {
  final WebViewController _controller;
  const _MobileChartHandle(this._controller);

  @override
  void post(String jsonMessage) {
    _controller.runJavaScript(_commandScript(jsonMessage));
  }

  @override
  Future<void> dispose() async {}
}

class _WindowsChartHandle implements TradeChartPlatformHandle {
  final win.WebviewController _controller;
  final StreamSubscription<dynamic> _subscription;
  const _WindowsChartHandle(this._controller, this._subscription);

  @override
  void post(String jsonMessage) {
    _controller.executeScript(_commandScript(jsonMessage));
  }

  @override
  Future<void> dispose() async {
    await _subscription.cancel();
    await _controller.dispose();
  }
}

class _NoopChartHandle implements TradeChartPlatformHandle {
  const _NoopChartHandle();

  @override
  void post(String jsonMessage) {}

  @override
  Future<void> dispose() async {}
}
