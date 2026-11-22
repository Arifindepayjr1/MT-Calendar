import 'package:flutter/material.dart';
import 'package:trader_log/model/journal.model.dart';
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/screens/trade_detail.screen.dart';

const bg = Color(0xFF101310),
    surface = Color(0xFF1A1F1B),
    mint = Color(0xFFB7F7C4),
    green = Color(0xFF162319),
    coral = Color(0xFFFF7C7C),
    red = Color(0xFF261517),
    muted = Color(0xFF858D86),
    border = Color(0xFF303832),
    ink = Color(0xFFE8ECE8);

class CalendarScreen extends StatefulWidget {
  final List<Trade> trades;
  final String accountName, brokerAndNumber, currency;
  final double initialDeposit;
  final Map<String, String> dayNotes;
  final Map<String, Journal> journals;
  final void Function(String, String) onDayNoteChanged;
  final void Function(String, Journal) onJournalChanged;
  final VoidCallback onGoHome;
  const CalendarScreen({
    super.key,
    required this.trades,
    required this.accountName,
    required this.brokerAndNumber,
    required this.currency,
    required this.initialDeposit,
    required this.dayNotes,
    required this.journals,
    required this.onDayNoteChanged,
    required this.onJournalChanged,
    required this.onGoHome,
  });
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ],
      weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  late DateTime month, selected;
  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    month = DateTime(n.year, n.month);
    selected = DateTime(n.year, n.month, n.day);
  }

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  List<Trade> get _month => widget.trades.where((t) {
    final d = t.closeTime.toLocal();
    return d.year == month.year && d.month == month.month;
  }).toList();
  Map<int, List<Trade>> get _days {
    final m = <int, List<Trade>>{};
    for (final t in _month) {
      m.putIfAbsent(t.closeTime.toLocal().day, () => []).add(t);
    }
    return m;
  }

  double _sum(Iterable<Trade> a) => a.fold(0.0, (s, t) => s + t.netProfit);
  String _money(double n, {bool sign = false}) {
    final p = sign ? (n < 0 ? '-' : '+') : (n < 0 ? '-' : '');
    final a = n.abs().toStringAsFixed(2);
    return widget.currency.toUpperCase() == 'USD'
        ? '$p\$$a'
        : '$p$a ${widget.currency}';
  }

  String _short(double n) {
    final s = n < 0 ? '-' : '+';
    final a = n.abs();
    if (a >= 1000000) return '$s${(a / 1000000).toStringAsFixed(1)}m';
    if (a >= 10000) return '$s${(a / 1000).toStringAsFixed(0)}k';
    if (a >= 1000) return '$s${(a / 1000).toStringAsFixed(1)}k';
    return '$s${a.toStringAsFixed(0)}';
  }

  void _shift(int n) {
    setState(() {
      month = DateTime(month.year, month.month + n);
      final max = DateTime(month.year, month.month + 1, 0).day;
      selected = DateTime(month.year, month.month, selected.day.clamp(1, max));
    });
  }

  @override
  Widget build(BuildContext context) {
    final trades = _month, days = _days, pnl = _sum(trades);
    final wins = trades.where((t) => t.outcome == TradeOutcome.win).length,
        loss = trades.where((t) => t.outcome == TradeOutcome.loss).length,
        be = trades.length - wins - loss;
    final wr = trades.isEmpty ? 0.0 : wins / trades.length * 100;
    final up = days.values.where((v) => _sum(v) > 0).length,
        down = days.values.where((v) => _sum(v) < 0).length;
    final rate = up + down == 0 ? 0.0 : up / (up + down) * 100;
    final gw = trades
            .where((t) => t.netProfit > 0)
            .fold<double>(0, (s, t) => s + t.netProfit),
        gl = trades
            .where((t) => t.netProfit < 0)
            .fold<double>(0, (s, t) => s + t.netProfit.abs());
    final pf = gl == 0 ? null : gw / gl;
    final today = (days[selected.day] ?? <Trade>[])
      ..sort((a, b) => a.openTime.compareTo(b.openTime));
    final ordinal = days.keys.where((d) => d <= selected.day).length;
    final offset = DateTime(month.year, month.month, 1).weekday - 1,
        count = DateTime(month.year, month.month + 1, 0).day,
        rows = ((offset + count) / 7).ceil();
    final rowCount = rows < 5 ? 5 : rows;
    final ret = widget.initialDeposit > 0
        ? pnl / widget.initialDeposit * 100
        : 0.0;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _heading(),
                  const SizedBox(height: 18),
                  _account(),
                  const SizedBox(height: 18),
                  _summary(pnl, ret, wr, trades.length),
                  const SizedBox(height: 20),
                  _calendar(days, offset, count, rowCount),
                  const SizedBox(height: 18),
                  _kpis(trades.length, wins, loss, be, wr, up, down, rate, pf),
                  const SizedBox(height: 24),
                  _session(today, _sum(today), ordinal, _key(selected)),
                  if (trades.isEmpty) ...[
                    const SizedBox(height: 14),
                    _importPrompt(),
                  ],
                  const SizedBox(height: 14),
                  if (today.isEmpty)
                    _rest(_key(selected))
                  else ...[
                    _reflection(_key(selected)),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Executions',
                          style: TextStyle(
                            color: ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${today.length} trades',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...today.map(_tradeCard),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: mint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.show_chart_rounded, color: bg, size: 17),
          ),
          const SizedBox(width: 8),
          const Text(
            'TRADELOG',
            style: TextStyle(
              color: ink,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
        ],
      ),
      const SizedBox(height: 13),
      const Text(
        'Calendar',
        style: TextStyle(color: ink, fontSize: 26, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 4),
      const Text(
        'Track your trading performance',
        style: TextStyle(color: muted, fontSize: 13),
      ),
    ],
  );
  Widget _account() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: border),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.account_balance_wallet_outlined,
          color: mint,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${widget.accountName} · ${widget.brokerAndNumber}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ink, fontSize: 11),
          ),
        ),
        const Icon(Icons.expand_more_rounded, color: muted, size: 18),
      ],
    ),
  );
  Widget _summary(double pnl, double ret, double wr, int n) {
    final c = pnl < 0 ? coral : mint;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        gradient: LinearGradient(colors: [c.withValues(alpha: .1), surface]),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _shift(-1),
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous month',
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${months[month.month - 1]} ${month.year}',
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const Text(
                      'MONTHLY PERFORMANCE',
                      style: TextStyle(
                        color: muted,
                        fontSize: 9,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _shift(1),
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next month',
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Net P&L',
                      style: TextStyle(color: muted, fontSize: 11),
                    ),
                    Text(
                      _money(pnl, sign: true),
                      style: TextStyle(
                        color: c,
                        fontWeight: FontWeight.w800,
                        fontSize: 27,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${ret >= 0 ? '+' : ''}${ret.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: c,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    'Estimated return',
                    style: TextStyle(color: muted, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: border),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.trending_up, color: mint, size: 15),
              const SizedBox(width: 6),
              Text(
                '${wr.toStringAsFixed(1)}% win rate',
                style: const TextStyle(color: ink, fontSize: 11),
              ),
              const Spacer(),
              Text(
                '$n closed trades',
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _calendar(
    Map<int, List<Trade>> days,
    int offset,
    int count,
    int rows,
  ) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: border),
    ),
    child: Column(
      children: [
        Row(
          children: List.generate(
            7,
            (i) => Expanded(
              child: Center(
                child: Text(
                  weekdays[i],
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...List.generate(
          rows,
          (r) => SizedBox(
            height: 64,
            child: Row(
              children: List.generate(7, (c) {
                final d = r * 7 + c - offset + 1;
                if (d < 1 || d > count) {
                  return const Expanded(child: SizedBox());
                }
                return Expanded(
                  child: _day(
                    DateTime(month.year, month.month, d),
                    days[d] ?? const <Trade>[],
                    c > 4,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend(mint, 'Profit'),
            const SizedBox(width: 12),
            _legend(coral, 'Loss'),
            const SizedBox(width: 12),
            _legend(muted, 'No trades'),
          ],
        ),
      ],
    ),
  );
  Widget _day(DateTime date, List<Trade> ts, bool weekend) {
    final chosen =
            date.year == selected.year &&
            date.month == selected.month &&
            date.day == selected.day,
        pnl = _sum(ts),
        up = pnl > 0,
        down = pnl < 0;
    final fill = chosen
            ? mint
            : up
            ? green
            : down
            ? red
            : Colors.transparent,
        fg = chosen
            ? bg
            : ts.isNotEmpty
            ? ink
            : weekend
            ? muted.withValues(alpha: .6)
            : muted;
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: () => setState(() => selected = date),
          child: Column(
            children: [
              const SizedBox(height: 5),
              Text(
                '${date.day}',
                style: TextStyle(
                  color: fg,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              if (ts.isNotEmpty)
                Text(
                  _short(pnl),
                  style: TextStyle(
                    color: chosen
                        ? bg
                        : up
                        ? mint
                        : down
                        ? coral
                        : ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  ts.length.clamp(0, 3),
                  (_) => Container(
                    margin: const EdgeInsets.only(bottom: 5, left: 1, right: 1),
                    width: 3,
                    height: 3,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: chosen
                          ? bg
                          : up
                          ? mint
                          : down
                          ? coral
                          : muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legend(Color c, String s) => Row(
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text(s, style: const TextStyle(color: muted, fontSize: 9)),
    ],
  );
  Widget _kpis(
    int n,
    int w,
    int l,
    int be,
    double wr,
    int up,
    int down,
    double rate,
    double? pf,
  ) => Column(
    children: [
      Row(
        children: [
          Expanded(
            child: _kpi(
              'TOTAL TRADES',
              '$n',
              '$w wins · $l losses · $be BE',
              Icons.swap_vert,
              mint,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _kpi(
              'WIN RATE',
              '${wr.toStringAsFixed(1)}%',
              '$w wins / $n trades',
              Icons.track_changes,
              mint,
            ),
          ),
        ],
      ),
      const SizedBox(height: 9),
      Row(
        children: [
          Expanded(
            child: _kpi(
              'TRADING DAYS',
              '$up / ${up + down}',
              '$up profit · $down loss · ${rate.toStringAsFixed(0)}% up',
              Icons.calendar_today,
              mint,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: _kpi(
              'PROFIT FACTOR',
              pf?.toStringAsFixed(2) ?? '—',
              pf == null
                  ? 'Unavailable without losses'
                  : 'Gross wins / gross losses',
              Icons.auto_graph,
              pf == null ? muted : mint,
            ),
          ),
        ],
      ),
    ],
  );
  Widget _kpi(String t, String v, String sub, IconData icon, Color c) =>
      Container(
        height: 96,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: c),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    t,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              v,
              style: const TextStyle(
                color: ink,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const Spacer(),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted, fontSize: 9),
            ),
          ],
        ),
      );

  Widget _session(List<Trade> ts, double pnl, int ordinal, String k) {
    final w = ts.where((t) => t.outcome == TradeOutcome.win).length,
        l = ts.where((t) => t.outcome == TradeOutcome.loss).length,
        be = ts.length - w - l;
    final realizedRs = ts.map(_realizedR).whereType<double>().toList();
    final averageR = realizedRs.isEmpty
        ? null
        : realizedRs.reduce((a, b) => a + b) / realizedRs.length;
    final date =
        '${weekdays[selected.weekday - 1]} · ${months[selected.month - 1]} ${selected.day}, ${selected.year}';
    final dayLabel = ts.isEmpty ? date : '$date · DAY $ordinal';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DAY SESSION  ·  $dayLabel',
            style: const TextStyle(color: ink, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            _money(pnl, sign: true),
            style: TextStyle(
              color: pnl < 0 ? coral : mint,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${ts.length} trades  ·  $w wins  ·  $l losses  ·  $be break-even',
            style: const TextStyle(color: muted, fontSize: 11),
          ),
          Text(
            averageR == null
                ? 'Average realized R: —'
                : 'Average realized R: ${averageR >= 0 ? '+' : ''}${averageR.toStringAsFixed(2)}R',
            style: const TextStyle(color: muted, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Text(
            'Discipline: Unscored',
            style: const TextStyle(color: muted, fontSize: 10),
          ),
          if ((widget.dayNotes[k] ?? '').isNotEmpty)
            Text(
              widget.dayNotes[k]!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: muted),
            ),
        ],
      ),
    );
  }

  Widget _importPrompt() => Row(
    children: [
      const Expanded(
        child: Text(
          'No executions this month. Import a report from Home to see your results.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ),
      TextButton(onPressed: widget.onGoHome, child: const Text('Home')),
    ],
  );
  Widget _rest(String k) {
    const description = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Rest & Prep Day',
          style: TextStyle(
            color: ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'No executions. 0 impulse trades recorded.',
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
    final action = TextButton.icon(
      icon: const Icon(Icons.edit_note, color: mint),
      label: const Text('Log Plan'),
      onPressed: () => _editDay(k, false),
    );

    return Card(
      color: surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 320) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.self_improvement, color: muted),
                      const SizedBox(width: 12),
                      const Expanded(child: description),
                    ],
                  ),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            }
            return Row(
              children: [
                const Icon(Icons.self_improvement, color: muted),
                const SizedBox(width: 12),
                const Expanded(child: description),
                const SizedBox(width: 4),
                action,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _reflection(String k) => OutlinedButton.icon(
    onPressed: () => _editDay(k, true),
    icon: const Icon(Icons.edit_note),
    label: const Text('Reflection'),
  );
  Future<void> _editDay(String k, bool hasTrades) async {
    final s = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NoteSheet(
        initial: widget.dayNotes[k] ?? '',
        title: hasTrades ? 'Reflection' : 'Log Plan',
      ),
    );
    if (s != null) widget.onDayNoteChanged(k, s);
  }

  Widget _tradeCard(Trade t) {
    final journal = widget.journals[t.id];
    final note = journal?.executionNotes?.trim() ?? '';
    final (outcome, outcomeColor) = switch (t.closeReason) {
      CloseReason.takeProfit => ('TP HIT', mint),
      CloseReason.stopLoss => ('SL HIT', coral),
      CloseReason.manual => ('MANUAL', muted),
      CloseReason.stopOut => ('STOP OUT', coral),
      CloseReason.other => ('OTHER', muted),
      CloseReason.unknown => ('UNKNOWN', muted),
    };
    final title = Text(
      '${t.symbol} · ${t.type.name.toUpperCase()} · ${t.volume}L',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
    final subtitle = Text(
      '#${t.ticket}  ${t.openTime} → ${t.closeTime}\n${t.openPrice} → ${t.closePrice}  ·  R ${_realizedR(t)?.toStringAsFixed(2) ?? '—'}\n${note.isEmpty ? 'Tap to journal this execution' : note}',
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: muted, fontSize: 10),
    );
    final profit = Text(
      _money(t.netProfit, sign: true),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: t.netProfit < 0 ? coral : mint,
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
    final journalHint = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.edit_note, color: mint, size: 13),
        const SizedBox(width: 2),
        Text(
          note.isEmpty ? 'Journal' : 'Edit journal',
          style: const TextStyle(
            color: mint,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    return Card(
      color: surface,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openTradeJournal(t),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 320) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: title),
                        const SizedBox(width: 8),
                        _outcomeBadge(outcome, outcomeColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    subtitle,
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(child: profit),
                        const SizedBox(width: 8),
                        journalHint,
                      ],
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [title, subtitle],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 132,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _outcomeBadge(outcome, outcomeColor),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(child: profit),
                            const SizedBox(width: 8),
                            journalHint,
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _outcomeBadge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .4)),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: .3,
      ),
    ),
  );

  void _openTradeJournal(Trade trade) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TradeDetailScreen(
          trade: trade,
          currency: widget.currency,
          accountLabel: widget.brokerAndNumber,
          initialJournal: widget.journals[trade.id],
          onJournalSaved: (journal) =>
              widget.onJournalChanged(trade.id, journal),
        ),
      ),
    );
  }

  double? _realizedR(Trade trade) {
    final stop = trade.stoploss;
    if (stop == null || stop <= 0) return null;
    final risk = (trade.openPrice - stop).abs();
    if (risk == 0) return null;
    final move = trade.type == TradeType.buy
        ? trade.closePrice - trade.openPrice
        : trade.openPrice - trade.closePrice;
    return move / risk;
  }
}

class _NoteSheet extends StatefulWidget {
  final String initial, title;
  const _NoteSheet({required this.initial, required this.title});
  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  late final c = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 18,
      right: 18,
      top: 18,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 18,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: const TextStyle(color: ink, fontSize: 18)),
        TextField(
          controller: c,
          minLines: 5,
          maxLines: 8,
          decoration: const InputDecoration(
            hintText: 'Write a note for this day',
          ),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, c.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
