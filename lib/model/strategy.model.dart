enum StrategyCategory {
  ictSmc,
  priceAction,
  trendFollowing,
  scalping,
  breakout,
  other,
}

enum TradingSession { asian, london, newYork, londonNewYorkOverlap }

class Strategy {
  final String id;
  final String name;
  final String description;
  final StrategyCategory strategyCategory;
  final TradingSession tradingSession;
  final String entryCondition;
  final String exitCondition;
  final List<String> rules;
  final DateTime createdAt;
  final String userId;

  Strategy({
    required this.id,
    required this.name,
    required this.description,
    required this.strategyCategory,
    required this.tradingSession,
    required this.entryCondition,
    required this.exitCondition,
    required this.rules,
    required this.createdAt,
    required this.userId,
  });

  factory Strategy.fromJson(Map<String, dynamic> json) {
    return Strategy(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      strategyCategory: StrategyCategory.values.byName(
        json['strategyCategory'] as String,
      ),
      tradingSession: TradingSession.values.byName(
        json['tradingSession'] as String,
      ),
      entryCondition: json['entryCondition'] as String,
      exitCondition: json['exitCondition'] as String,
      rules: List<String>.from(json['rules'] as List),
      createdAt: DateTime.parse(json['createdAt'] as String),
      userId: json['userId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'description': description,
      'strategyCategory': strategyCategory.name,
      'tradingSession': tradingSession.name,
      'entryCondition': entryCondition,
      'exitCondition': exitCondition,
      'rules': rules,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
