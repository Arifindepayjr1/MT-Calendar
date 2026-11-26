import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trader_log/main.dart';
import 'package:trader_log/model/auth.model.dart';
import 'package:trader_log/services/auth_store.dart';

void main() {
  testWidgets('root navigation opens the Calendar section', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    for (final label in [
      'Home',
      'Calendar',
      'Strategies',
      'Statistics',
      'Settings',
    ]) {
      expect(
        find.text(label),
        findsWidgets,
        reason: '$label tab should be visible',
      );
    }

    await tester.tap(find.text('Calendar').first);
    await tester.pumpAndSettle();

    expect(find.text('Track your trading performance'), findsOneWidget);
  });

  testWidgets('auth gate opens Log In before the main navigation',
      (tester) async {
    final auth = AuthStore.inMemory();
    await tester.pumpWidget(MyApp(
      authStore: auth,
      requireAuth: true,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Log In'), findsOneWidget);
    expect(find.text('Welcome Back, Trader'), findsOneWidget);
    expect(find.text('Sign In to TradeLog →'), findsOneWidget);
    expect(find.text('Calendar'), findsNothing,
        reason: 'home tabs must not appear before authentication');
    expect(find.text('Continue as guest'), findsNothing,
        reason: 'auth must not offer a guest bypass');
    expect(find.byKey(const ValueKey('auth_back_Log In')), findsNothing,
        reason: 'root login step must not offer a back route to home');
  });

  testWidgets('saved session skips auth and opens the main navigation',
      (tester) async {
    final auth = AuthStore.inMemory();
    await auth.saveSession(
      const AuthSession(
        accessToken: 'jwt-1',
        tokenType: 'Bearer',
        expiresIn: '7d',
        user: AuthUser(id: 'u1', email: 'trader@example.com', name: 'Trader'),
      ),
    );

    await tester.pumpWidget(MyApp(
      authStore: auth,
      requireAuth: true,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome Back, Trader'), findsNothing);
    expect(find.text('Calendar'), findsWidgets);
  });
}
