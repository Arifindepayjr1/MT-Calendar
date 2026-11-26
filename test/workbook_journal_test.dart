import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trader_log/services/workbook_html_render.dart';
import 'package:trader_log/services/workbook_journal_compute.dart';
import 'package:trader_log/services/workbook_journal_model.dart';
import 'package:trader_log/services/workbook_journal_parser.dart';

WorkbookSettings get _settings => const WorkbookSettings(
      startCapital: 1000,
      currency: 'USC',
      contractSize: 1,
      monthlyTarget: 1000,
      dailyLossLimit: 300,
      maxTradesPerDay: 5,
      calendarYear: 2026,
      calendarMonth: 11,
      dashboardYear: 2026,
    );

WorkbookTrade _trade({
  required int day,
  required String direction,
  required double entry,
  double? sl,
  required double tp,
  required double exit,
  double lots = 0.1,
}) {
  return WorkbookTrade(
    date: DateTime(2026, 11, day),
    symbol: 'XAUUSDc',
    direction: direction == 'Buy'
        ? WorkbookDirection.buy
        : WorkbookDirection.sell,
    lots: lots,
    entry: entry,
    stopLoss: sl,
    takeProfit: tp,
    exit: exit,
  );
}

WorkbookJournal _fixtureJournal() {
  final trades = <WorkbookTrade>[
    _trade(day: 16, direction: 'Buy', entry: 3846.088, sl: 3832.674, tp: 3866.086, exit: 3866.086),
    _trade(day: 16, direction: 'Buy', entry: 3863.958, sl: 3849.956, tp: 3884.009, exit: 3884.009),
    _trade(day: 16, direction: 'Buy', entry: 3859.711, sl: 3849.414, tp: 3889.762, exit: 3849.414),
    _trade(day: 16, direction: 'Buy', entry: 3847.135, sl: 3847.562, tp: 3879.56, exit: 3847.562),
    _trade(day: 17, direction: 'Sell', entry: 3885.517, sl: null, tp: 3885.013, exit: 3885.013),
    _trade(day: 17, direction: 'Buy', entry: 3866.777, sl: 3858.133, tp: 3886.788, exit: 3860.482),
    _trade(day: 17, direction: 'Buy', entry: 3861.691, sl: 3849.599, tp: 3897.75, exit: 3849.599),
    _trade(day: 17, direction: 'Sell', entry: 3863.58, sl: 3874.825, tp: 3843.551, exit: 3874.825),
    _trade(day: 17, direction: 'Sell', entry: 3873.634, sl: 3886.299, tp: 3860.891, exit: 3886.299),
    _trade(day: 17, direction: 'Sell', entry: 3887.637, sl: 3900.431, tp: 3867.59, exit: 3869.996),
    _trade(day: 17, direction: 'Buy', entry: 3862.753, sl: 3850.748, tp: 3872.804, exit: 3850.748),
    _trade(day: 18, direction: 'Sell', entry: 3780.412, sl: 3791.71, tp: 3759.885, exit: 3759.885),
    _trade(day: 18, direction: 'Sell', entry: 3786.188, sl: 3798.198, tp: 3756.021, exit: 3780.233),
    _trade(day: 18, direction: 'Sell', entry: 3787.58, sl: 3797.378, tp: 3767.517, exit: 3767.517),
    _trade(day: 18, direction: 'Buy', entry: 3754.217, sl: 3743.112, tp: 3784.263, exit: 3743.112),
    _trade(day: 19, direction: 'Buy', entry: 3732.484, sl: 3721.379, tp: 3754.494, exit: 3721.379),
    _trade(day: 19, direction: 'Sell', entry: 3734.693, sl: 3755.163, tp: 3732.569, exit: 3732.569),
    _trade(day: 19, direction: 'Sell', entry: 3744.275, sl: 3755.51, tp: 3722.233, exit: 3722.233),
    _trade(day: 20, direction: 'Buy', entry: 3575.326, sl: 3564.221, tp: 3585.655, exit: 3564.221, lots: 0.2),
  ];

  return WorkbookJournal(
    settings: _settings,
    strategies: const [],
    sessions: const [],
    trades: trades,
    cashFlows: [
      WorkbookCashFlow(
        date: DateTime(2026, 11, 19),
        type: WorkbookCashFlowType.withdrawal,
        amount: 1425,
      ),
      WorkbookCashFlow(
        date: DateTime(2026, 11, 19),
        type: WorkbookCashFlowType.deposit,
        amount: 1400,
      ),
      WorkbookCashFlow(
        date: DateTime(2026, 11, 20),
        type: WorkbookCashFlowType.withdrawal,
        amount: 1178,
      ),
      WorkbookCashFlow(
        date: DateTime(2026, 11, 20),
        type: WorkbookCashFlowType.deposit,
        amount: 1000,
      ),
    ],
  );
}

