import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trader_log/services/strategy_api_service.dart';

/// API-shaped fixtures that mirror the NestJS strategies service.
/// Keeping them here makes widget tests independent of a running backend.

Map<String, dynamic> _playbook({
  required String id,
  required String name,
  required String description,
  required String category,
  required bool primary,
  required int adherence,
  required bool reviewNeeded,
  required bool favorite,
  required int executions,
  required double winRate,
  required double avgR,
  required double netPnl,
  required List<String> badges,
}) =>
    {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'primary': primary,
      'adherence': adherence,
      'reviewNeeded': reviewNeeded,
      'favorite': favorite,
      'executions': executions,
      'winRate': winRate,
      'avgR': avgR,
      'netPnl': netPnl,
      'badges': badges,
    };

final Map<String, dynamic> silverBulletPlaybook = _playbook(
  id: 'pb_silver_bullet',
  name: 'ICT Silver Bullet',
  description:
      'Time-based liquidity grab and displacement setup in London & NY AM macro windows.',
  category: 'ictSmc',
  primary: false,
  adherence: 92,
  reviewNeeded: false,
  favorite: false,
  executions: 14,
  winRate: 71.4,
  avgR: 2.4,
  netPnl: 2140,
  badges: const ['15M / 5M / 1M', 'London & NY Overlap'],
);

Map<String, dynamic> strategyOverviewJson() => {
      'playbooks': [
        silverBulletPlaybook,
        _playbook(
          id: 'pb_london_breakout',
          name: 'London Breakout',
          description:
              'Asian range high/low expansion during London open with aggressive volume displacement.',
          category: 'priceAction',
          primary: true,
          adherence: 94,
          reviewNeeded: false,
          favorite: true,
          executions: 18,
          winRate: 72.2,
          avgR: 2.8,
          netPnl: 2840,
          badges: const ['15M', 'London Session'],
        ),
        _playbook(
          id: 'pb_judas_swing',
          name: 'ICT Judas Swing',
          description:
              'False move liquidity sweep at session open followed by violent market structure shift.',
          category: 'ictSmc',
          primary: false,
          adherence: 83,
          reviewNeeded: false,
          favorite: false,
          executions: 6,
          winRate: 50.0,
          avgR: 1.6,
          netPnl: 380,
          badges: const ['1H / 15M', 'NY Session'],
        ),
        _playbook(
          id: 'pb_ote',
          name: 'ICT OTE',
          description:
              'Fibonacci 0.62–0.79 retracement into premium/discount order blocks with HTF confluence.',
          category: 'ictSmc',
          primary: false,
          adherence: 67,
          reviewNeeded: true,
          favorite: false,
          executions: 4,
          winRate: 50.0,
          avgR: 1.1,
          netPnl: -539.5,
          badges: const ['4H / 15M', 'Any Session'],
        ),
      ],
      'summary': {
        'playbooks': 4,
        'executions': 42,
        'netReturn': 4820.5,
        'winRate': 66.7,
      },
    };

Map<String, dynamic> strategyDetailJson() => {
      'playbook': silverBulletPlaybook,
      'statusLabel': 'Live Rulebook Active',
      'syncLabel': 'MT5 Synced · 2m ago',
      'grade': 92,
      'macroWindow': 'London & NY AM Macro',
      'netReturn': 2140,
      'netReturnPercent': 7.2,
      'winRate': 71.4,
      'profitFactor': 2.85,
      'avgRMultiple': 2.41,
      'maxDrawdown': -1.8,
      'adherence': 92.8,
      'entryRules': [
        {
          'text': 'Mark the London/NY AM macro window on the 15M chart.',
          'verified': true,
        },
        {
          'text': 'Confirm a liquidity grab of the prior session high or low.',
          'verified': true,
        },
        {
          'text': 'Wait for displacement with a clear fair-value gap.',
          'verified': true,
        },
        {
          'text':
              'Enter only on mitigate/retest into the discount or premium array.',
          'verified': true,
        },
      ],
      'riskRules': [
        {
          'text': 'Stop loss sits beyond the sweep extreme with a 5-pip buffer.',
          'verified': true,
        },
        {
          'text': 'TP1 at 2R; TP2 at the opposite session range extension.',
          'verified': true,
        },
        {
          'text':
              'Invalidate if price reclaims the liquidity pool before displacement.',
          'verified': true,
        },
      ],
      'trades': [
        {
          'pair': 'XAUUSD',
          'lots': 0.1,
          'entry': 2341.2,
          'exit': 2362.8,
          'pnl': 215,
          'compliant': true,
        },
        {
          'pair': 'EURUSD',
          'lots': 0.25,
          'entry': 1.0842,
          'exit': 1.0876,
          'pnl': 85,
          'compliant': true,
        },
        {
          'pair': 'GBPUSD',
          'lots': 0.15,
          'entry': 1.2631,
          'exit': 1.2598,
          'pnl': -49.5,
          'compliant': false,
        },
        {
          'pair': 'XAUUSD',
          'lots': 0.08,
          'entry': 2350.1,
          'exit': 2394.6,
          'pnl': 356.4,
          'compliant': true,
        },
        {
          'pair': 'USDJPY',
          'lots': 0.2,
          'entry': 156.42,
          'exit': 155.91,
          'pnl': -102,
          'compliant': false,
        },
        {
          'pair': 'EURUSD',
          'lots': 0.3,
          'entry': 1.0818,
          'exit': 1.0884,
          'pnl': 198,
          'compliant': true,
        },
      ],
    };

http.Response _jsonResponse(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: const {'content-type': 'application/json'},
    );

/// Creates a strategy API client backed by the fixtures above.
/// Pass [requests] to inspect what the UI sent to the backend.
StrategyApiService fakeStrategyApi({
  List<http.Request>? requests,
  Map<String, dynamic>? draftResponse,
}) {
  return StrategyApiService(
    client: MockClient((request) async {
      requests?.add(request);
      final path = request.url.path;

      if (request.method == 'GET' && path.endsWith('/api/strategies')) {
        return _jsonResponse(strategyOverviewJson());
      }
      if (request.method == 'GET' && path.contains('/api/strategies/')) {
        return _jsonResponse(strategyDetailJson());
      }
      if (request.method == 'POST' && path.endsWith('/api/strategies')) {
        return _jsonResponse(draftResponse ?? {
          'id': 'draft_1',
          'name': 'Draft',
          'savedAt': '2026-01-01T00:00:00.000Z',
          'draftCount': 1,
        });
      }

      return http.Response(
        jsonEncode({'error': 'Unexpected request'}),
        404,
        headers: const {'content-type': 'application/json'},
      );
    }),
  );
}
