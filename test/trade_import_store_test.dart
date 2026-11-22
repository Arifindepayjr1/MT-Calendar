import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trader_log/model/auth.model.dart';
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/services/auth_store.dart';
import 'package:trader_log/services/trade_import_store.dart';

Trade _trade() => Trade(
      id: 'trd_1',
      ticket: '482910',
      positionId: '482910',
      symbol: 'XAUUSD',
      type: TradeType.buy,
      volume: 0.1,
      openPrice: 2310.5,
      closePrice: 2320.5,
      stoploss: 2305.0,
      takeProfit: 2325.0,
      openTime: DateTime.utc(2026, 9, 1, 8, 20),
      closeTime: DateTime.utc(2026, 9, 1, 9, 20),
      profit: 100,
      commission: -2,
      swap: 0,
      fee: 0,
      netProfit: 98,
      closeReason: CloseReason.takeProfit,
      createdAt: DateTime.utc(2026, 9, 2),
      accountId: 'acc_001',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  test('imported report survives a store restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = TradeImportStore(preferences: prefs);
    await store.initialize();
    expect(store.hasImport, isFalse);

    await store.save(
      ImportedAccount(
        trades: [_trade()],
        accountName: 'Alex',
        brokerAndNumber: 'IC Markets (MT5 #482910)',
        currency: 'USD',
        syncSubtitle: 'Imported report.html · 1 positions (USD)',
        initialDeposit: 5000,
        finalBalance: 5098,
      ),
    );

    final restarted = TradeImportStore(preferences: prefs);
    await restarted.initialize();

    expect(restarted.hasImport, isTrue);
    expect(restarted.data!.trades.single.ticket, '482910');
    expect(restarted.data!.trades.single.netProfit, 98);
    expect(restarted.data!.currency, 'USD');
    expect(restarted.data!.finalBalance, 5098);
    expect(restarted.data!.syncSubtitle, contains('report.html'));
  });

  test('signing in and signing out never clears the imported report',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final imports = TradeImportStore(preferences: prefs);
    await imports.initialize();
    await imports.save(
      ImportedAccount(
        trades: [_trade()],
        accountName: 'Alex',
        brokerAndNumber: 'IC Markets (MT5 #482910)',
        currency: 'USD',
        initialDeposit: 5000,
      ),
    );

    final auth = AuthStore(preferences: prefs);
    await auth.initialize();
    await auth.saveSession(
      const AuthSession(
        accessToken: 'jwt-1',
        tokenType: 'Bearer',
        expiresIn: '7d',
        user: AuthUser(id: 'u1', email: 'trader@example.com', name: 'Trader'),
      ),
    );
    expect(imports.hasImport, isTrue);

    await auth.clear();
    expect(auth.isSignedIn, isFalse);
    expect(imports.hasImport, isTrue);
    expect(imports.data!.trades.single.symbol, 'XAUUSD');
  });

  test('clear removes the persisted import', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = TradeImportStore(preferences: prefs);
    await store.save(
      ImportedAccount(
        trades: [_trade()],
        accountName: 'Alex',
        brokerAndNumber: 'MT5',
        currency: 'USD',
        initialDeposit: 0,
      ),
    );
    await store.clear();

    final restarted = TradeImportStore(preferences: prefs);
    await restarted.initialize();
    expect(restarted.hasImport, isFalse);
  });
}
