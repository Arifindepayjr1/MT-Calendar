import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trader_log/screens/auth.screen.dart';
import 'package:trader_log/services/auth_api_service.dart';
import 'package:trader_log/services/auth_store.dart';

http.Response _session() => http.Response(
      jsonEncode({
        'accessToken': 'jwt-1',
        'tokenType': 'Bearer',
        'expiresIn': '7d',
        'user': {'id': 'u1', 'email': 'trader@example.com', 'name': 'Trader'},
      }),
      200,
      headers: const {'content-type': 'application/json'},
    );

Finder _field(String label) {
  return find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  );
}

void main() {
  testWidgets('signs in and stores the JWT session', (tester) async {
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

    await tester.enterText(_field('Email'), 'trader@example.com');
    await tester.enterText(_field('Password'), 'secret123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(requests.single.url.toString(), 'http://auth.test/api/auth/login');
    expect(store.token, 'jwt-1');
    expect(store.user?.name, 'Trader');
  });

  testWidgets('sign up mode adds the name field and validates empty input',
      (tester) async {
    final store = AuthStore.inMemory();
    final api = AuthApiService(
      baseUrl: 'http://auth.test',
      client: MockClient((_) async => _session()),
    );

    await tester.pumpWidget(MaterialApp(
      home: AuthScreen(api: api, store: store),
    ));

    await tester.tap(find.widgetWithText(GestureDetector, 'Sign up'));
    await tester.pump();
    expect(_field('Name'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pump();
    expect(find.text('Enter email, password and name.'), findsOneWidget);
    expect(store.isSignedIn, isFalse);
  });
}
