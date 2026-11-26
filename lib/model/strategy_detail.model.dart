import 'strategy_draft.model.dart';
import 'strategy_playbook.model.dart';

/// Filter tabs shown above the assigned MT5 ticket log.
enum StrategyTradeFilter { all, wins, losses }

extension StrategyTradeFilterLabel on StrategyTradeFilter {
  String get label => switch (this) {
        StrategyTradeFilter.all => 'All',
        StrategyTradeFilter.wins => 'Wins',
        StrategyTradeFilter.losses => 'Losses',
      };
}

/// One verified rule inside a playbook rulebook.
class StrategyRule {
  final String text;
  final bool verified;

  const StrategyRule({required this.text, required this.verified});

  factory StrategyRule.fromJson(Map<String, dynamic> json) => StrategyRule(
        text: json['text'] as String,
        verified: json['verified'] as bool,
      );
}

/// One MT5 execution assigned to a strategy.
class StrategyTradeRecord {
  final String pair;
  final double lots;
  final double entry;
  final double exit;
  final double pnl;
  final bool compliant;

  const StrategyTradeRecord({
    required this.pair,
    required this.lots,
    required this.entry,
    required this.exit,
    required this.pnl,
    required this.compliant,
  });

  factory StrategyTradeRecord.fromJson(Map<String, dynamic> json) =>
      StrategyTradeRecord(
        pair: json['pair'] as String,
        lots: (json['lots'] as num).toDouble(),
        entry: (json['entry'] as num).toDouble(),
        exit: (json['exit'] as num).toDouble(),
        pnl: (json['pnl'] as num).toDouble(),
        compliant: json['compliant'] as bool,
      );

  bool get isWin => pnl > 0;
}

/// Presentation data for the strategy deep-dive screen.
class StrategyDetail {
  /// Null for a user-created setup: it has no shared catalogue row.
  final StrategyPlaybook? playbook;
  final String statusLabel;
  final String syncLabel;

  /// The user's own strategy notes; backend playbooks use the shared rulebook.
  final String? summary;
  final int grade;
  final String macroWindow;
  final double netReturn;
  final double netReturnPercent;
  final double winRate;
  final double profitFactor;
  final double avgRMultiple;
  final double maxDrawdown;
  final double adherence;
  final List<StrategyRule> entryRules;
  final List<StrategyRule> riskRules;
  final List<StrategyTradeRecord> trades;

  /// True when MT5-backed performance numbers are available. User-created
  /// setups keep the same detail layout but show honest empty stats.
  final bool hasTelemetry;

  const StrategyDetail({
    required this.playbook,
    required this.statusLabel,
    required this.syncLabel,
    this.summary,
    required this.grade,
    required this.macroWindow,
    required this.netReturn,
    required this.netReturnPercent,
    required this.winRate,
    required this.profitFactor,
    required this.avgRMultiple,
    required this.maxDrawdown,
    required this.adherence,
    required this.entryRules,
    required this.riskRules,
    required this.trades,
    required this.hasTelemetry,
  });

  /// Builds the exact same detail view for a setup the user created. Nothing
  /// is invented: no trades means zero win rate/net return and `—` for ratios
  /// that need executions.
  factory StrategyDetail.fromDraft(StrategyDraft draft) {
    final sessions = draft.sessions
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    final narrative = draft.narrative?.trim() ?? '';
    final description = draft.description?.trim() ?? '';
    final summary =
        narrative.isNotEmpty ? narrative : (description.isNotEmpty ? description : null);

    final riskRules = <StrategyRule>[];
    void addRisk(String? value) {
      final text = value?.trim() ?? '';
      if (text.isNotEmpty) {
        riskRules.add(StrategyRule(text: text, verified: true));
      }
    }

    addRisk(draft.takeProfitRule);
    addRisk(draft.stopLossRule);
    addRisk(draft.invalidationRule);

    return StrategyDetail(
      playbook: null,
      statusLabel: 'Your Setup',
      syncLabel: 'Saved to your account',
      summary: summary,
      grade: 0,
      macroWindow:
          sessions.isEmpty ? 'No sessions selected' : sessions.join(' / '),
      netReturn: 0,
      netReturnPercent: 0,
      winRate: 0,
      profitFactor: 0,
      avgRMultiple: 0,
      maxDrawdown: 0,
      adherence: 0,
      entryRules: [
        for (final condition in draft.entryConditions)
          StrategyRule(text: condition.text, verified: condition.enabled),
      ],
      riskRules: riskRules,
      trades: const <StrategyTradeRecord>[],
      hasTelemetry: false,
    );
  }

  factory StrategyDetail.fromJson(Map<String, dynamic> json) {
    List<T> decodeList<T>(
      String key,
      T Function(Map<String, dynamic>) factory,
    ) =>
        (json[key] as List<dynamic>)
            .map((item) => factory(item as Map<String, dynamic>))
            .toList();

    return StrategyDetail(
      playbook: json['playbook'] == null
          ? null
          : StrategyPlaybook.fromJson(json['playbook'] as Map<String, dynamic>),
      statusLabel: json['statusLabel'] as String,
      syncLabel: json['syncLabel'] as String,
      grade: (json['grade'] as num).toInt(),
      macroWindow: json['macroWindow'] as String,
      netReturn: (json['netReturn'] as num).toDouble(),
      netReturnPercent: (json['netReturnPercent'] as num).toDouble(),
      winRate: (json['winRate'] as num).toDouble(),
      profitFactor: (json['profitFactor'] as num).toDouble(),
      avgRMultiple: (json['avgRMultiple'] as num).toDouble(),
      maxDrawdown: (json['maxDrawdown'] as num).toDouble(),
      adherence: (json['adherence'] as num).toDouble(),
      entryRules: decodeList('entryRules', StrategyRule.fromJson),
      riskRules: decodeList('riskRules', StrategyRule.fromJson),
      trades: decodeList('trades', StrategyTradeRecord.fromJson),
      hasTelemetry: true,
    );
  }

  List<StrategyTradeRecord> filteredTrades(StrategyTradeFilter filter) =>
      switch (filter) {
        StrategyTradeFilter.all => trades,
        StrategyTradeFilter.wins =>
          trades.where((trade) => trade.isWin).toList(),
        StrategyTradeFilter.losses =>
          trades.where((trade) => !trade.isWin).toList(),
      };
}
