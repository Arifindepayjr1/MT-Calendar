import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trader_log/services/auth_api_service.dart';

const _baseUrl = 'http://auth.test';

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

const Map<String, dynamic> _session = {
  'accessToken': 'jwt-token-1',
  'tokenType': 'Bearer',
  'expiresIn': '7d',
  'user': {'id': 'user-1', 'email': 'trader@example.com', 'name': 'Trader'},
};

void main() {
  test('signUp posts credentials and decodes the session', () async {
    final requests = <http.Request>[];
    final api = AuthApiService(
      baseUrl: _baseUrl,
      client: MockClient((request) async {
        requests.add(request);
        return _json(_session, status: 201);
      }),
    );

    final session = await api.signUp(
      email: 'trader@example.com',
      password: 'secret123',
      name: 'Trader',
    );

    expect(requests.single.method, 'POST');
    expect(requests.single.url.toString(), '$_baseUrl/api/auth/signup');
    expect(jsonDecode(requests.single.body), {
      'email': 'trader@example.com',
      'password': 'secret123',
      'name': 'Trader',
    });
    expect(session.accessToken, 'jwt-token-1');
    expect(session.user.name, 'Trader');
  });

  test('signIn posts email and password', () async {
    final requests = <http.Request>[];
    final api = AuthApiService(
      baseUrl: _baseUrl,
      client: MockClient((request) async {
        requests.add(request);
        return _json(_session);
      }),
    );

    await api.signIn(email: 'trader@example.com', password: 'secret123');

    expect(requests.single.url.toString(), '$_baseUrl/api/auth/login');
    expect(jsonDecode(requests.single.body), {
      'email': 'trader@example.com',
      'password': 'secret123',
    });
  });

  test('me sends the Bearer token and decodes the user', () async {
    final requests = <http.Request>[];
    final api = AuthApiService(
      baseUrl: _baseUrl,
      client: MockClient((request) async {
        requests.add(request);
        return _json(_session['user']);
      }),
    );

    final user = await api.me('jwt-token-1');

    expect(requests.single.url.toString(), '$_baseUrl/api/auth/me');
    expect(requests.single.headers['authorization'], 'Bearer jwt-token-1');
    expect(user.email, 'trader@example.com');
  });

  test('surfaces backend validation errors', () async {
    final api = AuthApiService(
      baseUrl: _baseUrl,
      client: MockClient(
        (_) async => _json({'error': 'Invalid email or password.'}, status: 401),
      ),
    );

    await expectLater(
      api.signIn(email: 'trader@example.com', password: 'wrong'),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.message,
          'message',
          'Invalid email or password.',
        ),
      ),
    );
  });

  test('throws a clear error when the API is not reachable', () async {
    final api = AuthApiService(
      baseUrl: _baseUrl,
      client: MockClient(
        (_) async => http.Response('<html>offline</html>', 502,
            headers: const {'content-type': 'text/html'}),
      ),
    );

    await expectLater(
      api.signIn(email: 'trader@example.com', password: 'secret123'),
      throwsA(
        isA<AuthApiException>().having(
          (error) => error.message,
          'message',
          contains('Auth API is unavailable'),
        ),
      ),
    );
  });
}
