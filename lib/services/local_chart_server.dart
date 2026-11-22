import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

/// Serves the bundled TradeCanvas files over loopback HTTP.
///
/// The chart is an ES module (`<script type="module" src="./chart.js">`), so
/// loading it from a `file://` WebView URL is blocked by CORS on Android and
/// Windows. A tiny same-origin loopback server gives every native platform a
/// normal http origin without needing any network access.
class LocalChartServer {
  LocalChartServer._();

  static final LocalChartServer instance = LocalChartServer._();

  static const _assetPrefix = 'assets/trade_chart/';

  HttpServer? _server;
  Future<String>? _starting;
  final Map<String, Uint8List> _files = <String, Uint8List>{};

  /// Returns the base URL (for example `http://127.0.0.1:49152`) of the server.
  Future<String> start() {
    final server = _server;
    if (server != null) {
      return Future<String>.value('http://127.0.0.1:${server.port}');
    }
    return _starting ??= _start();
  }

  Future<String> _start() async {
    try {
      final manifest = jsonDecode(
        await rootBundle.loadString('AssetManifest.json'),
      ) as Map<String, dynamic>;
      for (final key in manifest.keys) {
        if (!key.startsWith(_assetPrefix)) continue;
        final relative = key.substring(_assetPrefix.length);
        final data = await rootBundle.load(key);
        _files[relative] = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
      }
      if (!_files.containsKey('index.html')) {
        throw StateError(
          'Trade chart assets are missing. Add assets/trade_chart to pubspec.yaml.',
        );
      }
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      server.listen(_handle);
      return 'http://127.0.0.1:${server.port}';
    } catch (_) {
      _starting = null;
      rethrow;
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = responseFor(request);
    await response.close();
  }

  HttpResponse responseFor(HttpRequest request) {
    var path = Uri.decodeComponent(request.uri.path);
    if (path.isEmpty || path == '/') path = '/index.html';
    while (path.startsWith('/')) {
      path = path.substring(1);
    }
    final data = _files[path];
    final response = request.response;
    if (data == null) {
      response.statusCode = HttpStatus.notFound;
      response.headers.contentType = ContentType.text;
      response.write('Not found: $path');
      return response;
    }
    response.statusCode = HttpStatus.ok;
    final mime = _mimeFor(path);
    final parts = mime.split('/');
    response.headers.contentType = ContentType(
      parts.first,
      parts.last,
      charset: _isText(path) ? 'utf-8' : null,
    );
    response.headers.set('Cache-Control', 'no-cache');
    response.add(data);
    return response;
  }

  static String _mimeFor(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
    if (lower.endsWith('.js') || lower.endsWith('.mjs')) {
      return 'text/javascript';
    }
    if (lower.endsWith('.css')) return 'text/css';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.woff2')) return 'font/woff2';
    if (lower.endsWith('.woff')) return 'font/woff';
    if (lower.endsWith('.map')) return 'application/json';
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }

  static bool _isText(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.html') ||
        lower.endsWith('.htm') ||
        lower.endsWith('.js') ||
        lower.endsWith('.mjs') ||
        lower.endsWith('.css') ||
        lower.endsWith('.json') ||
        lower.endsWith('.svg') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.map');
  }
}
