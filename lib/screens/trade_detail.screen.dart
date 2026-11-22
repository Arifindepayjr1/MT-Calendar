import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:trader_log/model/journal.model.dart';
import 'package:trader_log/model/trade.model.dart';
import 'package:trader_log/seed/strategy.seed.dart';
import 'package:trader_log/widgets/trade_candlestick_chart.dart';

const _bg = Color(0xFF101310);
const _surface = Color(0xFF1A1F1B);
const _mint = Color(0xFFB7F7C4);
const _coral = Color(0xFFFF7C7C);
const _muted = Color(0xFF858D86);
const _border = Color(0xFF303832);
const _ink = Color(0xFFE8ECE8);

class TradeDetailScreen extends StatefulWidget {
  final Trade trade;
  final String currency;
  final String accountLabel;
  final Journal? initialJournal;
  final ValueChanged<Journal> onJournalSaved;

  const TradeDetailScreen({
    super.key,
    required this.trade,
    required this.currency,
    required this.accountLabel,
    required this.initialJournal,
    required this.onJournalSaved,
  });

  @override
  State<TradeDetailScreen> createState() => _TradeDetailScreenState();
}

class _TradeDetailScreenState extends State<TradeDetailScreen> {
  static const _sessionOptions = [
    'Asia',
    'London',
    'New York',
    'London–New York overlap',
  ];
  static const _rules = [
    'Entry matched my written plan',
    'Risk stayed within my limit',
    'I respected my exit rules',
  ];

