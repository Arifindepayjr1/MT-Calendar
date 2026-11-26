import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trader_log/screens/auth.screen.dart';
import 'package:trader_log/services/auth_api_service.dart';
import 'package:trader_log/services/auth_store.dart';

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

http.Response _session() => _json({
      'accessToken': 'jwt-1',
      'tokenType': 'Bearer',
      'expiresIn': '7d',
      'user': {'id': 'u1', 'email': 'trader@example.com', 'name': 'Trader'},
    });

Finder _field(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

Future<void> _tapKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

void main() {
  testWidgets('log in stores the JWT session from the terminal screen',
      (tester) async {
    final store = AuthStore.inMemory();
    final requests = <http.Request>[];
    final api = AuthApiService(
      baseUrl: 'http://auth.test',
      client: MockClient((request) async {
        requests.add(request);
        return _session();
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(api: api, store: store),
    ));

    expect(find.text('Welcome Back, Trader'), findsOneWidget);
    expect(find.text('AUTHORIZED ONLY'), findsOneWidget);

    await tester.enterText(
        _field('TERMINAL ID / EMAIL'), 'trader@example.com');
    await tester.enterText(_field('MASTER CIPHER'), 'secret123');
    await tester.tap(find.byKey(const ValueKey('login_submit')));
    await tester.pumpAndSettle();

    expect(requests.single.url.toString(), 'http://auth.test/api/auth/login');
    expect(store.token, 'jwt-1');
    expect(store.user?.name, 'Trader');
  });

  testWidgets('create account sends a code, verifies the OTP and launches',
      (tester) async {
    final store = AuthStore.inMemory();
    final requests = <http.Request>[];
    final api = AuthApiService(
      baseUrl: 'http://auth.test',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('auth/request-code')) {
          return _json({
            'email': 'trader@example.com',
            'expiresInSeconds': 600,
            'devCode': '842910',
          });
        }
        return _session();
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(api: api, store: store),
    ));

    await _tapKey(tester, const ValueKey('login_create_account'));
    await tester.pumpAndSettle();

    expect(find.text('Create Trader Account'), findsOneWidget);
    expect(find.text('STEP 1 OF 2: TRADER PROFILE'), findsOneWidget);
    expect(find.text('50% Completed'), findsOneWidget);
    expect(find.byKey(const ValueKey('framework_ICT / SMC')), findsOneWidget);
    expect(find.byKey(const ValueKey('framework_Order Flow (DOM)')),
        findsOneWidget);

    await tester.enterText(_field('TRADER HANDLE'), 'Alex Mercer');
    await tester.enterText(
        _field('BROKER / WORK EMAIL'), 'trader@example.com');
    await tester.enterText(_field('VAULT PASSPHRASE'), 'Str0ng!Pass');
    await _tapKey(tester, const ValueKey('framework_Order Flow (DOM)'));
    await _tapKey(tester, const ValueKey('create_submit'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Verify Code'), findsOneWidget);
    expect(find.text('Institutional Session Token'), findsOneWidget);
    expect(find.text('Resend in 00:46s'), findsOneWidget);
    expect(find.byKey(const ValueKey('otp_dev_code')), findsOneWidget);
    expect(find.text('Local dev code: 842910'), findsOneWidget);

    final requestCode = requests.firstWhere(
      (request) => request.url.path.endsWith('auth/request-code'),
    );
    expect(jsonDecode(requestCode.body), {
      'email': 'trader@example.com',
      'password': 'Str0ng!Pass',
      'name': 'Alex Mercer',
      'framework': 'Order Flow (DOM)',
    });

    for (final digit in '842910'.split('')) {
      await _tapKey(tester, ValueKey('otp_key_$digit'));
    }
    await _tapKey(tester, const ValueKey('otp_submit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final verify = requests.lastWhere(
      (request) => request.url.path.endsWith('auth/verify-code'),
    );
    expect(jsonDecode(verify.body), {
      'email': 'trader@example.com',
      'code': '842910',
    });
    expect(store.token, 'jwt-1');
  });

  testWidgets('log in validates empty credentials without a request',
      (tester) async {
    final requests = <http.Request>[];
    final api = AuthApiService(
      baseUrl: 'http://auth.test',
      client: MockClient((request) async {
        requests.add(request);
        return _session();
      }),
    );

    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(api: api, store: AuthStore.inMemory()),
    ));
    await tester.tap(find.byKey(const ValueKey('login_submit')));
    await tester.pump();

    expect(find.text('Enter your terminal ID and master cipher.'),
        findsOneWidget);
    expect(requests, isEmpty);
  });
}
