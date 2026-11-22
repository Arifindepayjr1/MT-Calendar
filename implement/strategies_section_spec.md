# My Strategies Section — Implementation Specification

## 1. Purpose

The Strategies tab is the app's playbook management view. A 390 px mobile
layout shows an overview of playbooks, execution counts and net return, then a
filterable list of strategy cards with adherence, rules-of-play and performance
context. It replaces the former placeholder section in the root navigation
shell.

Playbook data is owned by the NestJS backend. The Flutter screen is a
presentation client: it fetches `/api/strategies`, decodes a `StrategyOverview`,
and renders it. Local UI state is limited to filters, favorites, the empty-state
preview and navigation.

## 2. Files added and changed

| File | Purpose |
| --- | --- |
| `backend/src/strategies/` | Backend module, controller, service and DTOs that own the playbook catalogue, summary metrics, rulebook details and draft creation. |
| `lib/services/strategy_api_service.dart` | Flutter HTTP client for `/api/strategies` and `/api/strategies/:id`. |
| `lib/screens/strategies.screen.dart` | `StrategiesScreen`: loading/error states, metrics, filters, cards, tip card, accordion and navigation into detail/form screens. |
| `lib/model/strategy_playbook.model.dart` | `StrategyPlaybook`, `PlaybookFilter` and `StrategyOverview` decoding models. No sample data remains here. |
| `lib/screens/main_navigation.screen.dart` | Mounts the screen as the third tab and accepts an injectable `StrategyApiService`. |
| `lib/main.dart` | Passes the strategy API client through `MyApp` to the root shell. |
| `lib/widgets/home_app_bar.dart` | Adds an optional `backgroundColor` so the shared brand bar can adopt this screen's `#111411` surface; existing callers are unchanged. |
| `lib/screens/strategy_detail.screen.dart` | Detail route opened by tapping a playbook card or chevron. |
| `lib/screens/create_strategy.screen.dart` | Form route opened by `+ Create`. |
| `test/support/strategy_fixtures.dart` | API-shaped fixtures that mirror the backend responses for widget tests. |
| `test/strategies_screen_test.dart` | Widget tests for the tab, filtering, empty-state preview, navigation and decoded API data. |
| `implement/strategies_section_spec.md` | This document. |

The existing five-destination bottom bar is untouched: it already defines the
Strategies tab with the mint selected icon/label and uses `IndexedStack`, so the
screen is mounted as the third section without adding a second bottom bar.

## 3. Screen structure

`StrategiesScreen` is a `StatefulWidget` taking the active `accountName` from
the root shell and a `StrategyApiService`. It renders a `Scaffold` with
`HomeAppBar` and a `SafeArea` `ListView` in this order:

1. Title `My Strategies`, subtitle `Manage your trading setups and rules`, and
   a mint `+ Create` pill.
2. A three-column summary row: `Playbooks N / Active Sets`,
   `Executions 42 / Logged`, and `Net Return +$4,820.50 / 66.7% Win` (values
   decoded from the backend summary).
3. A horizontally scrolling filter strip with `All Setups (4)`, `ICT / SMC (3)`
   and `Price Action`.
4. One card per visible playbook.
5. A discipline tip card with a lightbulb icon.
6. An accordion that reveals a zero-playbook empty state preview.

A loading spinner is shown while the request is in flight. If the API is
unavailable or returns non-JSON, an error panel with a `Retry` button is shown.

## 4. Playbook data model

`StrategyPlaybook.fromJson` decodes the backend DTO:

- identity: `id`, `name`, `description`, `category`;
- tags: `primary`, `adherence`, `reviewNeeded`;
- performance: `executions`, `winRate`, `avgR`, `netPnl`;
- presentation: `favorite`, `badges`.

`matches(PlaybookFilter)` is the single filtering rule used by the UI. The
backend currently returns ICT Silver Bullet, London Breakout, ICT Judas Swing
and ICT OTE with the exact values shown in the specification. The negative OTE
net P&L is the only value rendered in coral.

No `adherence` field exists on `Trade`/`Journal`, so these percentages are
backend presentation values, not computed rule-compliance results. The discipline
tip explicitly points users to MT5 Trade Details, where strategy assignment can
later supply real adherence data.

## 5. Card anatomy

Each card uses the app's existing surface/border treatment (`#1A1F1B` on
`#111411`, 14 px radius) and contains:

- name with edit, overflow menu, optional favorite star and chevron controls;
- compact tag pills (category, `Primary`, adherence, review warning);
- the setup description;
- four stats: Volume, Win Rate, Avg R and Net P&L;
- timeframe and session badges.

Numeric values use `FontFeature.tabularFigures()` so columns line up at narrow
widths. `FittedBox(scaleDown)` prevents long values such as `+$4,820.50` from
overflowing the three-column metric row.

## 6. Interactions

- Filter chips are local state; changing one immediately recomputes the visible
  cards without refetching.
- The favorite star toggles locally; London Breakout starts favorited from the
  backend payload.
- Tapping a card body or its chevron pushes `StrategyDetailScreen` for that
  playbook; the route hides the bottom bar and restores it on back.
- `+ Create` pushes `CreateStrategyScreen`. The form posts a draft to the
  backend but does not refresh this list yet.
- Edit and overflow actions still show a short `SnackBar` note until a playbook
  editor and archive flow exist.
- The footer accordion uses `AnimatedSize` to reveal the empty state preview.

## 7. Visual tokens

| Use | Token |
| --- | --- |
| Screen / app bar background | `#111411` |
| Card surface | `#1A1F1B` |
| Mint accent and positive values | `#B7F7C4` |
| Negative P&L / review warning | `#FF7C7C` |
| Primary text | `#E8ECE8` |
| Secondary text | `#858D86` |
| Borders | `#303832` |

Font sizes stay between 8 and 22 px, with 12–16 px horizontal padding, so all
content fits a 390 px viewport.

## 8. Verification

- `flutter test` — 50 tests passed across the chart, navigation, strategies,
  detail, create-form and strategy-API suites. Strategies coverage includes the
  tab entry point, all four card names, metric text, the coral negative P&L
  style, category filtering, empty-state expansion, card-to-detail and
  `+ Create` navigation, and decoded API-data invariants.
- Widget tests use `http.MockClient` fixtures, so no live backend is required.
- Screen widget tests pump `StrategiesScreen` directly in a 390 px viewport so
  layout is validated at the target phone width. A separate test opens the
  screen through the real Strategies tab with an injected API client.
- The third filter chip starts just outside a 390 px viewport; the test uses
  `ensureVisible` to confirm the horizontal filter strip scrolls instead of
  assuming an off-screen tap.
- `flutter analyze` — no errors or warnings; the 12 reported info lints are
  pre-existing in unrelated widget files.
- `flutter build web --debug --no-wasm-dry-run` — compiled successfully.
- `cd backend && npm run build` — compiled successfully.

## 9. Implementation boundary and limitations

- Playbook data lives in the backend service's in-memory array. It is not
  stored in a database or `SharedPreferences`, is not linked to imported
  executions, and does not affect trade records, statistics or the calendar.
- `+ Create` and card taps navigate to the new form/detail screens. Saved drafts
  do not refresh this list yet; edit and overflow controls are still
  feedback-only affordances.
- Adherence and win-rate figures are backend display values, not derived from
  the current trade list. Real discipline tracking requires strategy assignment
  in MT5 Trade Details plus persisted playbooks.
- The shared `HomeAppBar` gained only an optional color argument; its Home-screen
  behavior and all other callers remain unchanged.