void main() {
  test('parseExnessReport extracts trades and cash flows', () {
    final html = '''
<table>
<tr><th>Open time</th><th>Ticket</th><th>Symbol</th><th>Type</th><th>Volume</th><th>Open price</th><th>SL</th><th>TP</th><th>Profit</th><th>Comment</th><th>Close price</th><th>Commission</th><th>Balance</th><th>Extra</th></tr>
<tr><td>2026.11.16 10:00:00</td><td>123</td><td>XAUUSDc</td><td>buy</td><td>0.1 / 0.1</td><td>3846.088</td><td>3832.674</td><td>3866.086</td><td>199.98</td><td>[tp]</td><td>3866.086</td><td>0</td><td>1199.98</td><td></td></tr>
<tr><td>2026.11.19 10:00:00</td><td></td><td></td><td>balance</td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td>1 000.00</td><td></td></tr>
<tr><td>2026.11.19 11:00:00</td><td></td><td></td><td>balance</td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td></td><td>-1 425.00</td><td></td></tr>
</table>''';

    final parsed = parseExnessReport(html);
    expect(parsed.trades, hasLength(1));
    expect(parsed.trades.single.symbol, 'XAUUSDc');
    expect(parsed.trades.single.lots, 0.1);
    expect(parsed.trades.single.notes, 'Position #123');
    expect(parsed.cashFlows, hasLength(1));
    expect(parsed.cashFlows.single.type, WorkbookCashFlowType.withdrawal);
    expect(parsed.cashFlows.single.amount, 1425);
  });

  test('compute reproduces the workbook fixture', () {
    final result = computeWorkbook(_fixtureJournal());

    expect(result.netPnl, closeTo(203.13, 0.02));
    expect(result.accountBalance, closeTo(1000.13, 0.02));
    expect(result.totalCashFlow, closeTo(-203.0, 0.001));
    expect(result.closedTrades, 19);
    expect(result.wins, 10);
    expect(result.losses, 9);
    expect(result.winRate, closeTo(10 / 19, 0.001));
    expect(result.profitFactor, closeTo(1.1863, 0.01));
    expect(result.expectancy, closeTo(10.69, 0.02));
    expect(result.maxDrawdown, closeTo(516.63, 0.02));
    expect(result.avgResultRr, closeTo(0.17, 0.02));
    expect(result.tradingDays, 5);
    expect(result.avgTradesPerDay, closeTo(3.8, 0.01));
    expect(result.daysOverLossLimit, 1);
    expect(result.daysOverTradeLimit, 1);
    expect(result.longestWinStreak, 3);
    expect(result.longestLossStreak, 4);
    expect(result.currentStreak, '1 L');
    expect(result.monthPnl, closeTo(203.13, 0.02));
    expect(result.monthlyGoal, closeTo(0.20313, 0.001));

    expect(result.rows[4].outcome, WorkbookOutcome.win);
    expect(result.rows[4].risk, isNull);
    expect(result.rows[4].resultRr, isNull);
    expect(result.rows[18].balanceBefore, closeTo(1400.23, 0.02));

    final nov17 = result.days.firstWhere((d) => d.date.day == 17);
    expect(nov17.tradeCount, 7);
    expect(nov17.pnl, closeTo(-361.57, 0.02));
  });

  test('compute handles open trades and an empty journal', () {
    final empty = computeWorkbook(WorkbookJournal(
      settings: _settings,
      strategies: const [],
      sessions: const [],
      trades: const [],
      cashFlows: const [],
    ));
    expect(empty.closedTrades, 0);
    expect(empty.winRate, 0);
    expect(empty.profitFactor, isNull);
    expect(empty.accountBalance, 1000);

    final withOpen = computeWorkbook(WorkbookJournal(
      settings: _settings,
      strategies: const [],
      sessions: const [],
      trades: [
        WorkbookTrade(
          date: DateTime(2026, 11, 16),
          symbol: 'XAUUSD',
          direction: WorkbookDirection.buy,
          lots: 0.1,
          entry: 2000,
          exit: null,
        ),
      ],
      cashFlows: const [],
    ));
    expect(withOpen.rows.single.outcome, WorkbookOutcome.open);
    expect(withOpen.rows.single.pnl, isNull);
    expect(withOpen.closedTrades, 0);
  });

  test('renderWorkbookHtml emits one self-contained offline report', () {
    final html = renderWorkbookHtml(computeWorkbook(_fixtureJournal()));

    expect(html, contains('<!doctype html>'));
    expect(html, contains('<style>'));
    expect(html, contains('<script>'));
    expect(html, contains('<svg viewBox='));
    expect(html, contains('id="calendar"'));
    expect(html, contains('id="tradeTable"'));
    expect(html, contains('var DATA = {'));
    expect(html, isNot(contains('__DATA__')));
    expect(html, isNot(contains('http://')));
    expect(html, isNot(contains('https://')));
  });

  test('readJournal reads input cells from a generated workbook', () {
    final excel = Excel.createExcel();
    final setup = excel['Setup'];
    final tradeLog = excel['Trade Log'];
    final cashFlow = excel['Cash Flow'];
    final calendar = excel['Calendar'];
    final dashboard = excel['Dashboard'];

    setup.cell(CellIndex.indexByString('B4')).value = const IntCellValue(1000);
    setup.cell(CellIndex.indexByString('B5')).value = TextCellValue('USC');
    setup.cell(CellIndex.indexByString('B7')).value = const IntCellValue(1);
    setup.cell(CellIndex.indexByString('B8')).value = const IntCellValue(1000);
    setup.cell(CellIndex.indexByString('B9')).value = const IntCellValue(300);
    setup.cell(CellIndex.indexByString('B10')).value = const IntCellValue(5);
    setup.cell(CellIndex.indexByString('A12')).value =
        TextCellValue('ICT Silver Bullet');
    setup.cell(CellIndex.indexByString('B12')).value =
        TextCellValue('London');

    tradeLog.cell(CellIndex.indexByString('B6')).value =
        DateCellValue.fromDateTime(DateTime(2026, 11, 16));
    tradeLog.cell(CellIndex.indexByString('E6')).value =
        TextCellValue('XAUUSDc');
    tradeLog.cell(CellIndex.indexByString('F6')).value =
        TextCellValue('Buy');
    tradeLog.cell(CellIndex.indexByString('H6')).value =
        const DoubleCellValue(0.1);
    tradeLog.cell(CellIndex.indexByString('I6')).value =
        const DoubleCellValue(3846.088);
    tradeLog.cell(CellIndex.indexByString('J6')).value =
        const DoubleCellValue(3832.674);
    tradeLog.cell(CellIndex.indexByString('K6')).value =
        const DoubleCellValue(3866.086);
    tradeLog.cell(CellIndex.indexByString('L6')).value =
        const DoubleCellValue(3866.086);
    tradeLog.cell(CellIndex.indexByString('P6')).value =
        TextCellValue('999'); // Cached formula value must be ignored.

    cashFlow.cell(CellIndex.indexByString('A6')).value =
        DateCellValue.fromDateTime(DateTime(2026, 11, 19));
    cashFlow.cell(CellIndex.indexByString('B6')).value =
        TextCellValue('Withdrawal');
    cashFlow.cell(CellIndex.indexByString('C6')).value =
        const IntCellValue(1425);

    calendar.cell(CellIndex.indexByString('B4')).value = const IntCellValue(2026);
    calendar.cell(CellIndex.indexByString('D4')).value = const IntCellValue(11);
    dashboard.cell(CellIndex.indexByString('L49')).value =
        const IntCellValue(2026);

    final bytes = excel.encode();
    expect(bytes, isNotNull);
    final journal = readJournal(bytes!);

    expect(journal.settings.currency, 'USC');
    expect(journal.settings.startCapital, 1000);
    expect(journal.strategies, ['ICT Silver Bullet']);
    expect(journal.sessions, ['London']);
    expect(journal.trades, hasLength(1));
    expect(journal.trades.single.entry, 3846.088);
    expect(journal.cashFlows.single.effect, -1425);
    expect(journal.settings.calendarMonth, 11);

    final result = computeWorkbook(journal);
    expect(result.rows.single.pnl, closeTo(199.98, 0.01));
  });
}
