import 'package:flutter/material.dart';
import 'package:trader_log/model/strategy_draft.model.dart';
import 'package:trader_log/model/strategy_detail.model.dart';
import 'package:trader_log/services/strategy_api_service.dart';

const _bg = Color(0xFF111411);
const _surface = Color(0xFF1A1F1B);
const _mint = Color(0xFFB7F7C4);
const _coral = Color(0xFFFF7C7C);
const _muted = Color(0xFF858D86);
const _border = Color(0xFF303832);
const _ink = Color(0xFFE8ECE8);
const String _dollar = r'$';

/// Deep-dive rulebook, telemetry and MT5 ticket log for one playbook.
///
/// A user-created [draft] uses this exact same layout. With no assigned trades
/// it shows honest empty stats instead of a different screen.
class StrategyDetailScreen extends StatefulWidget {
  final String? strategyId;
  final String playbookName;
  final StrategyDraft? draft;
  final StrategyApiService api;

  const StrategyDetailScreen({
    super.key,
    this.strategyId,
    required this.playbookName,
    this.draft,
    this.api = const StrategyApiService(),
  });

  factory StrategyDetailScreen.fromDraft({required StrategyDraft draft}) {
    return StrategyDetailScreen(playbookName: draft.name, draft: draft);
  }

  @override
  State<StrategyDetailScreen> createState() => _StrategyDetailScreenState();
}

class _StrategyDetailScreenState extends State<StrategyDetailScreen> {
  bool _rulesExpanded = true;
  StrategyTradeFilter _tradeFilter = StrategyTradeFilter.all;

  late final StrategyDetail _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (widget.draft != null) {
      setState(() {
        _detail = StrategyDetail.fromDraft(widget.draft!);
        _loading = false;
      });
      return;
    }

    final strategyId = widget.strategyId;
    if (strategyId == null) {
      setState(() {
        _error = 'No strategy was selected.';
        _loading = false;
      });
      return;
    }

