import 'strategy.model.dart';

/// One enabled/disabled rule inside a saved user draft.
class StrategyDraftCheck {
  final String text;
  final bool enabled;

  const StrategyDraftCheck({required this.text, required this.enabled});

  factory StrategyDraftCheck.fromJson(Map<String, dynamic> json) =>
      StrategyDraftCheck(
        text: json['text'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
      );
}

/// A complete playbook draft owned by the signed-in user in NestJS/Postgres.
class StrategyDraft {
  final String id;
  final String name;
  final DateTime savedAt;
  final int draftCount;
  final String? description;
  final StrategyCategory? category;
  final List<StrategyCategory> categories;
  final String? narrative;
  final List<StrategyDraftCheck> entryConditions;
  final String? takeProfitRule;
  final String? stopLossRule;
  final String? invalidationRule;
  final List<StrategyDraftCheck> disciplineRules;
  final List<String> sessions;
  final List<String> intervals;

  const StrategyDraft({
    required this.id,
    required this.name,
    required this.savedAt,
    required this.draftCount,
    required this.description,
    required this.category,
    required this.categories,
    required this.narrative,
    required this.entryConditions,
    required this.takeProfitRule,
    required this.stopLossRule,
    required this.invalidationRule,
    required this.disciplineRules,
    required this.sessions,
    required this.intervals,
  });

  factory StrategyDraft.fromJson(Map<String, dynamic> json) => StrategyDraft(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        draftCount: json['draftCount'] as int? ?? 0,
        description: json['description'] as String?,
        category: _category(json['category']),
        categories: _categories(json['categories']),
        narrative: json['narrative'] as String?,
        entryConditions: _checks(json['entryConditions']),
        takeProfitRule: json['takeProfitRule'] as String?,
        stopLossRule: json['stopLossRule'] as String?,
        invalidationRule: json['invalidationRule'] as String?,
        disciplineRules: _checks(json['disciplineRules']),
        sessions: _strings(json['sessions']),
        intervals: _strings(json['intervals']),
      );

  static StrategyCategory? _category(Object? value) {
    if (value is! String) return null;
    for (final category in StrategyCategory.values) {
      if (category.name == value) return category;
    }
    return null;
  }

  static List<StrategyCategory> _categories(Object? value) {
    if (value is! List) return const <StrategyCategory>[];
    return value
        .map(_category)
        .whereType<StrategyCategory>()
        .toList(growable: false);
  }

  static List<StrategyDraftCheck> _checks(Object? value) {
    if (value is! List) return const <StrategyDraftCheck>[];
    return value
        .whereType<Map>()
        .map(
          (item) => StrategyDraftCheck.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  static List<String> _strings(Object? value) {
    if (value is! List) return const <String>[];
    return value.whereType<String>().toList(growable: false);
  }
}
