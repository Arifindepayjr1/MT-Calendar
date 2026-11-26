import 'dart:math' as math;

import 'workbook_journal_model.dart';
import 'workbook_journal_parser.dart';

/// Pure computation layer. Mirrors every formula in the Trading Journal
/// Workbook using only the input cells returned by [readJournal].
WorkbookComputeResult computeWorkbook(WorkbookJournal journal) {
  final settings = journal.settings;
  final multiplier = settings.currencyMultiplier;
  final contractSize = settings.contractSize;
  final start = settings.startCapital;

  final cashByDate = <String, double>{};
  for (final flow in journal.cashFlows) {
    final key = _dateKey(flow.date);
    cashByDate[key] = (cashByDate[key] ?? 0.0) + flow.effect;
  }
  final totalCashFlow = cashByDate.values.fold(0.0, (a, b) => a + b);

  double cashBefore(DateTime date) {
    final key = _dateKey(date);
    var total = 0.0;
    for (final entry in cashByDate.entries) {
      if (entry.key.compareTo(key) < 0) total += entry.value;
    }
    return total;
  }

  final rows = <ComputedTrade>[];
  var runningPl = 0.0;
  for (var i = 0; i < journal.trades.length; i++) {
    final trade = journal.trades[i];
    final risk = trade.stopLoss == null
        ? null
        : (trade.entry - trade.stopLoss!).abs();
    final plannedRr = (risk == null || risk <= 0 || trade.takeProfit == null)
        ? null
        : (trade.takeProfit! - trade.entry).abs() / risk;
    final move = trade.exit == null
        ? null
        : trade.direction == WorkbookDirection.buy
            ? trade.exit! - trade.entry
            : trade.entry - trade.exit!;
    final pnl = move == null
        ? null
        : move * trade.lots * contractSize * multiplier;
    final resultRr = (pnl == null || risk == null || risk <= 0 || move == null)
        ? null
        : move / risk;
    final outcome = pnl == null
        ? WorkbookOutcome.open
        : pnl > 0
            ? WorkbookOutcome.win
            : pnl < 0
                ? WorkbookOutcome.loss
                : WorkbookOutcome.breakeven;
    final balanceBefore =
        pnl == null ? null : start + runningPl + cashBefore(trade.date);
    final riskAmount = (risk == null || trade.lots == 0)
        ? null
        : risk * trade.lots * contractSize * multiplier;
    final balanceAfter = pnl == null ? null : balanceBefore! + pnl;

    rows.add(ComputedTrade(
      trade: trade,
      number: i + 1,
      day: _weekdayShort(trade.date.weekday),
      risk: risk,
      plannedRr: plannedRr,
      move: move,
      pnl: pnl,
      resultRr: resultRr,
      outcome: outcome,
      balanceBefore: balanceBefore,
      riskAmount: riskAmount,
      balanceAfter: balanceAfter,
    ));
    if (pnl != null) runningPl += pnl;
  }

  final closed = rows.where((r) => r.isClosed).toList();
  final netPnl = closed.fold(0.0, (sum, r) => sum + r.pnl!);
  final wins = closed.where((r) => r.outcome == WorkbookOutcome.win).length;
  final losses = closed.where((r) => r.outcome == WorkbookOutcome.loss).length;
  final breakEvens =
      closed.where((r) => r.outcome == WorkbookOutcome.breakeven).length;
  final grossProfit = closed
      .where((r) => r.pnl! > 0)
      .fold(0.0, (sum, r) => sum + r.pnl!);
  final grossLoss = closed
      .where((r) => r.pnl! < 0)
      .fold(0.0, (sum, r) => sum - r.pnl!);
  final winRate = (wins + losses) == 0 ? 0.0 : wins / (wins + losses);
  final profitFactor = grossLoss <= 0 ? null : grossProfit / grossLoss;
  final expectancy = closed.isEmpty ? 0.0 : netPnl / closed.length;
  final avgWin = wins == 0 ? 0.0 : grossProfit / wins;
  final avgLoss = losses == 0 ? 0.0 : -grossLoss / losses;

  // Equity excludes cash flow on purpose: a withdrawal must never look like a
  // trading loss. Row order is authoritative.
  var equity = start;
  var peakEquity = start;
  var maxDrawdown = 0.0;
  final equityCurve = <EquityPoint>[EquityPoint(tradeNumber: 0, equity: start)];
  for (final row in closed) {
    equity += row.pnl!;
    if (equity > peakEquity) peakEquity = equity;
    final drawdown = peakEquity - equity;
    if (drawdown > maxDrawdown) maxDrawdown = drawdown;
    equityCurve.add(EquityPoint(tradeNumber: row.number, equity: equity));
  }

  final resultRrs = closed
      .where((r) => r.resultRr != null)
      .map((r) => r.resultRr!)
      .toList();
  final plannedRrs = rows
      .where((r) => r.plannedRr != null)
      .map((r) => r.plannedRr!)
      .toList();
  final avgResultRr = _average(resultRrs);
  final medianPlannedRr = _median(plannedRrs);

  final dayMap = <String, _DayAccumulator>{};
  for (final row in rows) {
    final key = _dateKey(row.trade.date);
    final acc = dayMap.putIfAbsent(
        key, () => _DayAccumulator(date: row.trade.date));
    acc.tradeCount++;
    if (row.pnl != null) {
      acc.pnl += row.pnl!;
      if (row.outcome == WorkbookOutcome.win) acc.wins++;
      if (row.outcome == WorkbookOutcome.loss) acc.losses++;
    }
  }
  final days = dayMap.values.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final dayStats = days
      .map(
        (d) => DayStat(
          date: d.date,
          pnl: d.pnl,
          tradeCount: d.tradeCount,
          wins: d.wins,
          losses: d.losses,
        ),
      )
      .toList();

  final monthPnl = dayStats
      .where(
        (d) =>
            d.date.year == settings.calendarYear &&
            d.date.month == settings.calendarMonth,
      )
      .fold(0.0, (sum, d) => sum + d.pnl);
  final monthlyGoal = settings.monthlyTarget > 0
      ? monthPnl / settings.monthlyTarget
      : 0.0;

  final tradingDays = dayStats.length;
  final avgTradesPerDay =
      tradingDays == 0 ? 0.0 : closed.length / tradingDays;
  final daysOverLossLimit = settings.dailyLossLimit > 0
      ? dayStats
          .where((d) => d.pnl < -settings.dailyLossLimit)
          .length
      : 0;
  final daysOverTradeLimit = settings.maxTradesPerDay > 0
      ? dayStats
          .where((d) => d.tradeCount > settings.maxTradesPerDay)
          .length
      : 0;
  final bestDay = dayStats.isEmpty
      ? 0.0
      : dayStats.map((d) => d.pnl).reduce(math.max);
  final worstDay = dayStats.isEmpty
      ? 0.0
      : dayStats.map((d) => d.pnl).reduce(math.min);

  var longestWinStreak = 0;
  var longestLossStreak = 0;
  var currentWin = 0;
  var currentLoss = 0;
  for (final row in closed) {
    if (row.outcome == WorkbookOutcome.win) {
      currentWin++;
      currentLoss = 0;
      if (currentWin > longestWinStreak) longestWinStreak = currentWin;
    } else if (row.outcome == WorkbookOutcome.loss) {
      currentLoss++;
      currentWin = 0;
      if (currentLoss > longestLossStreak) longestLossStreak = currentLoss;
    } else {
      currentWin = 0;
      currentLoss = 0;
    }
  }
  var currentStreak = '—';
  if (closed.isNotEmpty) {
    final last = closed.last.outcome;
    if (last == WorkbookOutcome.win) {
      currentStreak = '$currentWin W';
    } else if (last == WorkbookOutcome.loss) {
      currentStreak = '$currentLoss L';
    } else {
      currentStreak = 'BE';
    }
  }

  final weekdays = <WeekdayStat>[];
  for (var weekday = 1; weekday <= 5; weekday++) {
    final matching = closed.where((r) => r.trade.date.weekday == weekday);
    weekdays.add(WeekdayStat(
      label: _weekdayShort(weekday),
      weekday: weekday,
      netPnl: matching.fold(0.0, (sum, r) => sum + r.pnl!),
      trades: matching.length,
    ));
  }

  final monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final months = <MonthStat>[];
  for (var month = 1; month <= 12; month++) {
    final matching = closed
        .where(
          (r) =>
              r.trade.date.year == settings.dashboardYear &&
              r.trade.date.month == month,
        )
        .toList();
    final monthWins =
        matching.where((r) => r.outcome == WorkbookOutcome.win).length;
    final monthLosses =
        matching.where((r) => r.outcome == WorkbookOutcome.loss).length;
    final monthNet = matching.fold(0.0, (sum, r) => sum + r.pnl!);
    months.add(MonthStat(
      year: settings.dashboardYear,
      month: month,
      label: monthNames[month - 1],
      trades: matching.length,
      wins: monthWins,
      losses: monthLosses,
      netPnl: monthNet,
      winRate:
          (monthWins + monthLosses) == 0 ? null : monthWins / (monthWins + monthLosses),
      returnRatio: start == 0 ? 0.0 : monthNet / start,
      target: matching.isEmpty
          ? null
          : settings.monthlyTarget <= 0
              ? null
              : monthNet >= settings.monthlyTarget
                  ? 'Hit'
                  : 'Miss',
    ));
  }

  final setupNames = journal.strategies.toSet();
  final strategyAcc = <String, _StrategyAccumulator>{};
  for (final row in closed) {
    final raw = row.trade.strategy?.trim() ?? '';
    final name = raw.isNotEmpty && setupNames.contains(raw)
        ? raw
        : notInSetupList;
    final acc = strategyAcc.putIfAbsent(name, () => _StrategyAccumulator(name));
    acc.trades++;
    if (row.outcome == WorkbookOutcome.win) acc.wins++;
    if (row.outcome == WorkbookOutcome.loss) acc.losses++;
    acc.netPnl += row.pnl!;
    if (row.resultRr != null) {
      acc.resultRrSum += row.resultRr!;
      acc.resultRrCount++;
    }
    if (row.pnl! > 0) acc.grossProfit += row.pnl!;
    if (row.pnl! < 0) acc.grossLoss -= row.pnl!;
  }
  final strategies = strategyAcc.values
      .map(
        (a) => StrategyStat(
          name: a.name,
          trades: a.trades,
          wins: a.wins,
          losses: a.losses,
          netPnl: a.netPnl,
          avgResultRr:
              a.resultRrCount == 0 ? null : a.resultRrSum / a.resultRrCount,
          profitFactor:
              a.grossLoss <= 0 ? null : a.grossProfit / a.grossLoss,
        ),
      )
      .toList()
    ..sort((a, b) {
      if (a.name == notInSetupList) return -1;
      if (b.name == notInSetupList) return 1;
      return journal.strategies.indexOf(a.name)
          .compareTo(journal.strategies.indexOf(b.name));
    });

  final accountBalance = start + netPnl + totalCashFlow;
  final last20Pnl = closed
      .skip(math.max(0, closed.length - 20))
      .map((r) => r.pnl!)
      .toList();

  return WorkbookComputeResult(
    settings: settings,
    rows: rows,
    cashFlows: journal.cashFlows,
    accountBalance: accountBalance,
    totalCashFlow: totalCashFlow,
    netPnl: netPnl,
    netPnlUsd: multiplier == 0 ? netPnl : netPnl / multiplier,
    closedTrades: closed.length,
    wins: wins,
    losses: losses,
    breakEvens: breakEvens,
    winRate: winRate,
    profitFactor: profitFactor,
    grossProfit: grossProfit,
    grossLoss: grossLoss,
    expectancy: expectancy,
    avgWin: avgWin,
    avgLoss: avgLoss,
    maxDrawdown: maxDrawdown,
    peakEquity: peakEquity,
    avgResultRr: avgResultRr,
    medianPlannedRr: medianPlannedRr,
    monthPnl: monthPnl,
    monthlyGoal: monthlyGoal,
    tradingDays: tradingDays,
    avgTradesPerDay: avgTradesPerDay,
    daysOverLossLimit: daysOverLossLimit,
    daysOverTradeLimit: daysOverTradeLimit,
    bestDay: bestDay,
    worstDay: worstDay,
    longestWinStreak: longestWinStreak,
    longestLossStreak: longestLossStreak,
    currentStreak: currentStreak,
    days: dayStats,
    weekdays: weekdays,
    months: months,
    strategies: strategies,
    last20Pnl: last20Pnl,
    equityCurve: equityCurve,
    firstTradeDate:
        journal.trades.isEmpty ? null : journal.trades.first.date,
    lastTradeDate: journal.trades.isEmpty ? null : journal.trades.last.date,
  );
}

class _DayAccumulator {
  final DateTime date;
  double pnl = 0;
  int tradeCount = 0;
  int wins = 0;
  int losses = 0;

  _DayAccumulator({required this.date});
}

class _StrategyAccumulator {
  final String name;
  int trades = 0;
  int wins = 0;
  int losses = 0;
  double netPnl = 0;
  double grossProfit = 0;
  double grossLoss = 0;
  double resultRrSum = 0;
  int resultRrCount = 0;

  _StrategyAccumulator(this.name);
}

double _average(List<double> values) =>
    values.isEmpty ? 0.0 : values.fold(0.0, (a, b) => a + b) / values.length;

double _median(List<double> values) {
  if (values.isEmpty) return 0.0;
  final sorted = [...values]..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _weekdayShort(int weekday) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[(weekday - 1).clamp(0, 6)];
}
