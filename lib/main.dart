import 'package:flutter/material.dart';
import 'package:trader_log/screens/auth.screen.dart';
import 'package:trader_log/screens/main_navigation.screen.dart';
import 'package:trader_log/services/auth_api_service.dart';
import 'package:trader_log/services/auth_store.dart';
import 'package:trader_log/services/strategy_api_service.dart';
import 'package:trader_log/services/trade_import_store.dart';
import 'package:trader_log/theme/ledger_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authStore = AuthStore();
  final importStore = TradeImportStore();
  await Future.wait([
    authStore.initialize(),
    importStore.initialize(),
  ]);
  runApp(MyApp(
    authStore: authStore,
    importStore: importStore,
    requireAuth: true,
  ));
}

class MyApp extends StatefulWidget {
  final StrategyApiService strategyApi;
  final AuthStore? authStore;
  final TradeImportStore? importStore;
  final bool requireAuth;

  const MyApp({
    super.key,
    this.strategyApi = const StrategyApiService(),
    this.authStore,
    this.importStore,
    this.requireAuth = false,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _guest = false;

  void _enteredApp() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final authStore = widget.authStore ?? AuthStore();
    final showAuth = widget.requireAuth && !authStore.isSignedIn && !_guest;

    return _app(
      home: showAuth
          ? AuthScreen(
              api: const AuthApiService(),
              store: authStore,
              onCompleted: _enteredApp,
              onGuest: () => setState(() => _guest = true),
            )
          : MainNavigationScreen(
              strategyApi: widget.strategyApi,
              authStore: authStore,
              importStore: widget.importStore,
            ),
    );
  }

  Widget _app({required Widget home}) {
    return MaterialApp(
      title: 'TradeLog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: LedgerColors.background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: LedgerColors.mint,
          brightness: Brightness.dark,
        ),
      ),
      home: home,
    );
  }
}
