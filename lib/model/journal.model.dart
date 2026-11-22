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
  String? executionNotes;
  String? strategyName;
  String? tradingSession;
  List<String>? strategyNames;
  List<String?>? strategyIds;
  String? sessionNarrative;
  List<String>? rulesFollowed;
  EmotionalState? emotionalState;
  double? disciplineGrade;
  double? preEntryRating;
  double? tradeHoldingRating;
  String? lessonLearned;
  String? screenshots;
  List<String>? attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String tradeId;
  String? strategyId;

  Journal({
    required this.id,
    this.marketBias,
    this.entryReason,
    this.plan,
    this.executionNotes,
    this.strategyName,
    this.tradingSession,
    this.strategyNames,
    this.strategyIds,
    this.sessionNarrative,
    this.rulesFollowed,
    this.emotionalState,
    this.disciplineGrade,
    this.preEntryRating,
    this.tradeHoldingRating,
    this.lessonLearned,
    this.screenshots,
    this.attachments,
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
      executionNotes: json['executionNotes'] as String?,
      strategyName: json['strategyName'] as String?,
      tradingSession: json['tradingSession'] as String?,
      strategyNames: json['strategyNames'] != null
          ? List<String>.from(json['strategyNames'] as List)
          : json['strategyName'] == null
          ? null
          : [json['strategyName'] as String],
      strategyIds: json['strategyIds'] != null
          ? (json['strategyIds'] as List).map((id) => id as String?).toList()
          : json['strategyId'] == null
          ? null
          : [json['strategyId'] as String],
      sessionNarrative: json['sessionNarrative'] as String?,
      rulesFollowed: json['rulesFollowed'] != null
          ? List<String>.from(json['rulesFollowed'] as List)
          : null,
      emotionalState: json['emotionalState'] != null
          ? EmotionalState.values.byName(json['emotionalState'] as String)
          : null,
      disciplineGrade: (json['disciplineGrade'] as num?)?.toDouble(),
      preEntryRating: (json['preEntryRating'] as num?)?.toDouble(),
      tradeHoldingRating: (json['tradeHoldingRating'] as num?)?.toDouble(),
      lessonLearned: json['lessonLearned'] as String?,
      screenshots: json['screenshots'] as String?,
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'] as List)
          : null,
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
      'executionNotes': executionNotes,
      'strategyName': strategyName,
      'tradingSession': tradingSession,
      'strategyNames': strategyNames,
      'strategyIds': strategyIds,
      'sessionNarrative': sessionNarrative,
      'rulesFollowed': rulesFollowed,
      'emotionalState': emotionalState?.name,
      'disciplineGrade': disciplineGrade,
      'preEntryRating': preEntryRating,
      'tradeHoldingRating': tradeHoldingRating,
      'lessonLearned': lessonLearned,
      'screenshots': screenshots,
      'attachments': attachments,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
