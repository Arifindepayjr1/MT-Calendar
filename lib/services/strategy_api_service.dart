import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:trader_log/model/strategy_draft.model.dart';
import 'package:trader_log/model/strategy_detail.model.dart';
import 'package:trader_log/model/strategy_playbook.model.dart';

class StrategyApiException implements Exception {
  final String message;
  const StrategyApiException(this.message);

  @override
  String toString() => message;
}

/// Client for the backend-owned strategy catalogue, rulebooks and user drafts.
///
/// On web it first tries the same-origin Pages Function path, then the local
/// NestJS backend on port 3000. Passing [baseUrl] overrides both candidates.
class StrategyApiService {
  final http.Client? client;
  final String? baseUrl;

  /// Returns the current JWT, if the user is signed in. Called per request so
  /// a newly saved token is used without recreating the widget tree.
  final String? Function()? tokenProvider;

  const StrategyApiService({this.client, this.baseUrl, this.tokenProvider});

  /// Copies this client and attaches a token provider, preserving injected
  /// clients and base URLs used by tests.
  StrategyApiService withToken(String? Function() provider) {
    return StrategyApiService(
      client: client,
      baseUrl: baseUrl,
      tokenProvider: provider,
    );
  }

  /// True only when a JWT is currently available. The Strategies screen uses
  /// this to skip the guarded drafts endpoint for signed-out users.
  bool get hasToken => (tokenProvider?.call() ?? '').isNotEmpty;

  Map<String, String> _headers({bool jsonBody = false}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (jsonBody) 'Content-Type': 'application/json',
    };
    final token = tokenProvider?.call();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<StrategyOverview> fetchOverview() async {
    final json = await _getJson('strategies');
    return StrategyOverview.fromJson(json);
  }

  Future<StrategyDetail> fetchDetail(String id) async {
    final json = await _getJson('strategies/${Uri.encodeComponent(id)}');
    return StrategyDetail.fromJson(json);
  }

  /// Drafts are always fetched with the current JWT. NestJS scopes the rows by
  /// the authenticated user, so another account's drafts cannot be returned.
  Future<List<StrategyDraft>> fetchDrafts() async {
    final decoded = await _getJsonList('strategies/drafts');
    return decoded
        .whereType<Map>()
        .map(
          (item) => StrategyDraft.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> createDraft(Map<String, dynamic> payload) =>
      _postJson('strategies', payload);

  List<Uri> _candidates(String path) {
    if (baseUrl != null) {
      return [Uri.parse('${baseUrl!.replaceAll(RegExp(r'/+$'), '')}/api/$path')];
    }
    return [
      if (kIsWeb) Uri.base.resolve('/api/$path'),
      Uri.parse('http://127.0.0.1:3000/api/$path'),
    ];
  }

  Future<Object> _getDecoded(String path) async {
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    Object? lastError;
    try {
      for (final uri in _candidates(path)) {
        try {
          final response = await httpClient.get(
            uri,
            headers: _headers(),
          );
          final decoded = _decodeIfJson(response);
          if (decoded != null) return decoded;
          lastError = StrategyApiException(
            'Unexpected response from $uri (${response.statusCode}).',
          );
        } catch (error) {
          lastError = error;
        }
      }
    } finally {
      if (ownsClient) httpClient.close();
    }
    throw StrategyApiException(
      'Strategy API is unavailable. Start the backend on port 3000 or deploy /api/strategies. '
      '${lastError ?? ''}',
    );
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final decoded = await _getDecoded(path);
    if (decoded is Map<String, dynamic>) return decoded;
    throw StrategyApiException('Unexpected strategy response from $path.');
  }

  Future<List<dynamic>> _getJsonList(String path) async {
    final decoded = await _getDecoded(path);
    if (decoded is List<dynamic>) return decoded;
    throw StrategyApiException('Unexpected strategy list from $path.');
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    Object? lastError;
    final body = jsonEncode(payload);
    try {
      for (final uri in _candidates(path)) {
        try {
          final response = await httpClient.post(
            uri,
            headers: _headers(jsonBody: true),
            body: body,
          );
          final decoded = _decodeIfJson(response);
          if (decoded is Map<String, dynamic>) return decoded;
          lastError = StrategyApiException(
            'Unexpected response from $uri (${response.statusCode}).',
          );
        } catch (error) {
          lastError = error;
        }
      }
    } finally {
      if (ownsClient) httpClient.close();
    }
    throw StrategyApiException(
      'Strategy API rejected the draft. Start the backend on port 3000 or deploy /api/strategies. '
      '${lastError ?? ''}',
    );
  }

  Object? _decodeIfJson(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) return null;
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('application/json')) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is Map<String, dynamic> || decoded is List<dynamic>) {
      return decoded;
    }
    return null;
  }
}
