# Create Strategy Form Screen — Implementation Specification

## 1. Purpose

The Create Strategy screen is the drafting surface for a new trading playbook.
It collects the setup identity, narrative, entry triggers, risk framework,
discipline safeguards and active sessions/timeframes in one mobile form. The
form validates locally, then posts the complete draft to the NestJS backend via
`POST /api/strategies`.

## 2. Files added and changed

| File | Purpose |
| --- | --- |
| `backend/src/strategies/strategies.controller.ts` | Guards `POST /api/strategies` with JWT and validates the draft name. |
| `backend/src/strategies/strategies.service.ts` | Persists drafts in Postgres `strategy_drafts` and returns id, name, savedAt and draftCount. |
| `backend/src/strategies/strategy.models.ts` | `CreateStrategyDto` and `CreatedStrategyDto` typings. |
| `lib/screens/create_strategy.screen.dart` | All form sections, reorderable entry list, discipline toggles, chip selectors, sticky save bar and API submission. |
| `lib/screens/strategies.screen.dart` | The `+ Create` button now pushes the new form with the shared API client. |
| `lib/services/strategy_api_service.dart` | `createDraft()` posts JSON to the backend. |
| `test/support/strategy_fixtures.dart` | Mock API responses used by widget tests. |
| `test/create_strategy_screen_test.dart` | Widget tests for sections, adding rules, character count, validation, save feedback and POST payload. |
| `test/strategy_api_service_test.dart` | Unit tests for GET/POST paths and non-JSON error handling. |
| `implement/create_strategy_form_section_spec.md` | This document. |

The screen is pushed above the root navigation shell, matching the detail-screen
pattern. `Cancel` and the stack app bar back button both pop the route.

## 3. Screen structure

`CreateStrategyScreen` is a `StatefulWidget`. Its body is a
`SingleChildScrollView` containing six surface cards:

1. **Basic Setup** — name, short description and category chips.
2. **Playbook Narrative** — multi-line rationale field with a Markdown hint and
   live `n/800` character counter.
3. **Entry Conditions** — reorderable trigger list with checkboxes, inline text
   editors, delete buttons and `+ Add Entry Condition`.
4. **Risk & Exit Framework** — take-profit, stop-loss and invalidation fields.
5. **Pre-Flight Discipline** — toggleable safeguards plus
   `+ Add Custom Discipline Rule`.
6. **Active Sessions & Timeframes** — multi-select chips for sessions and chart
   intervals.

A sticky `bottomNavigationBar` holds `Cancel` and the full-width mint
`Save Strategy` CTA. During submission the CTA shows a mint progress spinner.

## 4. Local state model

- `_EntryCondition` owns a `TextEditingController` and an `enabled` flag.
  `ReorderableListView.builder` uses the object as its `ValueKey`, so drag order
  survives rebuilds and controllers are disposed with the screen.
- `_CheckItem` is the lightweight text plus `enabled` model for discipline
  rules. Custom rules are appended after inline entry.
- Category, session and interval choices are `Set`s, so chips toggle cleanly
  without duplicate values.
- `StrategyCategory` comes from the existing `lib/model/strategy.model.dart`
  enum; its `name` is sent to the backend as the category string.

Every edit updates `_draftStatus` to `Draft auto-saved`. On a successful POST the
form pops with `true`, returning the user to the Strategies tab; that tab waits
for the result, reloads the user's drafts, and shows the new card at the top of
**All Setups** with a "Your Setup" badge and a single confirmation snackbar.
On failure the form stays open and `_draftStatus` becomes `Save failed`.

## 5. Request payload

`Save Strategy` requires a non-empty name. It then sends:

```json
{
  "name": "London Sweep",
  "description": "...",
  "category": "ictSmc",
  "categories": ["ictSmc"],
  "narrative": "...",
  "entryConditions": [{ "text": "...", "enabled": true }],
  "takeProfitRule": "...",
  "stopLossRule": "...",
  "invalidationRule": "...",
  "disciplineRules": [{ "text": "...", "enabled": true }],
  "sessions": ["London", "New York"],
  "intervals": ["15M", "5M", "1M"]
}
```

The request is sent with `Authorization: Bearer <jwt>` from `AuthStore`, so the
backend attributes the draft to the signed-in user. The backend validates the
name again. A success SnackBar includes the returned draft id; an API failure
shows the exception message.

## 6. Interactions

- Filter chips toggle selection with mint selected state.
- The narrative field caps input at 800 characters and shows the live count.
- Entry rows can be checked, edited, deleted and reordered by the drag handle.
- Custom discipline rules appear in an inline text field and are added with the
  check button.
- `Save Strategy` shows validation feedback without calling the API when the
  name is empty.

## 7. Visual tokens

| Use | Token |
| --- | --- |
| Screen / app bar background | `#111411` |
| Card surface and sticky footer | `#1A1F1B` |
| Mint primary CTA, selected chips, checkmarks | `#B7F7C4` |
| Delete icons | `#FF7C7C` |
| Secondary text and disabled rules | `#858D86` |
| Borders and input outlines | `#303832` |
| Primary text and input text | `#E8ECE8` |
| Inner input fill | `#121813` |

## 8. Verification

- `flutter test` covers all six section headings, default chips and actions,
  adding an entry condition, adding a custom discipline rule, the live character
  count, validation, success feedback, the exact POST payload, and API-client
  behavior.
- `flutter analyze` reports no new errors or warnings.
- `flutter build web --debug --no-wasm-dry-run` compiles.
- `cd backend && npm run build` compiles the strategies module.

## 9. Implementation boundary and limitations

- A signed-in JWT is required to save; the user can sign in from the Settings
  tab. Drafts persist in Postgres but are not added to the public My Strategies
  catalogue automatically.
- Saving does not create a full `Strategy` record or write `SharedPreferences`.
- Markdown is indicated and counted but is not rendered in the field.
- Draft auto-save is an in-memory status label; only `Save Strategy` sends data.
- No MT5 assignment or file import is involved in this screen.
