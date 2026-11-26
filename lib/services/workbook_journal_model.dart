enum WorkbookDirection { buy, sell }

enum WorkbookCashFlowType { deposit, withdrawal }

enum WorkbookOutcome { win, loss, breakeven, open }

class WorkbookTrade {
  final DateTime date;
  final String? session;
  final String symbol;
  final WorkbookDirection direction;
  final String? strategy;
  final double lots;
  final double entry;
  final double? stopLoss;
  final double? takeProfit;
  final double? exit;
  final String? screenshot;
  final String? notes;

  const WorkbookTrade({
    required this.date,
    this.session,
    required this.symbol,
    required this.direction,
    this.strategy,
    required this.lots,
    required this.entry,
    this.stopLoss,
    this.takeProfit,
    this.exit,
    this.screenshot,
    this.notes,
  });

  bool get isOpen => exit == null;

  String get directionLabel =>
      direction == WorkbookDirection.buy ? 'Buy' : 'Sell';

  Map<String, dynamic> toJson() => {
        'date': _dateKey(date),
        'session': session,
        'symbol': symbol,
        'direction': directionLabel,
        'strategy': strategy,
        'lots': lots,
        'entry': entry,
        'stopLoss': stopLoss,
        'takeProfit': takeProfit,
        'exit': exit,
        'screenshot': screenshot,
        'notes': notes,
      };

