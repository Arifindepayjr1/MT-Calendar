import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:trader_log/model/journal.model.dart';
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/services/strategy_api_service.dart';
import 'package:trader_log/widgets/home_app_bar.dart';

import 'statistics_export.dart';

const _bg = Color(0xFF111411);
const _surfaceLow = Color(0xFF191C19);
const _surface = Color(0xFF202320);
const _border = Color(0xFF252B25);
const _mint = Color(0xFFB7F7C4);
const _green = Color(0xFF4ADE80);
const _coral = Color(0xFFF87171);
const _ink = Color(0xFFF0FDF4);
const _muted = Color(0xFF889088);

enum _Timeframe { d7, d30, d90, ytd, custom }

enum _SessionZone { utc, est }

class StatisticsScreen extends StatefulWidget {
  final List<Trade> trades;
  final String accountName;
  final String brokerAndNumber;
  final String currency;
  final double initialDeposit;
  final Map<String, Journal> journals;
  final StrategyApiService strategyApi;

  const StatisticsScreen({
    super.key,
    required this.trades,
    required this.accountName,
    required this.brokerAndNumber,
    required this.currency,
    required this.initialDeposit,
    required this.journals,
    this.strategyApi = const StrategyApiService(),
  });

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StrategyPerf {
  final String name;
  final int trades;
  final double winRate;
  final double avgR;
  final double netPnl;

  const _StrategyPerf({
    required this.name,
    required this.trades,
    required this.winRate,
    required this.avgR,
    required this.netPnl,
  });
}

class _SessionPerf {
  final String name;
  final double winRate;
  final double netPnl;

  const _SessionPerf({
    required this.name,
    required this.winRate,
    required this.netPnl,
  });
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  _Timeframe _timeframe = _Timeframe.d30;
  _SessionZone _zone = _SessionZone.utc;
  List<String> _savedStrategyNames = const [];

  @override
  void initState() {
    super.initState();
    _loadStrategies();
  }

  @override
  void didUpdateWidget(covariant StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.strategyApi.hasToken != widget.strategyApi.hasToken) {
      _loadStrategies();
    }
  }