    try {
      final detail = await widget.api.fetchDetail(strategyId);
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _surface,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _ink, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Strategy Details',
              style: TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              _loading ? 'Loading rulebook…' : widget.playbookName,
              style: const TextStyle(color: _muted, fontSize: 10.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'More strategy options',
            icon: const Icon(Icons.more_horiz_rounded, color: _muted),
            onPressed: () => _snack('Strategy options are not connected yet'),
          ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _mint));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, color: _muted, size: 34),
              const SizedBox(height: 10),
              const Text(
                'Could not load this rulebook.',
                style: TextStyle(color: _ink, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                _error ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted, fontSize: 10),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _mint,
                  foregroundColor: _bg,
                ),
                onPressed: _load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroCard(),
          const SizedBox(height: 12),
          _telemetryGrid(),
          const SizedBox(height: 12),
          _rulesCard(),
          const SizedBox(height: 12),
          _tradesSection(),
          const SizedBox(height: 12),
          _bottomActions(),
        ],
      ),
    );
  }

  Widget _heroCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _mint.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _mint.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _detail.statusLabel,
                    style: const TextStyle(
                      color: _mint,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _detail.syncLabel,
                    textAlign: TextAlign.right,
                    style: const TextStyle(color: _muted, fontSize: 9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _mint.withValues(alpha: 0.12),
                    border: Border.all(color: _mint, width: 1.5),
                  ),
                  child: Text(
                    _detail.hasTelemetry ? '${_detail.grade}%' : '—',
                    style: const TextStyle(
                      color: _mint,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GRADE',
                        style: TextStyle(color: _muted, fontSize: 8.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _detail.macroWindow,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _detail.hasTelemetry
                            ? 'Rulebook adherence tracked from MT5 assignments'
                            : 'No MT5 assignments yet · saved rulebook only',
                        style: const TextStyle(color: _muted, fontSize: 8.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(color: _border, height: 1),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NET RETURN',
                        style: TextStyle(color: _muted, fontSize: 8.5),
                      ),
                      const SizedBox(height: 3),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _formatMoney(_detail.netReturn),
                          style: const TextStyle(
                            color: _mint,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121813),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _border),
                  ),
                  child: Text(
                    '${_signed(_detail.netReturnPercent, 1)}%',
                    style: const TextStyle(
                      color: _mint,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _telemetryGrid() => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.6,
        children: [
          _telemetryCard(
            'Win Rate',
            _detail.hasTelemetry
                ? '${_detail.winRate.toStringAsFixed(1)}%'
                : '0.0%',
            color: _ink,
          ),
          _telemetryCard(
            'Profit Factor',
            _detail.hasTelemetry ? _detail.profitFactor.toStringAsFixed(2) : '—',
            color: _ink,
          ),
          _telemetryCard(
            'Avg R Multiple',
            _detail.hasTelemetry
                ? '${_signed(_detail.avgRMultiple, 2)} R'
                : '—',
            color: _mint,
          ),
          _telemetryCard(
            'Max Drawdown',
            _detail.hasTelemetry
                ? '${_detail.maxDrawdown.toStringAsFixed(1)}%'
                : '—',
            color: _coral,
          ),
        ],
      );

  Widget _telemetryCard(String label, String value, {required Color color}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 9)),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _rulesCard() => Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _rulesExpanded = !_rulesExpanded),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Rules & Verification',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _mint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: _mint.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        _detail.hasTelemetry
                            ? '${_detail.adherence.toStringAsFixed(1)}%'
                            : '—',
                        style: const TextStyle(
                          color: _mint,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _rulesExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: _muted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: !_rulesExpanded
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Divider(color: _border, height: 1),
                          const SizedBox(height: 12),
                          if (_detail.summary != null) ...[
                            const Text(
                              'STRATEGY NOTES',
                              style: TextStyle(
                                color: _mint,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _detail.summary!,
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 10,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          _ruleGroup('Entry Checklist', _detail.entryRules),
                          const SizedBox(height: 14),
                          _ruleGroup(
                              'Risk & Exit Architecture', _detail.riskRules),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      );

  Widget _ruleGroup(String title, List<StrategyRule> rules) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _mint,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          ...rules.map(
            (rule) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    rule.verified
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: rule.verified ? _mint : _muted,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rule.text,
                      style: const TextStyle(
                          color: _muted, fontSize: 10, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _tradesSection() {
    final trades = _detail.filteredTrades(_tradeFilter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Assigned MT5 Trades',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${_detail.trades.length}',
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final filter in StrategyTradeFilter.values) ...[
              _tradeFilterChip(filter),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (trades.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: Text(
              _detail.hasTelemetry
                  ? 'No trades in this filter'
                  : 'No MT5 trades assigned to this setup yet',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          )
        else
          ...trades.map(_tradeRow),
      ],
    );
  }

  Widget _tradeFilterChip(StrategyTradeFilter filter) {
    final active = filter == _tradeFilter;
    return Material(
      color: active ? _mint : _surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _tradeFilter = filter),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? _mint : _border),
          ),
          child: Text(
            filter.label,
            style: TextStyle(
              color: active ? _bg : _muted,
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _tradeRow(StrategyTradeRecord trade) {
    final digits = trade.pair.contains('JPY') || trade.pair.startsWith('XAU')
        ? 2
        : 4;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trade.pair}  ·  ${trade.lots.toStringAsFixed(2)} lot',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Entry ${trade.entry.toStringAsFixed(digits)} → Exit ${trade.exit.toStringAsFixed(digits)}',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 9,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: trade.compliant
                        ? _mint.withValues(alpha: 0.10)
                        : _coral.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: trade.compliant
                          ? _mint.withValues(alpha: 0.35)
                          : _coral.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    trade.compliant ? 'Compliant' : 'Rule Break',
                    style: TextStyle(
                      color: trade.compliant ? _mint : _coral,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'P&L',
                style: TextStyle(color: _muted, fontSize: 8.5),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _formatMoney(trade.pnl),
                  style: TextStyle(
                    color: trade.isWin ? _mint : _coral,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomActions() => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _mint,
                    side: const BorderSide(color: _mint),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () =>
                      _snack('MT5 assignment flow is not connected yet'),
                  child: const Text(
                    'Assign MT5 Trades',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => _snack('Audit report export is not connected yet'),
            child: const Text(
              'Export Strategy Audit Report',
              style: TextStyle(
                color: _mint,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      );

  String _signed(double value, int digits) =>
      '${value < 0 ? '-' : '+'}${value.abs().toStringAsFixed(digits)}';

  String _formatMoney(double value) {
    final sign = value < 0 ? '-' : '+';
    final absolute = value.abs();
    final parts = absolute.toStringAsFixed(2).split('.');
    final whole = parts.first;
    final grouped = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) grouped.write(',');
      grouped.write(whole[i]);
    }
    return '$sign$_dollar$grouped.${parts[1]}';
  }
}