  factory WorkbookTrade.fromJson(Map<String, dynamic> json) {
    return WorkbookTrade(
      date: _parseDateKey(json['date'] as String?),
      session: json['session'] as String?,
      symbol: (json['symbol'] as String?) ?? 'XAUUSDc',
      direction: (json['direction'] as String?).toString().toLowerCase() == 'sell'
          ? WorkbookDirection.sell
          : WorkbookDirection.buy,
      strategy: json['strategy'] as String?,
      lots: (json['lots'] as num?)?.toDouble() ?? 0.0,
      entry: (json['entry'] as num?)?.toDouble() ?? 0.0,
      stopLoss: (json['stopLoss'] as num?)?.toDouble(),
      takeProfit: (json['takeProfit'] as num?)?.toDouble(),
      exit: (json['exit'] as num?)?.toDouble(),
      screenshot: json['screenshot'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class WorkbookCashFlow {
  final DateTime date;
  final WorkbookCashFlowType type;
  final double amount;
  final String? note;

  const WorkbookCashFlow({
    required this.date,
    required this.type,
    required this.amount,
    this.note,
  });

  double get effect =>
      type == WorkbookCashFlowType.withdrawal ? -amount : amount;

  String get typeLabel =>
      type == WorkbookCashFlowType.deposit ? 'Deposit' : 'Withdrawal';

  Map<String, dynamic> toJson() => {
        'date': _dateKey(date),
        'type': typeLabel,
        'amount': amount,
        'note': note,
      };

  factory WorkbookCashFlow.fromJson(Map<String, dynamic> json) {
    return WorkbookCashFlow(
      date: _parseDateKey(json['date'] as String?),
      type: (json['type'] as String?).toString().toLowerCase() == 'withdrawal'
          ? WorkbookCashFlowType.withdrawal
          : WorkbookCashFlowType.deposit,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      note: json['note'] as String?,
    );
  }
}

class WorkbookSettings {
  final double startCapital;
  final String currency;
  final double contractSize;
  final double monthlyTarget;
  final double dailyLossLimit;
  final int maxTradesPerDay;
  final int calendarYear;
  final int calendarMonth;
  final int dashboardYear;
  final String accountName;

  const WorkbookSettings({
    this.startCapital = 1000,
    this.currency = 'USC',
    this.contractSize = 1,
    this.monthlyTarget = 1000,
    this.dailyLossLimit = 300,
    this.maxTradesPerDay = 5,
    required this.calendarYear,
    required this.calendarMonth,
    required this.dashboardYear,
    this.accountName = 'Trading Journal',
  });

  bool get isCentAccount => currency.toUpperCase() == 'USC';

  double get currencyMultiplier => isCentAccount ? 100.0 : 1.0;

  Map<String, dynamic> toJson() => {
        'startCapital': startCapital,
        'currency': currency,
        'contractSize': contractSize,
        'monthlyTarget': monthlyTarget,
        'dailyLossLimit': dailyLossLimit,
        'maxTradesPerDay': maxTradesPerDay,
        'calendarYear': calendarYear,
        'calendarMonth': calendarMonth,
        'dashboardYear': dashboardYear,
        'accountName': accountName,
        'currencyMultiplier': currencyMultiplier,
      };
}

class WorkbookJournal {
  final WorkbookSettings settings;
  final List<String> strategies;
  final List<String> sessions;
  final List<WorkbookTrade> trades;
  final List<WorkbookCashFlow> cashFlows;

  const WorkbookJournal({
    required this.settings,
    required this.strategies,
    required this.sessions,
    required this.trades,
    required this.cashFlows,
  });

  Map<String, dynamic> toJson() => {
        'settings': settings.toJson(),
        'strategies': strategies,
        'sessions': sessions,
        'trades': trades.map((t) => t.toJson()).toList(),
        'cashFlows': cashFlows.map((c) => c.toJson()).toList(),
      };
}

class ExnessReportData {
  final List<WorkbookTrade> trades;
  final List<WorkbookCashFlow> cashFlows;

  const ExnessReportData({
    required this.trades,
    required this.cashFlows,
  });
}

class ComputedTrade {
  final WorkbookTrade trade;
  final int number;
  final String day;
  final double? risk;
  final double? plannedRr;
  final double? move;
  final double? pnl;
  final double? resultRr;
  final WorkbookOutcome outcome;
  final double? balanceBefore;
  final double? riskAmount;
  final double? balanceAfter;

  const ComputedTrade({
    required this.trade,
    required this.number,
    required this.day,
    required this.risk,
    required this.plannedRr,
    required this.move,
    required this.pnl,
    required this.resultRr,
    required this.outcome,
    required this.balanceBefore,
    required this.riskAmount,
    required this.balanceAfter,
  });

  bool get isClosed => pnl != null;

  String get outcomeLabel {
    switch (outcome) {
      case WorkbookOutcome.win:
        return 'Win';
      case WorkbookOutcome.loss:
        return 'Loss';
      case WorkbookOutcome.breakeven:
        return 'BE';
      case WorkbookOutcome.open:
        return '';
    }
  }

  Map<String, dynamic> toJson() => {
        'number': number,
        'date': _dateKey(trade.date),
        'day': day,
        'session': trade.session ?? '',
        'symbol': trade.symbol,
        'direction': trade.directionLabel,
        'strategy': trade.strategy ?? '',
        'lots': trade.lots,
        'entry': trade.entry,
        'stopLoss': trade.stopLoss,
        'takeProfit': trade.takeProfit,
        'exit': trade.exit,
        'risk': risk,
        'plannedRr': plannedRr,
        'move': move,
        'pnl': pnl,
        'resultRr': resultRr,
        'outcome': outcomeLabel,
        'balanceBefore': balanceBefore,
        'riskAmount': riskAmount,
        'balanceAfter': balanceAfter,
        'notes': trade.notes ?? '',
      };
}

class DayStat {
  final DateTime date;
  final double pnl;
  final int tradeCount;
  final int wins;
  final int losses;

  const DayStat({
    required this.date,
    required this.pnl,
    required this.tradeCount,
    required this.wins,
    required this.losses,
  });

  Map<String, dynamic> toJson() => {
        'date': _dateKey(date),
        'pnl': pnl,
        'tradeCount': tradeCount,
        'wins': wins,
        'losses': losses,
      };
}

class WeekdayStat {
  final String label;
  final int weekday;
  final double netPnl;
  final int trades;

  const WeekdayStat({
    required this.label,
    required this.weekday,
    required this.netPnl,
    required this.trades,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'netPnl': netPnl,
        'trades': trades,
      };
}

class MonthStat {
  final int year;
  final int month;
  final String label;
  final int trades;
  final int wins;
  final int losses;
  final double netPnl;
  final double? winRate;
  final double returnRatio;
  final String? target;

  const MonthStat({
    required this.year,
    required this.month,
    required this.label,
    required this.trades,
    required this.wins,
    required this.losses,
    required this.netPnl,
    required this.winRate,
    required this.returnRatio,
    required this.target,
  });

  Map<String, dynamic> toJson() => {
        'year': year,
        'month': month,
        'label': label,
        'trades': trades,
        'winRate': winRate,
        'netPnl': netPnl,
        'returnRatio': returnRatio,
        'target': target,
      };
}

class StrategyStat {
  final String name;
  final int trades;
  final int wins;
  final int losses;
  final double netPnl;
  final double? avgResultRr;
  final double? profitFactor;

  const StrategyStat({
    required this.name,
    required this.trades,
    required this.wins,
    required this.losses,
    required this.netPnl,
    required this.avgResultRr,
    required this.profitFactor,
  });

  double? get winRate {
    final denom = wins + losses;
    return denom == 0 ? null : wins / denom;
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'trades': trades,
        'winRate': winRate,
        'netPnl': netPnl,
        'avgResultRr': avgResultRr,
        'profitFactor': profitFactor,
      };
}

class EquityPoint {
  final int tradeNumber;
  final double equity;

  const EquityPoint({required this.tradeNumber, required this.equity});

  Map<String, dynamic> toJson() => {
        'tradeNumber': tradeNumber,
        'equity': equity,
      };
}

class WorkbookComputeResult {
  final WorkbookSettings settings;
  final List<ComputedTrade> rows;
  final List<WorkbookCashFlow> cashFlows;
  final double accountBalance;
  final double totalCashFlow;
  final double netPnl;
  final double netPnlUsd;
  final int closedTrades;
  final int wins;
  final int losses;
  final int breakEvens;
  final double winRate;
  final double? profitFactor;
  final double grossProfit;
  final double grossLoss;
  final double expectancy;
  final double avgWin;
  final double avgLoss;
  final double maxDrawdown;
  final double peakEquity;
  final double avgResultRr;
  final double medianPlannedRr;
  final double monthPnl;
  final double monthlyGoal;
  final int tradingDays;
  final double avgTradesPerDay;
  final int daysOverLossLimit;
  final int daysOverTradeLimit;
  final double bestDay;
  final double worstDay;
  final int longestWinStreak;
  final int longestLossStreak;
  final String currentStreak;
  final List<DayStat> days;
  final List<WeekdayStat> weekdays;
  final List<MonthStat> months;
  final List<StrategyStat> strategies;
  final List<double> last20Pnl;
  final List<EquityPoint> equityCurve;
  final DateTime? firstTradeDate;
  final DateTime? lastTradeDate;

  const WorkbookComputeResult({
    required this.settings,
    required this.rows,
    required this.cashFlows,
    required this.accountBalance,
    required this.totalCashFlow,
    required this.netPnl,
    required this.netPnlUsd,
    required this.closedTrades,
    required this.wins,
    required this.losses,
    required this.breakEvens,
    required this.winRate,
    required this.profitFactor,
    required this.grossProfit,
    required this.grossLoss,
    required this.expectancy,
    required this.avgWin,
    required this.avgLoss,
    required this.maxDrawdown,
    required this.peakEquity,
    required this.avgResultRr,
    required this.medianPlannedRr,
    required this.monthPnl,
    required this.monthlyGoal,
    required this.tradingDays,
    required this.avgTradesPerDay,
    required this.daysOverLossLimit,
    required this.daysOverTradeLimit,
    required this.bestDay,
    required this.worstDay,
    required this.longestWinStreak,
    required this.longestLossStreak,
    required this.currentStreak,
    required this.days,
    required this.weekdays,
    required this.months,
    required this.strategies,
    required this.last20Pnl,
    required this.equityCurve,
    required this.firstTradeDate,
    required this.lastTradeDate,
  });

  Map<String, dynamic> toJson() => {
        'settings': settings.toJson(),
        'rows': rows.map((r) => r.toJson()).toList(),
        'cashFlows': cashFlows.map((c) => c.toJson()).toList(),
        'kpis': {
          'accountBalance': accountBalance,
          'totalCashFlow': totalCashFlow,
          'netPnl': netPnl,
          'netPnlUsd': netPnlUsd,
          'closedTrades': closedTrades,
          'wins': wins,
          'losses': losses,
          'breakEvens': breakEvens,
          'winRate': winRate,
          'profitFactor': profitFactor,
          'grossProfit': grossProfit,
          'grossLoss': grossLoss,
          'expectancy': expectancy,
          'avgWin': avgWin,
          'avgLoss': avgLoss,
          'maxDrawdown': maxDrawdown,
          'peakEquity': peakEquity,
          'avgResultRr': avgResultRr,
          'medianPlannedRr': medianPlannedRr,
          'monthPnl': monthPnl,
          'monthlyGoal': monthlyGoal,
          'tradingDays': tradingDays,
          'avgTradesPerDay': avgTradesPerDay,
          'daysOverLossLimit': daysOverLossLimit,
          'daysOverTradeLimit': daysOverTradeLimit,
          'bestDay': bestDay,
          'worstDay': worstDay,
          'longestWinStreak': longestWinStreak,
          'longestLossStreak': longestLossStreak,
          'currentStreak': currentStreak,
        },
        'days': days.map((d) => d.toJson()).toList(),
        'weekdays': weekdays.map((w) => w.toJson()).toList(),
        'months': months.map((m) => m.toJson()).toList(),
        'strategies': strategies.map((s) => s.toJson()).toList(),
        'last20Pnl': last20Pnl,
        'equityCurve': equityCurve.map((p) => p.toJson()).toList(),
        'firstTradeDate': firstTradeDate == null ? null : _dateKey(firstTradeDate!),
        'lastTradeDate': lastTradeDate == null ? null : _dateKey(lastTradeDate!),
      };
}

String _dateKey(DateTime? value) {
  if (value == null) return '';
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

DateTime _parseDateKey(String? value) {
  if (value == null || value.isEmpty) return DateTime(2000, 1, 1);
  final parsed = DateTime.tryParse(value);
  return parsed ?? DateTime(2000, 1, 1);
}