  Future<void> _loadStrategies() async {
    if (!widget.strategyApi.hasToken) {
      if (mounted) setState(() => _savedStrategyNames = const []);
      return;
    }
    try {
      final drafts = await widget.strategyApi.fetchDrafts();
      if (!mounted) return;
      setState(() {
        _savedStrategyNames = drafts.map((d) => d.name).toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _savedStrategyNames = const []);
    }
  }

  bool get _isCent => widget.currency.toUpperCase() == 'USC';
  double _amount(double raw) => _isCent ? raw / 100.0 : raw;
  String get _ccy => _isCent ? 'USD' : widget.currency.toUpperCase();

  String _money(double raw, {bool sign = false, int decimals = 2}) {
    final v = _amount(raw);
    final neg = v < 0;
    final prefix = sign ? (neg ? '-' : '+') : (neg ? '-' : '');
    final abs = v.abs().toStringAsFixed(decimals);
    final parts = abs.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    final numStr = decimals > 0 ? '$intPart.${parts[1]}' : intPart;
    if (_ccy == 'USD') return '$prefix\$$numStr';
    return '$prefix$numStr $_ccy';
  }

  String _compact(double raw, {bool sign = true}) {
    final v = _amount(raw);
    final s = v < 0 ? '-' : (sign ? '+' : '');
    final a = v.abs();
    String body;
    if (a >= 1000000) {
      body = '${(a / 1000000).toStringAsFixed(2)}M';
    } else if (a >= 1000) {
      body = '${(a / 1000).toStringAsFixed(1)}k';
    } else {
      body = a.toStringAsFixed(a == a.roundToDouble() ? 0 : 2);
    }
    if (_ccy == 'USD') return '$s\$$body';
    return '$s$body $_ccy';
  }

  List<Trade> get _filteredTrades {
    final all = [...widget.trades]
      ..sort((a, b) => a.closeTime.compareTo(b.closeTime));
    if (all.isEmpty) return const [];
    final now = DateTime.now();
    DateTime? from;
    switch (_timeframe) {
      case _Timeframe.d7:
        from = now.subtract(const Duration(days: 7));
        break;
      case _Timeframe.d30:
        from = now.subtract(const Duration(days: 30));
        break;
      case _Timeframe.d90:
        from = now.subtract(const Duration(days: 90));
        break;
      case _Timeframe.ytd:
        from = DateTime(now.year, 1, 1);
        break;
      case _Timeframe.custom:
        from = null;
        break;
    }
    if (from == null) return all;
    return all.where((t) => !t.closeTime.isBefore(from!)).toList();
  }

  double get _netPnl => _filteredTrades.fold(0.0, (s, t) => s + t.netProfit);
  int get _wins => _filteredTrades.where((t) => t.netProfit > 0).length;
  int get _losses => _filteredTrades.where((t) => t.netProfit < 0).length;
  double get _winRate => (_wins + _losses) == 0
      ? 0
      : _wins / (_wins + _losses) * 100;

  double get _grossProfit => _filteredTrades
      .where((t) => t.netProfit > 0)
      .fold(0.0, (s, t) => s + t.netProfit);
  double get _grossLossAbs => _filteredTrades
      .where((t) => t.netProfit < 0)
      .fold(0.0, (s, t) => s + t.netProfit.abs());
  double? get _profitFactor {
    if (_grossLossAbs == 0) return _grossProfit > 0 ? null : 0;
    return _grossProfit / _grossLossAbs;
  }

  double? _tradeR(Trade t) {
    final sl = t.stoploss;
    if (sl == null || sl <= 0) return null;
    final risk = (t.openPrice - sl).abs();
    if (risk <= 0) return null;
    final signed = t.type == TradeType.buy
        ? (t.closePrice - t.openPrice)
        : (t.openPrice - t.closePrice);
    return signed / risk;
  }

  double? get _expectancyR {
    final rValues = <double>[];
    for (final t in _filteredTrades) {
      final r = _tradeR(t);
      if (r != null) rValues.add(r);
    }
    if (rValues.isEmpty) return null;
    return rValues.reduce((a, b) => a + b) / rValues.length;
  }

  double get _avgWinR {
    final vals = _filteredTrades
        .where((t) => t.netProfit > 0)
        .map(_tradeR)
        .whereType<double>()
        .toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  double get _avgLossR {
    final vals = _filteredTrades
        .where((t) => t.netProfit < 0)
        .map(_tradeR)
        .whereType<double>()
        .map((r) => r.abs())
        .toList();
    if (vals.isEmpty) return 0;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  List<double> get _equityCurve {
    final trades = _filteredTrades;
    if (trades.isEmpty) return const [0];
    final byDay = <DateTime, double>{};
    for (final t in trades) {
      final d = DateTime(t.closeTime.year, t.closeTime.month, t.closeTime.day);
      byDay[d] = (byDay[d] ?? 0) + t.netProfit;
    }
    final days = byDay.keys.toList()..sort();
    final start = days.first;
    final end = days.last;
    final totalDays = math.max(1, end.difference(start).inDays);
    final points = math.min(30, totalDays + 1);
    final result = <double>[0];
    double cum = 0;
    for (var i = 0; i < points; i++) {
      final day = start.add(Duration(
        days: (totalDays * i / math.max(1, points - 1)).round(),
      ));
      cum += byDay[DateTime(day.year, day.month, day.day)] ?? 0;
      result.add(cum);
    }
    return result;
  }

  List<_StrategyPerf> get _strategyPlaybooks {
    final groups = <String, List<Trade>>{};
    for (final t in _filteredTrades) {
      final j = widget.journals[t.id];
      final name = (j?.strategyName?.trim().isNotEmpty == true)
          ? j!.strategyName!.trim()
          : (j?.strategyNames?.isNotEmpty == true
              ? j!.strategyNames!.first
              : 'Unassigned');
      groups.putIfAbsent(name, () => []).add(t);
    }
    final list = groups.entries.map((e) {
      final ts = e.value;
      final wins = ts.where((t) => t.netProfit > 0).length;
      final losses = ts.where((t) => t.netProfit < 0).length;
      final wr = (wins + losses) == 0 ? 0.0 : wins / (wins + losses) * 100;
      final rs = ts.map(_tradeR).whereType<double>().toList();
      final avgR = rs.isEmpty ? 0.0 : rs.reduce((a, b) => a + b) / rs.length;
      final pnl = ts.fold(0.0, (s, t) => s + t.netProfit);
      return _StrategyPerf(
        name: e.key,
        trades: ts.length,
        winRate: wr,
        avgR: avgR,
        netPnl: pnl,
      );
    }).toList();
    list.sort((a, b) => b.netPnl.compareTo(a.netPnl));
    return list.take(5).toList();
  }

  int _sessionHour(DateTime dt) {
    final utc = dt.toUtc();
    return _zone == _SessionZone.utc ? utc.hour : (utc.hour - 5) % 24;
  }

  String _sessionFor(Trade t) {
    final h = _sessionHour(t.openTime);
    if (_zone == _SessionZone.utc) {
      if (h >= 0 && h < 7) return 'Asian';
      if (h >= 7 && h < 12) return 'London';
      if (h >= 12 && h < 21) return 'New York';
      return 'Asian';
    }
    if (h >= 19 || h < 2) return 'Asian';
    if (h >= 2 && h < 7) return 'London';
    if (h >= 7 && h < 16) return 'New York';
    return 'Asian';
  }

  List<_SessionPerf> get _sessionPerformance {
    final buckets = <String, List<Trade>>{
      'London Session': [],
      'New York Session': [],
      'Asian Session': [],
    };
    for (final t in _filteredTrades) {
      buckets['${_sessionFor(t)} Session']!.add(t);
    }
    final list = buckets.entries.map((e) {
      final ts = e.value;
      final wins = ts.where((t) => t.netProfit > 0).length;
      final losses = ts.where((t) => t.netProfit < 0).length;
      final wr = (wins + losses) == 0 ? 0.0 : wins / (wins + losses) * 100;
      final pnl = ts.fold(0.0, (s, t) => s + t.netProfit);
      return _SessionPerf(name: e.key, winRate: wr, netPnl: pnl);
    }).toList();
    list.sort((a, b) => b.netPnl.compareTo(a.netPnl));
    return list;
  }

  Iterable<String> get _allRules => widget.journals.values.expand(
        (j) => j.rulesFollowed ?? const <String>[],
      );

  int get _rulesHonored => _allRules
      .where((r) => !r.toLowerCase().contains('violat'))
      .length;

  int get _rulesViolated =>
      _allRules.where((r) => r.toLowerCase().contains('violat')).length;

  int get _rulesTotal => _rulesHonored + _rulesViolated;

  int get _journalsWithRules => widget.journals.values
      .where((j) => (j.rulesFollowed?.length ?? 0) > 0)
      .length;

  int get _journalsWithViolations => widget.journals.values
      .where(
        (j) =>
            j.rulesFollowed?.any((r) => r.toLowerCase().contains('violat')) ==
            true,
      )
      .length;

  static const Set<EmotionalState> _negativeEmotions = <EmotionalState>{
    EmotionalState.fearful,
    EmotionalState.greedy,
    EmotionalState.frustrated,
    EmotionalState.anxious,
    EmotionalState.impatient,
    EmotionalState.fomo,
    EmotionalState.revengeTrading,
  };

  int get _emotionalDepartures => widget.journals.values
      .where((j) => _negativeEmotions.contains(j.emotionalState))
      .length;

  double? get _disciplinePercent => _rulesTotal == 0
      ? null
      : _rulesHonored / _rulesTotal * 100;

  double? _winRateForJournals({required bool withRules}) {
    final ids = widget.journals.entries
        .where(
          (e) => ((e.value.rulesFollowed?.length ?? 0) > 0) == withRules,
        )
        .map((e) => e.key)
        .toSet();
    final trades = _filteredTrades.where((t) => ids.contains(t.id)).toList();
    final wins = trades.where((t) => t.netProfit > 0).length;
    final losses = trades.where((t) => t.netProfit < 0).length;
    if (wins + losses == 0) return null;
    return wins / (wins + losses) * 100;
  }

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  String _buildCsv() {
    final rows = <List<String>>[
      [
        'Ticket',
        'Open Time (UTC)',
        'Close Time (UTC)',
        'Symbol',
        'Type',
        'Lots',
        'Open',
        'SL',
        'TP',
        'Close',
        'Net P&L',
        'R',
        'Strategy',
        'Session',
        'Emotion',
        'Rules Followed',
        'Notes',
      ],
    ];
    for (final t in _filteredTrades) {
      final j = widget.journals[t.id];
      final r = _tradeR(t);
      rows.add([
        t.ticket,
        t.openTime.toUtc().toIso8601String(),
        t.closeTime.toUtc().toIso8601String(),
        t.symbol,
        t.type.name,
        t.volume.toStringAsFixed(2),
        t.openPrice.toStringAsFixed(5),
        t.stoploss?.toStringAsFixed(5) ?? '',
        t.takeProfit?.toStringAsFixed(5) ?? '',
        t.closePrice.toStringAsFixed(5),
        t.netProfit.toStringAsFixed(2),
        r?.toStringAsFixed(2) ?? '',
        j?.strategyName ?? (j?.strategyNames?.join(' / ') ?? ''),
        j?.tradingSession ?? _sessionFor(t),
        j?.emotionalState?.name ?? '',
        (j?.rulesFollowed ?? const []).join(' | '),
        [
          j?.entryReason,
          j?.plan,
          j?.executionNotes,
          j?.lessonLearned,
        ].whereType<String>().join(' | '),
      ]);
    }
    return rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
  }

  Future<void> _exportReport() async {
    final csv = _buildCsv();
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-');
    final fileName = 'traderlog_audit_$stamp.csv';
    try {
      await downloadStatisticsCsv(fileName: fileName, csv: csv);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('CSV audit report downloaded.'),
          backgroundColor: _surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('CSV export is unavailable on this platform.'),
          backgroundColor: _surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTrades = _filteredTrades.isNotEmpty;

    return Scaffold(
      backgroundColor: _bg,
      appBar: HomeAppBar(accountName: widget.accountName, backgroundColor: _bg),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _header(),
            const SizedBox(height: 14),
            _timeframePills(),
            if (!hasTrades) ...[
              const SizedBox(height: 12),
              _emptyNotice(),
            ],
            const SizedBox(height: 16),
            _kpiGrid(),
            const SizedBox(height: 14),
            _disciplineCard(
              percent: _disciplinePercent,
              honored: _rulesHonored,
              violated: _rulesViolated,
              total: _rulesTotal,
              departures: _emotionalDepartures,
              followedWr: _winRateForJournals(withRules: true),
              violatedWr: _winRateForJournals(withRules: false),
              followedCount: _journalsWithRules,
              violatedCount: _journalsWithViolations,
            ),
            const SizedBox(height: 14),
            _equityCard(hasTrades ? _netPnl : null),
            const SizedBox(height: 14),
            _strategyCard(),
            const SizedBox(height: 14),
            _sessionCard(),
            const SizedBox(height: 16),
            _exportButton(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance Analytics',
                style: TextStyle(
                  color: _ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Disciplined execution audit',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
        _accountPill(),
      ],
    );
  }

  Widget _accountPill() {
    return Tooltip(
      message: widget.brokerAndNumber.isNotEmpty
          ? widget.brokerAndNumber
          : 'All imported accounts',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _surfaceLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: _mint,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'All Accounts',
              style: TextStyle(
                color: _ink,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _muted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeframePills() {
    Widget pill(String label, _Timeframe tf) {
      final active = _timeframe == tf;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: active ? _mint : _surfaceLow,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _timeframe = tf),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? _mint : _border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (active) ...[
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: _bg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? _bg : _muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          pill('7D', _Timeframe.d7),
          pill('30D', _Timeframe.d30),
          pill('90D', _Timeframe.d90),
          pill('YTD', _Timeframe.ytd),
          pill('Custom', _Timeframe.custom),
        ],
      ),
    );
  }

  Widget _emptyNotice() {
    return _card(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _surfaceLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.timeline_outlined, color: _mint, size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No closed trades in this range',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Import MT5 trades or change the timeframe to fill the audit.',
                  style: TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiGrid() {
    final trades = _filteredTrades;
    final dayCount = trades
        .map(
          (t) => DateTime(
            t.closeTime.year,
            t.closeTime.month,
            t.closeTime.day,
          ),
        )
        .toSet()
        .length;
    final perDay = dayCount == 0 ? null : _netPnl / dayCount;
    final pfText =
        _profitFactor == null ? '—' : _profitFactor!.toStringAsFixed(2);
    final expText = _expectancyR == null
        ? '—'
        : '${_expectancyR! >= 0 ? '+' : ''}${_expectancyR!.toStringAsFixed(2)} R';
    final rAvailable = _expectancyR != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 1 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: columns == 1 ? 2.6 : 1.75,
          children: [
            _kpiTile(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Net Realized P&L',
              value: _money(_netPnl, sign: true),
              sub: perDay == null
                  ? '— / day'
                  : '${_money(perDay, sign: true)} / day',
              valueColor: _netPnl >= 0 ? _mint : _coral,
            ),
            _kpiTile(
              icon: Icons.percent,
              label: 'Win Rate',
              value: '${_winRate.toStringAsFixed(1)}%',
              sub: '${_wins}W • ${_losses}L',
              valueColor: _ink,
            ),
            _kpiTile(
              icon: Icons.zoom_in_rounded,
              label: 'Profit Factor',
              value: pfText,
              sub: '${_compact(_grossProfit)} / ${_compact(-_grossLossAbs)} gross',
              valueColor: _ink,
            ),
            _kpiTile(
              icon: Icons.straighten_rounded,
              label: 'Expectancy (R)',
              value: expText,
              sub: rAvailable
                  ? '${_avgWinR.toStringAsFixed(1)}R W / -${_avgLossR.toStringAsFixed(1)}R L'
                  : 'No SL data to compute R',
              valueColor: (_expectancyR ?? 0) >= 0 ? _mint : _coral,
            ),
          ],
        );
      },
    );
  }

  Widget _kpiTile({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color valueColor,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: _mint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: _muted, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            sub,
            style: const TextStyle(color: _muted, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _disciplineCard({
    required double? percent,
    required int honored,
    required int violated,
    required int total,
    required int departures,
    required double? followedWr,
    required double? violatedWr,
    required int followedCount,
    required int violatedCount,
  }) {
    final gauge = (percent ?? 0).clamp(0.0, 100.0) / 100.0;
    final percentText =
        percent == null ? '—' : '${percent.toStringAsFixed(0)}%';
    final ruleText = total == 0
        ? 'No rules logged yet'
        : '$honored of $total rules honored';

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _surfaceLow,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: _mint,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discipline Index',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Execution process adherence',
                      style: TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (percent != null && percent >= 85)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _green),
                  ),
                  child: const Text(
                    'Institutional Grade',
                    style: TextStyle(
                      color: _green,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 78,
                      height: 78,
                      child: CircularProgressIndicator(
                        value: gauge,
                        strokeWidth: 8,
                        backgroundColor: _border,
                        valueColor: const AlwaysStoppedAnimation<Color>(_mint),
                      ),
                    ),
                    Text(
                      percentText,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ruleText,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      departures == 0
                          ? 'No emotional departures detected'
                          : '$departures emotional departures detected',
                      style: const TextStyle(color: _muted, fontSize: 11),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: gauge,
                      minHeight: 5,
                      backgroundColor: _surfaceLow,
                      valueColor: const AlwaysStoppedAnimation<Color>(_mint),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _disciplineMetric(
                  icon: Icons.check_circle_outline,
                  label: 'Followed Rules',
                  value: followedWr == null
                      ? '—'
                      : '${followedWr.toStringAsFixed(1)}%',
                  sub: 'Win rate on $followedCount setups',
                  color: _green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _disciplineMetric(
                  icon: Icons.warning_amber_rounded,
                  label: 'Violated Rules',
                  value: violatedWr == null
                      ? '—'
                      : '${violatedWr.toStringAsFixed(1)}%',
                  sub: 'Win rate on $violatedCount deviations',
                  color: _coral,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _disciplineMetric({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: _muted, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(color: _muted, fontSize: 9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _equityCard(double? net) {
    final values = _equityCurve;
    final hasCurve = values.length > 1;
    final peak = values.fold<double>(0.0, (m, v) => math.max(m, v.abs()));

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cumulative Growth Curve',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Net P&L progress over ${_filteredTrades.length} closed trades',
                      style: const TextStyle(color: _muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              if (net != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border),
                  ),
                  child: Text(
                    _money(net, sign: true),
                    style: TextStyle(
                      color: net >= 0 ? _mint : _coral,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (hasCurve)
            SizedBox(
              height: 180,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _EquityChartPainter(values: values),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Text(
                      _compact(peak),
                      style: const TextStyle(color: _muted, fontSize: 9),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    bottom: 20,
                    child: Text(
                      '0',
                      style: TextStyle(color: _muted, fontSize: 9),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              height: 180,
              alignment: Alignment.center,
              child: const Text(
                'No curve available for this timeframe.',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Day 1',
                style: TextStyle(color: _muted, fontSize: 9),
              ),
              Text(
                'Day ${values.length - 1}',
                style: const TextStyle(color: _muted, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _strategyCard() {
    final assigned = _strategyPlaybooks;
    final savedRows = _savedStrategyNames
        .where((name) => !assigned.any((p) => p.name == name))
        .map(
          (name) => _StrategyPerf(
            name: name,
            trades: 0,
            winRate: 0,
            avgR: 0,
            netPnl: 0,
          ),
        )
        .toList();
    final rows = [...assigned, ...savedRows].take(6).toList();
    final total = rows.fold<double>(0.0, (s, p) => s + p.netPnl);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Strategy Playbooks',
                style: TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Sorted by Net P&L',
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Assign strategies in Trade Detail to populate this ledger.',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: _border),
                    ),
                  _strategyRow(rows[i], i, total),
                ],
              ],
            ),
        ],
      ),
    );
  }

  Widget _strategyRow(_StrategyPerf p, int index, double total) {
    final contribution = total > 0 ? p.netPnl / total * 100 : 0.0;
    final pnlColor = p.netPnl >= 0 ? _mint : _coral;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      p.name,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (index == 0 && p.trades > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceLow,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: _mint),
                      ),
                      child: const Text(
                        'Primary',
                        style: TextStyle(
                          color: _mint,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Text(
                p.trades == 0
                    ? '0 trades • — WR • — avg R'
                    : '${p.trades} trades • ${p.winRate.toStringAsFixed(0)}% WR • ${p.avgR.toStringAsFixed(1)}R avg',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _money(p.netPnl, sign: true),
              style: TextStyle(
                color: pnlColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${contribution.toStringAsFixed(1)}% Contribution',
              style: const TextStyle(color: _muted, fontSize: 9),
            ),
          ],
        ),
      ],
    );
  }

  Widget _sessionCard() {
    final rows = _sessionPerformance;
    final peak = rows.fold<double>(
      0.0,
      (m, p) => math.max(m, p.netPnl.abs()),
    );
    _SessionPerf? worst;
    for (final p in rows) {
      if (p.netPnl < 0 && (worst == null || p.netPnl < worst.netPnl)) {
        worst = p;
      }
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: _mint, size: 17),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Session Performance',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _zoneToggle(),
            ],
          ),
          const SizedBox(height: 14),
          if (rows.every((p) => p.netPnl == 0 && p.winRate == 0))
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No closed trades in this timeframe.',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${rows[i].name} (${rows[i].winRate.toStringAsFixed(0)}% WR)',
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _money(rows[i].netPnl, sign: true),
                            style: TextStyle(
                              color: rows[i].netPnl >= 0 ? _mint : _coral,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      SizedBox(
                        height: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value:
                                peak == 0 ? 0 : rows[i].netPnl.abs() / peak,
                            backgroundColor: _surfaceLow,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              rows[i].netPnl >= 0 ? _mint : _coral,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surfaceLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: _mint, size: 16),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    worst == null
                        ? 'No statistical leak detected in this timeframe. Protect the edge by keeping the current session filters.'
                        : 'Statistical leak detected: Discontinue ${worst.name} entries or adjust parameter filters to protect monthly edge.',
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 10,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoneToggle() {
    Widget button(String label, _SessionZone zone) {
      final active = _zone == zone;
      return GestureDetector(
        onTap: () => setState(() => _zone = zone),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active ? _mint : _surfaceLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? _mint : _border),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? _bg : _muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button('UTC', _SessionZone.utc),
        const SizedBox(width: 4),
        button('EST', _SessionZone.est),
      ],
    );
  }

  Widget _exportButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _exportReport,
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text(
          'Export Audit Report (PDF / CSV)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _mint,
          foregroundColor: _bg,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(14),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }
}

class _EquityChartPainter extends CustomPainter {
  final List<double> values;

  const _EquityChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 8.0;
    const right = 8.0;
    const top = 12.0;
    const bottom = 18.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    if (chartWidth <= 0 || chartHeight <= 0 || values.isEmpty) return;

    final low = values.fold<double>(0.0, (a, b) => math.min(a, b));
    final high = values.fold<double>(0.0, (a, b) => math.max(a, b));
    final span = math.max(1.0, high - low);

    double x(int i) => values.length == 1
        ? left + chartWidth / 2
        : left + (i / (values.length - 1)) * chartWidth;
    double y(double v) => top + chartHeight - ((v - low) / span) * chartHeight;

    final gridPaint = Paint()
      ..color = _border
      ..strokeWidth = 1;
    for (final v in [low, (low + high) / 2, high]) {
      final gy = y(v);
      canvas.drawLine(
        Offset(left, gy),
        Offset(left + chartWidth, gy),
        gridPaint,
      );
    }

    final points = [
      for (var i = 0; i < values.length; i++) Offset(x(i), y(values[i])),
    ];

    final fillPath = Path()..moveTo(points.first.dx, y(low));
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath
      ..lineTo(points.last.dx, y(low))
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x52B7F7C4), Color(0x00B7F7C4)],
        ).createShader(
          Rect.fromLTWH(left, top, chartWidth, chartHeight),
        ),
    );

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final mid = Offset(
        (prev.dx + curr.dx) / 2,
        (prev.dy + curr.dy) / 2,
      );
      linePath.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    linePath.lineTo(points.last.dx, points.last.dy);
    canvas.drawPath(
      linePath,
      Paint()
        ..color = _mint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (final p in points) {
      canvas.drawCircle(p, 2.6, Paint()..color = _bg);
      canvas.drawCircle(p, 2.0, Paint()..color = _mint);
    }
  }

  @override
  bool shouldRepaint(covariant _EquityChartPainter oldDelegate) =>
      oldDelegate.values != values;
}
