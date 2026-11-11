enum MarketBias { bullish, bearish, neutral }

enum EmotionalState {
  confident,
  calm,
  focused,
  fearful,
  greedy,
  frustrated,
  anxious,
  impatient,
  fomo,
  revengeTrading,
}

class Journal {
  final String id;
  MarketBias? marketBias;
  String? entryReason;
  String? plan;
  List<String>? rulesFollowed;
  EmotionalState? emotionalState;
  String? lessonLearned;
  String? screenshots;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String tradeId;
  String? strategyId;

  Journal({
    required this.id,
    this.marketBias,
    this.entryReason,
    this.plan,
    this.rulesFollowed,
    this.emotionalState,
    this.lessonLearned,
    this.screenshots,
    required this.createdAt,
    required this.updatedAt,
    required this.tradeId,
    this.strategyId,
  });

  factory Journal.fromJson(Map<String, dynamic> json) {
    return Journal(
      id: json['id'] as String,
      marketBias: json['marketBias'] != null
          ? MarketBias.values.byName(json['marketBias'] as String)
          : null,
      entryReason: json['entryReason'] as String?,
      plan: json['plan'] as String?,
      rulesFollowed: json['rulesFollowed'] != null
          ? List<String>.from(json['rulesFollowed'] as List)
          : null,
      emotionalState: json['emotionalState'] != null
          ? EmotionalState.values.byName(json['emotionalState'] as String)
          : null,
      lessonLearned: json['lessonLearned'] as String?,
      screenshots: json['screenshots'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      tradeId: json['tradeId'] as String,
      strategyId: json['strategyId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tradeId': tradeId,
      'strategyId': strategyId,
      'marketBias': marketBias?.name,
      'entryReason': entryReason,
      'plan': plan,
      'rulesFollowed': rulesFollowed,
      'emotionalState': emotionalState?.name,
      'lessonLearned': lessonLearned,
      'screenshots': screenshots,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
