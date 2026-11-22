import 'strategy.model.dart';

/// Filter choices shown as chips on the My Strategies screen.
enum PlaybookFilter { all, ictSmc, priceAction }

extension PlaybookFilterLabel on PlaybookFilter {
  String get label => switch (this) {
        PlaybookFilter.all => 'All Setups',
        PlaybookFilter.ictSmc => 'ICT / SMC',
        PlaybookFilter.priceAction => 'Price Action',
      };
}

/// Presentation model for one playbook card.
///
/// Playbook data is owned by the backend and decoded from `/api/strategies`.
class StrategyPlaybook {
  final String id;
  final String name;
  final String description;
  final StrategyCategory category;
  final bool primary;
  final int adherence;
  final bool reviewNeeded;
  final bool favorite;
  final int executions;
  final double winRate;
  final double avgR;
  final double netPnl;
  final List<String> badges;

  const StrategyPlaybook({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.primary,
    required this.adherence,
    required this.reviewNeeded,
    required this.favorite,
    required this.executions,
    required this.winRate,
    required this.avgR,
    required this.netPnl,
    required this.badges,
  });

  factory StrategyPlaybook.fromJson(Map<String, dynamic> json) {
    return StrategyPlaybook(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: StrategyCategory.values.byName(json['category'] as String),
      primary: json['primary'] as bool,
      adherence: (json['adherence'] as num).toInt(),
      reviewNeeded: json['reviewNeeded'] as bool,
      favorite: json['favorite'] as bool,
      executions: (json['executions'] as num).toInt(),
      winRate: (json['winRate'] as num).toDouble(),
      avgR: (json['avgR'] as num).toDouble(),
      netPnl: (json['netPnl'] as num).toDouble(),
      badges: List<String>.from(json['badges'] as List<dynamic>),
    );
  }

  bool matches(PlaybookFilter filter) => switch (filter) {
        PlaybookFilter.all => true,
        PlaybookFilter.ictSmc => category == StrategyCategory.ictSmc,
        PlaybookFilter.priceAction => category == StrategyCategory.priceAction,
      };

  List<String> get tags {
    final values = <String>[];
    if (primary) values.add('Primary');
    values.add(category == StrategyCategory.ictSmc ? 'ICT / SMC' : 'Price Action');
    values.add(reviewNeeded
        ? '● $adherence% • Review Needed'
        : '● $adherence% Adherence');
    return values;
  }
}

/// Summary metrics returned with the playbook catalogue.
class StrategyOverview {
  final List<StrategyPlaybook> playbooks;
  final int executions;
  final double netReturn;
  final double winRate;

  const StrategyOverview({
    required this.playbooks,
    required this.executions,
    required this.netReturn,
    required this.winRate,
  });

  factory StrategyOverview.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>;
    return StrategyOverview(
      playbooks: (json['playbooks'] as List<dynamic>)
          .map((item) => StrategyPlaybook.fromJson(item as Map<String, dynamic>))
          .toList(),
      executions: (summary['executions'] as num).toInt(),
      netReturn: (summary['netReturn'] as num).toDouble(),
      winRate: (summary['winRate'] as num).toDouble(),
    );
  }
}
