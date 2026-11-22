import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A user's saved drawing analysis for one trade's advanced chart.
class TradeChartAnalysis {
  final String tradeId;
  final String timeframe;
  final List<Map<String, dynamic>> drawings;
  final Map<String, dynamic> settings;
  final DateTime updatedAt;

  const TradeChartAnalysis({
    required this.tradeId,
    required this.timeframe,
    required this.drawings,
    required this.settings,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'version': 1,
    'tradeId': tradeId,
    'timeframe': timeframe,
    'drawings': drawings,
    'settings': settings,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory TradeChartAnalysis.fromJson(Map<String, dynamic> json) {
    return TradeChartAnalysis(
      tradeId: json['tradeId'] as String? ?? '',
      timeframe: json['timeframe'] as String? ?? '1h',
      drawings: (json['drawings'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList(),
      settings:
          (json['settings'] as Map<String, dynamic>? ??
          const <String, dynamic>{}),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Shared-preferences backed store for [TradeChartAnalysis].
///
/// Analysis is keyed by trade id (not symbol) so a re-import or a different
/// account never overwrites another trade's drawings.
class TradeChartAnalysisStore {
  static const _prefix = 'traderlog.chart.analysis.';

  const TradeChartAnalysisStore();

  Future<TradeChartAnalysis?> load(String tradeId) async {
    if (tradeId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$tradeId');
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return TradeChartAnalysis.fromJson(decoded);
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> save(TradeChartAnalysis analysis) async {
    if (analysis.tradeId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix${analysis.tradeId}',
      jsonEncode(analysis.toJson()),
    );
  }

  Future<void> clear(String tradeId) async {
    if (tradeId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$tradeId');
  }
}

/// Converts a bridge payload into a JSON-safe map.
Map<String, dynamic> decodeChartMessage(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      return const <String, dynamic>{};
    }
  }
  return const <String, dynamic>{};
}
