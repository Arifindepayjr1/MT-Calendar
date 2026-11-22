import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trader_log/services/strategy_api_service.dart';

import 'support/strategy_fixtures.dart';

const _baseUrl = 'http://strategy.test';

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: const {'content-type': 'application/json'},
    );

void main() {
  test('fetchOverview decodes the backend catalogue', () async {
    final requests = <http.Request>[];
    final api = StrategyApiService(
      baseUrl: _baseUrl,
      client: MockClient((request) async {
        requests.add(request);
        return _json(strategyOverviewJson());
      }),
    );

    final overview = await api.fetchOverview();

    expect(requests.single.method, 'GET');
    expect(requests.single.url.toString(), '$_baseUrl/api/strategies');
    expect(overview.playbooks, hasLength(4));
    expect(overview.netReturn, 4820.5);
  });

  test('fetchDetail requests an encoded strategy id', () async {
    final requests = <http.Request>[];
    final api = StrategyApiService(
      baseUrl: _baseUrl,
      client: MockClient((request) async {
        requests.add(request);
        return _json(strategyDetailJson());
      }),
    );

    final detail = await api.fetchDetail('pb_silver_bullet');

    expect(requests.single.url.toString(),
        '$_baseUrl/api/strategies/pb_silver_bullet');
    expect(detail.statusLabel, 'Live Rulebook Active');
    expect(detail.trades, hasLength(6));
  });

  test('createDraft posts JSON and decodes the created draft', () async {
    final requests = <http.Request>[];
    final api = StrategyApiService(
      baseUrl: _baseUrl,
      client: MockClient((request) async {
        requests.add(request);
        return _json({
          'id': 'draft_7',
          'name': 'London Sweep',
          'savedAt': '2026-01-01T00:00:00.000Z',
          'draftCount': 7,
        });
      }),
    );

    final result = await api.createDraft({'name': 'London Sweep'});

    expect(requests.single.method, 'POST');
    expect(requests.single.headers['content-type'], 'application/json');
    expect(jsonDecode(requests.single.body), {'name': 'London Sweep'});
    expect(result['id'], 'draft_7');
  });

  test('attaches the current JWT when a token provider is set', () async {
    final requests = <http.Request>[];
    final api = StrategyApiService(
      baseUrl: _baseUrl,
      tokenProvider: () => 'jwt-from-auth-store',
      client: MockClient((request) async {
        requests.add(request);
        return _json(strategyOverviewJson());
      }),
    );

    await api.fetchOverview();
    await api.createDraft({'name': 'London Sweep'});

    expect(
      requests.map((request) => request.headers['authorization']).toList(),
      ['Bearer jwt-from-auth-store', 'Bearer jwt-from-auth-store'],
    );
  });

  test('throws a clear exception when the endpoint is not JSON', () async {
    final api = StrategyApiService(
      baseUrl: _baseUrl,
      client: MockClient(
        (_) async => http.Response('<html>not the api</html>', 200,
            headers: const {'content-type': 'text/html'}),
      ),
    );

    await expectLater(
      api.fetchOverview(),
      throwsA(
        isA<StrategyApiException>().having(
          (error) => error.message,
          'message',
          contains('Strategy API is unavailable'),
        ),
      ),
    );
  });
}
