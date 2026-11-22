import 'package:flutter/material.dart';
import 'package:trader_log/screens/main_navigation.screen.dart';
import 'package:trader_log/services/auth_store.dart';
import 'package:trader_log/services/strategy_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authStore = AuthStore();
  await authStore.initialize();
  runApp(MyApp(authStore: authStore));
}

class MyApp extends StatelessWidget {
  final StrategyApiService strategyApi;
  final AuthStore? authStore;

  const MyApp({
    super.key,
    this.strategyApi = const StrategyApiService(),
    this.authStore,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TradeLog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF101310),
      ),
      home: MainNavigationScreen(
        strategyApi: strategyApi,
        authStore: authStore,
      ),
    );
  }
}