  late final TextEditingController _narrative;
  late final TextEditingController _execution;
  late final TextEditingController _takeaway;
  MarketBias? _bias;
  EmotionalState? _emotion;
  double? _grade;
  double? _preEntry;
  double? _holding;
  late List<bool> _checkedRules;
  late List<String> _attachments;
  late Set<String> _selectedStrategyNames;
  late Map<String, String> _strategyIdsByName;
  late Set<String> _selectedSessions;
  Journal? _journal;
  bool _editing = false;
  final GlobalKey _journalSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final j = widget.initialJournal;
    _journal = j;
    final strategyNames =
        j?.strategyNames ??
        <String>[if (j?.strategyName != null) j!.strategyName!];
    final strategyIds = j?.strategyIds ?? <String?>[j?.strategyId];
    _selectedStrategyNames = strategyNames.toSet();
    _strategyIdsByName = {
      for (var index = 0; index < strategyNames.length; index++)
        if (index < strategyIds.length && strategyIds[index] != null)
          strategyNames[index]: strategyIds[index]!,
    };
    _selectedSessions = (j?.tradingSession ?? '')
        .split(',')
        .map((session) => _normalizeSession(session.trim()))
        .where((session) => session.isNotEmpty)
        .toSet();
    _narrative = TextEditingController(text: j?.sessionNarrative ?? '');
    _execution = TextEditingController(text: j?.executionNotes ?? '');
    _takeaway = TextEditingController(text: j?.lessonLearned ?? '');
    _bias = j?.marketBias;
    _emotion = j?.emotionalState;
    _grade = j?.disciplineGrade;
    _preEntry = j?.preEntryRating;
    _holding = j?.tradeHoldingRating;
    _checkedRules = List.generate(
      _rules.length,
      (i) => j?.rulesFollowed?.contains(_rules[i]) ?? false,
    );
    _attachments = [...?j?.attachments];
    if (j?.screenshots != null && !_attachments.contains(j!.screenshots)) {
      _attachments.insert(0, j.screenshots!);
    }
  }

  @override
  void dispose() {
    _narrative.dispose();
    _execution.dispose();
    _takeaway.dispose();
    super.dispose();
  }

  String _money(double value, {bool signed = false}) {
    final sign = signed ? (value < 0 ? '−' : '+') : (value < 0 ? '−' : '');
    final amount = value.abs().toStringAsFixed(2);
    return widget.currency.toUpperCase() == 'USD'
        ? '$sign${String.fromCharCode(36)}$amount'
        : '$sign$amount ${widget.currency}';
  }

  double? get _realizedR {
    final stop = widget.trade.stoploss;
    if (stop == null || stop <= 0) return null;
    final risk = (widget.trade.openPrice - stop).abs();
    if (risk == 0) return null;
    final move = widget.trade.type == TradeType.buy
        ? widget.trade.closePrice - widget.trade.openPrice
        : widget.trade.openPrice - widget.trade.closePrice;
    return move / risk;
  }

  bool _isFxPair(String symbol) =>
      RegExp(r'^[A-Z]{6}$').hasMatch(symbol.toUpperCase());

  double? _pips(double? level) {
    if (level == null || !_isFxPair(widget.trade.symbol)) return null;
    final pip = widget.trade.symbol.toUpperCase().contains('JPY')
        ? 0.01
        : 0.0001;
    return (level - widget.trade.openPrice).abs() / pip;
  }

  int get _digits => widget.trade.symbol.toUpperCase().contains('JPY') ? 3 : 5;
  String _price(double? value) =>
      value == null ? '--' : value.toStringAsFixed(_digits);

  String get _closeStatus => switch (widget.trade.closeReason) {
    CloseReason.takeProfit => 'TP HIT',
    CloseReason.stopLoss => 'SL HIT',
    CloseReason.manual => 'MANUAL',
    CloseReason.stopOut => 'STOP OUT',
    CloseReason.other => 'OTHER EXIT',
    CloseReason.unknown => 'UNKNOWN',
  };

  String get _outcome => switch (widget.trade.outcome) {
    TradeOutcome.win => 'WIN',
    TradeOutcome.loss => 'LOSS',
    TradeOutcome.breakeven => 'BREAK EVEN',
  };

  Color get _resultColor => switch (widget.trade.outcome) {
    TradeOutcome.win => _mint,
    TradeOutcome.loss => _coral,
    TradeOutcome.breakeven => _muted,
  };

  Color get _closeStatusColor => switch (widget.trade.closeReason) {
    CloseReason.takeProfit => _mint,
    CloseReason.stopLoss || CloseReason.stopOut => _coral,
    CloseReason.manual || CloseReason.other || CloseReason.unknown => _muted,
  };

  String? _nullable(String text) => text.trim().isEmpty ? null : text.trim();

  @override
  Widget build(BuildContext context) {
    final duration = widget.trade.closeTime.difference(widget.trade.openTime);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  _header(),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                      children: [
                        _performanceCard(duration),
                        const SizedBox(height: 16),
                        _marketChartSection(),
                        const SizedBox(height: 16),
                        _telemetryCard(),
                        const SizedBox(height: 16),
                        _journalSection(),
                        const SizedBox(height: 16),
                        _attachmentsSection(),
                      ],
                    ),
                  ),
                  _stickyAction(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 18, 8),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
          tooltip: 'Back',
        ),
        const Expanded(
          child: Text(
            'Trade Details',
            style: TextStyle(
              color: _ink,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const CircleAvatar(
          radius: 17,
          backgroundColor: _surface,
          child: Icon(Icons.person_outline_rounded, color: _mint, size: 19),
        ),
      ],
    ),
  );

  Widget _performanceCard(Duration duration) {
    final t = widget.trade;
    final durationText =
        '${duration.inHours}h ${(duration.inMinutes % 60).toString().padLeft(2, '0')}m';
    final r = _realizedR;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.symbol.toUpperCase(),
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _badge(_outcome, _resultColor),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${t.type.name.toUpperCase()}  ${t.volume.toStringAsFixed(2)} Lots',
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(t.netProfit, signed: true),
              style: TextStyle(
                color: _resultColor,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            r == null
                ? 'Realized R unavailable'
                : '${r >= 0 ? '+' : ''}${r.toStringAsFixed(2)} R realized',
            style: const TextStyle(
              color: _ink,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: _border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _timeInfo('OPEN', _dateTime(t.openTime))),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: _muted),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _timeInfo(
                    'CLOSE · $durationText',
                    _dateTime(t.closeTime),
                    right: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _badge(_closeStatus, _closeStatusColor),
        ],
      ),
    );
  }

  Widget _timeInfo(String label, String value, {bool right = false}) => Column(
    crossAxisAlignment: right
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: _muted,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        style: const TextStyle(
          color: _ink,
          fontSize: 11,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  );

  String _dateTime(DateTime value) {
    final d = value.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}:${two(d.second)} · ${two(d.day)}/${two(d.month)}/${d.year}';
  }

  List<String> get _chartStrategyNames {
    final names = _journal?.strategyNames;
    if (names != null && names.isNotEmpty) return names;
    final legacyName = _journal?.strategyName;
    return legacyName == null ? const [] : [legacyName];
  }

  Widget _marketChartSection() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          'Candlestick Chart',
          trailing: _badge('HISTORICAL FEED', _muted),
        ),
        const SizedBox(height: 5),
        const Text(
          'Advanced mode fetches real historical candles around the trade and marks only three levels: white entry, red stop loss and green take profit. Use the full-screen button to inspect where price touched SL or TP; Simple mode is the lightweight native view.',
          style: TextStyle(color: _muted, fontSize: 11, height: 1.4),
        ),
        TradeCandlestickChart(
          trade: widget.trade,
          strategyNames: _chartStrategyNames,
        ),
      ],
    ),
  );

  Widget _telemetryCard() {
    final t = widget.trade;
    final sl = _pips(t.stoploss);
    final tp = _pips(t.takeProfit);
    final rr = sl != null && tp != null && sl > 0
        ? '1 : ${(tp / sl).toStringAsFixed(2)}'
        : '--';
    final realized = _realizedR;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'MT5 Execution Telemetry',
            trailing: _badge('MT5 REPORT', _mint),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.account_balance_outlined,
                color: _mint,
                size: 16,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  widget.accountLabel,
                  style: const TextStyle(color: _ink, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _badge('EA VERIFICATION UNAVAILABLE', _muted),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final metricWidth = (constraints.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _metric('TICKET ID', t.ticket, metricWidth),
                  _metric('ENTRY PRICE', _price(t.openPrice), metricWidth),
                  _metric('EXIT PRICE', _price(t.closePrice), metricWidth),
                  _metric(
                    'STOP LOSS',
                    t.stoploss == null
                        ? '--'
                        : '${sl?.toStringAsFixed(1) ?? '--'} pips · ${_price(t.stoploss)}',
                    metricWidth,
                  ),
                  _metric(
                    'TAKE PROFIT',
                    t.takeProfit == null
                        ? '--'
                        : '${tp?.toStringAsFixed(1) ?? '--'} pips · ${_price(t.takeProfit)}',
                    metricWidth,
                  ),
                  _metric('COMMISSION', _money(t.commission), metricWidth),
                  _metric('SWAP', _money(t.swap), metricWidth),
                  _metric('FEES', _money(t.fee), metricWidth),
                  _metric('RISK CAPITAL', '--', metricWidth),
                  _metric('PLANNED R:R', rr, metricWidth),
                  _metric(
                    'REALIZED R:R',
                    realized == null
                        ? '--'
                        : '${realized >= 0 ? '+' : ''}${realized.toStringAsFixed(2)}R',
                    metricWidth,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, String value, double width) => SizedBox(
    width: width,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _muted,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _panel({required Widget child}) => Material(
    color: _surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: _border),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );

  Widget _sectionHeading(String title, {Widget? trailing}) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      ?trailing,
    ],
  );

  Widget _badge(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      border: Border.all(color: color.withValues(alpha: .35)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 8,
        letterSpacing: .4,
        fontWeight: FontWeight.w800,
      ),
    ),
  );

  Widget _journalSection() => KeyedSubtree(
    key: _journalSectionKey,
    child: _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeading(
            'Journal & Psychology',
            trailing: _badge(
              _journal == null ? 'NO JOURNAL YET' : 'JOURNALED',
              _journal == null ? _muted : _mint,
            ),
          ),
          if (_editing) ..._journalForm() else ..._journalSummary(_journal),
        ],
      ),
    ),
  );

  void _startEditing() {
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sectionContext = _journalSectionKey.currentContext;
      if (mounted && sectionContext != null) {
        Scrollable.ensureVisible(
          sectionContext,
          alignment: 0.04,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
        );
      }
    });
  }

  List<Widget> _journalSummary(Journal? journal) {
    if (journal == null) {
      return [
        const SizedBox(height: 12),
        const Text(
          'Add setup, mindset, and execution notes for this trade.',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.5),
        ),
      ];
    }
    final rulesFollowed = journal.rulesFollowed ?? const <String>[];
    return [
      const SizedBox(height: 12),
      _summaryLine(
        'STRATEGY',
        journal.strategyNames?.isNotEmpty == true
            ? journal.strategyNames!.join(', ')
            : journal.strategyName ?? '--',
      ),
      _summaryLine('4H MARKET BIAS', _title(journal.marketBias?.name)),
      _summaryLine('TRADING SESSION', journal.tradingSession ?? '--'),
      _summaryLine('SESSION NOTES', journal.sessionNarrative ?? '--'),
      _summaryLine('EMOTION', _title(journal.emotionalState?.name)),
      _summaryLine(
        'DISCIPLINE',
        journal.disciplineGrade == null
            ? '--'
            : '${journal.disciplineGrade!.toStringAsFixed(1)} / 10',
      ),
      _summaryLine(
        'PRE-ENTRY / HOLDING',
        '${_rating(journal.preEntryRating)} / ${_rating(journal.tradeHoldingRating)}',
      ),
      _summaryLine('RULES', '${rulesFollowed.length} of 3 followed'),
      ..._rules.map(
        (rule) => Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: Row(
            children: [
              Icon(
                rulesFollowed.contains(rule)
                    ? Icons.check_circle_outline
                    : Icons.radio_button_unchecked,
                size: 14,
                color: rulesFollowed.contains(rule) ? _mint : _muted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rule,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
      _summaryLine('EXECUTION', journal.executionNotes ?? '--'),
      _summaryLine('KEY TAKEAWAY', journal.lessonLearned ?? '--'),
    ];
  }

  String _rating(double? value) =>
      value == null ? '--' : '${value.toStringAsFixed(1)} / 10';

  String _title(String? value) {
    if (value == null || value.isEmpty) return '--';
    final spaced = value.replaceAllMapped(
      RegExp(r'([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    return '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  String _normalizeSession(String session) => switch (session.toLowerCase()) {
    'asian' || 'asia' => 'Asia',
    'london' => 'London',
    'newyork' || 'new york' => 'New York',
    'londonnewyorkoverlap' ||
    'london new york overlap' ||
    'london–new york overlap' => 'London–New York overlap',
    _ => session,
  };

  List<String> get _strategyOptions => {
    ...seedStrategies.map((strategy) => strategy.name),
    ..._selectedStrategyNames,
  }.toList();

  List<String> get _orderedSelectedStrategyNames => [
    ...seedStrategies
        .map((strategy) => strategy.name)
        .where(_selectedStrategyNames.contains),
    ..._selectedStrategyNames.where(
      (name) => !seedStrategies.any((strategy) => strategy.name == name),
    ),
  ];

  String? _strategyIdForName(String name) {
    for (final strategy in seedStrategies) {
      if (strategy.name == name) return strategy.id;
    }
    return _strategyIdsByName[name];
  }

  List<String> get _orderedSelectedSessions => [
    ..._sessionOptions.where(_selectedSessions.contains),
    ..._selectedSessions.where((session) => !_sessionOptions.contains(session)),
  ];

  Widget _strategySelector() => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final strategy in _strategyOptions)
        FilterChip(
          label: Text(strategy),
          selected: _selectedStrategyNames.contains(strategy),
          selectedColor: _mint,
          side: BorderSide(
            color: _selectedStrategyNames.contains(strategy) ? _mint : _border,
          ),
          labelStyle: TextStyle(
            color: _selectedStrategyNames.contains(strategy) ? _bg : _ink,
            fontSize: 12,
          ),
          onSelected: (selected) => setState(() {
            if (selected) {
              _selectedStrategyNames.add(strategy);
            } else {
              _selectedStrategyNames.remove(strategy);
            }
          }),
        ),
    ],
  );

  Widget _sessionSelector() => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final session in {..._sessionOptions, ..._selectedSessions})
        FilterChip(
          label: Text(session),
          selected: _selectedSessions.contains(session),
          selectedColor: _mint,
          side: BorderSide(
            color: _selectedSessions.contains(session) ? _mint : _border,
          ),
          labelStyle: TextStyle(
            color: _selectedSessions.contains(session) ? _bg : _ink,
            fontSize: 12,
          ),
          onSelected: (selected) => setState(() {
            if (selected) {
              _selectedSessions.add(session);
            } else {
              _selectedSessions.remove(session);
            }
          }),
        ),
    ],
  );

  List<Widget> _journalForm() => [
    const SizedBox(height: 14),
    _fieldLabel('STRATEGY / PLAYBOOK'),
    _strategySelector(),
    const SizedBox(height: 12),
    _fieldLabel('4H MARKET BIAS'),
    _dropdown<MarketBias>(
      _bias,
      MarketBias.values,
      (v) => _title(v.name),
      (v) => setState(() => _bias = v),
    ),
    const SizedBox(height: 12),
    _fieldLabel('TRADING SESSION'),
    _sessionSelector(),
    const SizedBox(height: 12),
    _fieldLabel('SESSION NARRATIVE'),
    _textField(_narrative, 'Describe the context around this trade', lines: 2),
    const SizedBox(height: 12),
    _fieldLabel('EMOTIONAL STATE'),
    _dropdown<EmotionalState>(
      _emotion,
      EmotionalState.values,
      (v) => _title(v.name),
      (v) => setState(() => _emotion = v),
    ),
    const SizedBox(height: 12),
    _ratingSlider(
      'OVERALL DISCIPLINE GRADE',
      _grade,
      (v) => setState(() => _grade = v),
      (v) => setState(() => _grade = v),
    ),
    _ratingSlider(
      'PRE-ENTRY',
      _preEntry,
      (v) => setState(() => _preEntry = v),
      (v) => setState(() => _preEntry = v),
    ),
    _ratingSlider(
      'TRADE HOLDING',
      _holding,
      (v) => setState(() => _holding = v),
      (v) => setState(() => _holding = v),
    ),
    const SizedBox(height: 8),
    _fieldLabel('RULE COMPLIANCE'),
    ...List.generate(
      _rules.length,
      (i) => CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: _mint,
        checkColor: _bg,
        value: _checkedRules[i],
        title: Text(
          _rules[i],
          style: const TextStyle(color: _ink, fontSize: 12),
        ),
        onChanged: (value) => setState(() => _checkedRules[i] = value ?? false),
      ),
    ),
    const SizedBox(height: 8),
    _fieldLabel('EXECUTION NOTES'),
    _textField(
      _execution,
      'What happened during entry, management, and exit?',
      lines: 3,
    ),
    const SizedBox(height: 12),
    _fieldLabel('KEY TAKEAWAY'),
    _textField(_takeaway, 'One lesson to carry into the next trade', lines: 2),
  ];

  Widget _ratingSlider(
    String label,
    double? value,
    ValueChanged<double> onChanged,
    ValueChanged<double?> onClear,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: _fieldLabel(label)),
          Text(
            value?.toStringAsFixed(1) ?? '--',
            style: const TextStyle(
              color: _mint,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            tooltip: 'Clear $label rating',
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            padding: EdgeInsets.zero,
            onPressed: value == null ? null : () => onClear(null),
            icon: const Icon(Icons.close_rounded, size: 16),
            color: _muted,
          ),
        ],
      ),
      Slider(
        value: value ?? 0,
        min: 0,
        max: 10,
        divisions: 20,
        activeColor: _mint,
        inactiveColor: _border,
        onChangeStart: value == null ? (_) => onChanged(0) : null,
        onChanged: onChanged,
      ),
    ],
  );

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        color: _muted,
        fontSize: 9,
        letterSpacing: .6,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _textField(
    TextEditingController controller,
    String hint, {
    int lines = 1,
  }) => TextField(
    controller: controller,
    minLines: lines,
    maxLines: lines == 1 ? 1 : 5,
    style: const TextStyle(color: _ink, fontSize: 12),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 11),
      filled: true,
      fillColor: _bg,
      contentPadding: const EdgeInsets.all(11),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _mint),
      ),
    ),
  );

  Widget _dropdown<T extends Enum>(
    T? value,
    List<T> items,
    String Function(T) label,
    ValueChanged<T?> onChanged,
  ) => DropdownButtonFormField<T?>(
    initialValue: value,
    dropdownColor: _surface,
    style: const TextStyle(color: _ink, fontSize: 12),
    decoration: InputDecoration(
      filled: true,
      fillColor: _bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
    ),
    items: [
      DropdownMenuItem<T?>(value: null, child: Text('-- Not set --')),
      ...items.map(
        (item) => DropdownMenuItem<T?>(value: item, child: Text(label(item))),
      ),
    ],
    onChanged: onChanged,
  );

  Widget _summaryLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labelText = Text(
          label,
          style: const TextStyle(
            color: _muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        );
        final valueText = Text(
          value,
          style: const TextStyle(color: _ink, fontSize: 11, height: 1.4),
        );

        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [labelText, const SizedBox(height: 3), valueText],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 112, child: labelText),
            Expanded(child: valueText),
          ],
        );
      },
    ),
  );

  Widget _attachmentsSection() => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('Attachments'),
        const SizedBox(height: 12),
        _chartPanel('BEFORE', '15M Setup', 0),
        const SizedBox(height: 10),
        _chartPanel('AFTER', '1M Execution & Exit', 1),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addScreenshots,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: const Text('+ Add Screenshot'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _mint,
              side: const BorderSide(color: _border),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (_attachments.isNotEmpty) ...[
          const SizedBox(height: 4),
          ...List.generate(_attachments.length, _attachmentRow),
        ],
      ],
    ),
  );

  Widget _chartPanel(String eyebrow, String title, int index) {
    final source = index < _attachments.length ? _attachments[index] : null;
    final preview = source == null
        ? _imageUnavailable('No screenshot attached')
        : _attachmentPreview(source);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF090D0B),
          border: Border.all(color: _border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          eyebrow,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          title,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: source == null
                        ? null
                        : () => _showAttachment(source, title),
                    tooltip: 'Open screenshot',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.zoom_in_rounded,
                      color: _mint,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 150,
              width: double.infinity,
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: preview,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
              child: Text(
                source == null
                    ? 'Add a screenshot when ready'
                    : 'Screenshot attached',
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentPreview(
    String source, {
    double height = 150,
    BoxFit fit = BoxFit.cover,
  }) {
    Widget errorBuilder(
      BuildContext context,
      Object error,
      StackTrace? stackTrace,
    ) => _imageUnavailable('Image could not be opened');
    if (source.startsWith('data:image/')) {
      final separator = source.indexOf(',');
      if (separator < 0) return _imageUnavailable('Image could not be opened');
      try {
        return Image.memory(
          base64Decode(source.substring(separator + 1)),
          fit: fit,
          width: double.infinity,
          height: height,
          errorBuilder: errorBuilder,
        );
      } on FormatException {
        return _imageUnavailable('Image could not be opened');
      }
    }

    final uri = Uri.tryParse(source);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      return Image.network(
        source,
        fit: fit,
        width: double.infinity,
        height: height,
        errorBuilder: errorBuilder,
      );
    }
    return _imageUnavailable('Image unavailable on this device');
  }

  Widget _imageUnavailable(String message) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.image_outlined, color: _muted, size: 24),
        const SizedBox(height: 7),
        Text(message, style: const TextStyle(color: _muted, fontSize: 10)),
      ],
    ),
  );

  void _showAttachment(String source, String title) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _surface,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: 'Close image',
                    icon: const Icon(Icons.close_rounded, color: _muted),
                  ),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 600),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: _attachmentPreview(
                    source,
                    height: 480,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentRow(int index) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        const Icon(Icons.image_outlined, color: _mint, size: 18),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'Screenshot ${index + 1}',
            style: const TextStyle(color: _ink, fontSize: 11),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: _muted, size: 17),
          tooltip: 'Remove screenshot',
          onPressed: () => setState(() {
            _attachments.removeAt(index);
            _editing = true;
          }),
        ),
      ],
    ),
  );

  Future<void> _addScreenshots() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || !mounted) return;
    final images = result.files
        .where((file) => file.bytes != null)
        .map(
          (file) =>
              'data:${_mimeType(file.name)};base64,${base64Encode(file.bytes!)}',
        )
        .toList();
    if (images.isEmpty) return;
    setState(() {
      _attachments.addAll(images);
      _editing = true;
    });
  }

  String _extension(String name) {
    final dot = name.lastIndexOf('.');
    final extension = dot < 0 || dot == name.length - 1
        ? 'jpg'
        : name.substring(dot + 1).toLowerCase();
    return extension == 'jpg' ? 'jpeg' : extension;
  }

  String _mimeType(String name) {
    final extension = _extension(name);
    return switch (extension) {
      'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'bmp' => 'image/bmp',
      _ => 'image/$extension',
    };
  }

  void _saveJournal() {
    final now = DateTime.now();
    final previous = _journal;
    final selectedStrategyNames = _orderedSelectedStrategyNames;
    final selectedStrategyIds = selectedStrategyNames
        .map(_strategyIdForName)
        .toList();
    final saved = Journal(
      id: previous?.id ?? 'journal-${widget.trade.id}',
      tradeId: widget.trade.id,
      strategyId: selectedStrategyIds.isEmpty
          ? null
          : selectedStrategyIds.first,
      strategyName: selectedStrategyNames.isEmpty
          ? null
          : selectedStrategyNames.first,
      strategyIds: selectedStrategyIds.isEmpty ? null : selectedStrategyIds,
      strategyNames: selectedStrategyNames.isEmpty
          ? null
          : selectedStrategyNames,
      marketBias: _bias,
      tradingSession: _orderedSelectedSessions.isEmpty
          ? null
          : _orderedSelectedSessions.join(', '),
      sessionNarrative: _nullable(_narrative.text),
      entryReason: previous?.entryReason,
      plan: previous?.plan,
      executionNotes: _nullable(_execution.text),
      rulesFollowed: [
        for (var i = 0; i < _checkedRules.length; i++)
          if (_checkedRules[i]) _rules[i],
      ],
      emotionalState: _emotion,
      disciplineGrade: _grade,
      preEntryRating: _preEntry,
      tradeHoldingRating: _holding,
      lessonLearned: _nullable(_takeaway.text),
      screenshots: _attachments.isEmpty ? null : _attachments.first,
      attachments: _attachments,
      createdAt: previous?.createdAt ?? now,
      updatedAt: now,
    );
    widget.onJournalSaved(saved);
    setState(() {
      _journal = saved;
      _editing = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Journal entry saved')));
  }

  Widget _stickyAction() => Container(
    padding: EdgeInsets.fromLTRB(
      18,
      10,
      18,
      MediaQuery.paddingOf(context).bottom + 12,
    ),
    decoration: const BoxDecoration(
      color: _bg,
      border: Border(top: BorderSide(color: _border)),
    ),
    child: SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: _editing ? _saveJournal : _startEditing,
        style: FilledButton.styleFrom(
          backgroundColor: _mint,
          foregroundColor: _bg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          _editing ? 'Save Journal Entry' : 'Edit Journal Entry',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),
    ),
  );
}
