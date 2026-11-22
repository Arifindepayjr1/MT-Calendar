# Strategy Details Screen — Implementation Specification

## 1. Purpose

The Strategy Details screen is a deep-dive rulebook view for a single playbook.
It combines three concerns in one scrolling mobile layout: performance
telemetry, the verifiable rule checklist, and the MT5 tickets assigned to the
strategy. The backend's `pb_silver_bullet` payload targets **ICT Silver Bullet**
with the exact figures from the screen specification.

## 2. Files added and changed

| File | Purpose |
| --- | --- |
| `backend/src/strategies/strategies.service.ts` | Owns the Silver Bullet rulebook, telemetry, rule list and MT5 tickets; generates fallback details for other playbooks. |
| `backend/src/strategies/strategy.models.ts` | Backend DTOs for detail payloads. |
| `lib/screens/strategy_detail.screen.dart` | `StrategyDetailScreen`: stacked app bar, loading/error states, hero card, telemetry grid, collapsible rules, MT5 ticket log and bottom actions. |
| `lib/model/strategy_detail.model.dart` | `StrategyDetail`, `StrategyRule`, `StrategyTradeRecord` and `StrategyTradeFilter` decoding models. |
| `lib/services/strategy_api_service.dart` | Fetches `GET /api/strategies/:id`. |
| `lib/screens/strategies.screen.dart` | Playbook cards and chevron now push `StrategyDetailScreen` with the playbook id. |
| `test/support/strategy_fixtures.dart` | API-shaped detail fixture used by widget tests. |
| `test/strategy_detail_screen_test.dart` | Widget and decoded-data tests for hero values, rules, filters and actions. |
| `implement/strategy_details_section_spec.md` | This document. |

The screen is pushed above the root navigation shell with `Navigator.push`, so
the persistent five-tab bar is hidden while the detail view is open. Tapping the
stack app bar back button returns to My Strategies.

## 3. Screen structure

`StrategyDetailScreen` takes a `strategyId`, a `playbookName` for the subtitle and
a `StrategyApiService`. It fetches `GET /api/strategies/:id` and renders the
decoded `StrategyDetail` in a `SingleChildScrollView`:

1. Stacked app bar: back arrow, `Strategy Details` title and the playbook name.
2. Hero card: status pill, MT5 sync state, grade circle, macro window and net
   return with percentage.
3. Four-card telemetry grid: Win Rate, Profit Factor, Avg R Multiple and Max
   Drawdown.
4. Collapsible `Rules & Verification` card with an adherence badge.
5. `Assigned MT5 Trades` list with All / Wins / Losses filter chips.
6. Bottom actions: `Assign MT5 Trades` and `Export Strategy Audit Report`.

Loading and API-failure states mirror the overview screen: a mint spinner or a
retry panel, so an unavailable backend does not produce a blank page.

## 4. Silver Bullet payload

The backend hand-authored payload uses the specified values:

- status `Live Rulebook Active`, sync `MT5 Synced · 2m ago`
- grade `92%`, macro `London & NY AM Macro`
- net return `+$2,140.00`, percentage `+7.2%`
- win rate `71.4%`, profit factor `2.85`, avg R `+2.41 R`, drawdown `-1.8%`
- adherence badge `92.8%`

Other playbooks get a generated detail payload from the backend so every card can
open a detail screen safely.

## 5. Rule and trade data

`StrategyRule.fromJson` decodes a rule string plus a verified flag. The rules
card groups them into **Entry Checklist** and **Risk & Exit Architecture**, using
mint check icons for verified rules.

`StrategyTradeRecord.fromJson` decodes pair, lot size, entry, exit, P&L and a
`compliant` flag. The ticket row renders entry and exit prices with sensible
decimal precision, a Compliance / Rule Break tag, and mint or coral P&L. The
All, Wins and Losses chips use `filteredTrades()`; a win is any positive P&L.

## 6. Interactions

- The rules header toggles `AnimatedSize` expansion.
- Filter chips switch the ticket list immediately.
- Assign and export controls show short `SnackBar` placeholders because there
  is no MT5 assignment or report service in this build.

## 7. Visual tokens

| Use | Token |
| --- | --- |
| Screen / app bar background | `#111411` |
| Card surface | `#1A1F1B` |
| Mint accent, positive values, verified rules | `#B7F7C4` |
| Negative P&L, drawdown, rule breaks | `#FF7C7C` |
| Secondary text | `#858D86` |
| Borders | `#303832` |
| Primary text | `#E8ECE8` |

## 8. Verification

- `flutter test` includes the detail-screen suite: hero/telemetry text, rules
  collapse/expand, win/loss filtering, and decoded-data invariants from the API
  fixture.
- `flutter analyze` reports no new errors or warnings.
- `flutter build web --debug --no-wasm-dry-run` compiles.
- `cd backend && npm run build` compiles the strategies module.

## 9. Implementation boundary and limitations

- Detail figures and MT5 tickets are backend sample data. They are not computed
  from the imported trade list and are not persisted.
- Only ICT Silver Bullet has the full hand-authored rulebook. Other playbooks
  use a generated fallback until their own rulebooks are defined.
- The audit export and MT5 assignment buttons are visual affordances only.
- Entry/exit prices and compliance tags are display values, not a tick-level
  replay of execution quality.
