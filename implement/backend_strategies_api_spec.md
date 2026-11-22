# Backend Strategies API — Implementation Specification

## 1. Purpose

The NestJS backend owns strategy catalogue data. Flutter screens ship no
business data: they decode JSON served by `backend/src/strategies` through
`GET /api/strategies`, `GET /api/strategies/:id` and the authenticated
`POST /api/strategies`. Catalogue and rulebook rows are stored in Postgres by
TypeORM and seeded on first run. See `implement/backend_auth_and_database_spec.md`
for the database, JWT and client-tooling details.

## 2. Files added and changed

| File | Purpose |
| --- | --- |
| `backend/src/strategies/entities/playbook.entity.ts` | Postgres playbook row with card and detail metrics. |
| `backend/src/strategies/entities/strategy-rule.entity.ts` | Ordered entry/risk rule rows. |
| `backend/src/strategies/entities/strategy-trade.entity.ts` | Assigned MT5 ticket rows. |
| `backend/src/strategies/entities/strategy-draft.entity.ts` | Per-user persisted draft payload. |
| `backend/src/strategies/strategies.seed.ts` | Four seeded playbooks with rules and tickets. |
| `backend/src/strategies/strategies.service.ts` | DTO mapping, seeding and draft persistence. |
| `backend/src/strategies/strategies.controller.ts` | Overview/detail (public) and drafts (Bearer-protected) routes. |
| `backend/src/strategies/strategy.models.ts` | Validated `CreateStrategyDto` and response interfaces. |
| `lib/services/strategy_api_service.dart` | Flutter client with JWT token provider and local-backend fallback. |
| `lib/model/strategy_playbook.model.dart` | Decodes the overview response; sample list removed. |
| `lib/model/strategy_detail.model.dart` | Decodes the detail response; sample detail removed. |
| `test/support/strategy_fixtures.dart` | API-shaped fixtures mirroring the backend for Flutter tests. |
| `test/strategy_api_service_test.dart` | Unit tests including Bearer-header coverage. |
| `implement/backend_strategies_api_spec.md` | This document. |

## 3. Endpoints

### `GET /api/strategies` (public)

Returns:

```json
{
  "playbooks": [ /* StrategyPlaybookDto[] */ ],
  "summary": {
    "playbooks": 4,
    "executions": 42,
    "netReturn": 4820.5,
    "winRate": 66.7
  }
}
```

The four seeded playbooks are ICT Silver Bullet, London Breakout, ICT Judas
Swing and ICT OTE. The Flutter strategy tab derives all metric text and filter
counts from this response.

### `GET /api/strategies/:id` (public)

Returns a `StrategyDetailDto`. `pb_silver_bullet` has the full hand-authored
payload:

- `Live Rulebook Active`, `MT5 Synced · 2m ago`
- grade `92`, `London & NY AM Macro`
- net return `2140`, `netReturnPercent: 7.2`
- `winRate: 71.4`, `profitFactor: 2.85`, `avgRMultiple: 2.41`,
  `maxDrawdown: -1.8`, `adherence: 92.8`
- four entry rules, three risk rules and six assigned MT5 tickets

Any other known id returns that playbook's own rules; an unknown id returns
`404` with `{"error":"Strategy not found."}`.

### `GET /api/strategies/drafts` (Bearer)

Returns the current user's drafts, newest first. Drafts live in Postgres and
survive backend restarts.

### `POST /api/strategies` (Bearer)

Accepts the form payload described in
`implement/create_strategy_form_section_spec.md`. A missing or blank `name`
returns `400`. Success returns:

```json
{
  "id": "draft_uuid",
  "name": "London Sweep",
  "savedAt": "2026-01-01T00:00:00.000Z",
  "draftCount": 1
}
```

## 4. Flutter client behavior

`StrategyApiService` checks these candidates in order:

1. same-origin `/api/...` (web only, for a deployed API);
2. `http://127.0.0.1:3000/api/...` (the local NestJS backend).

A non-2xx response, non-JSON content type, or malformed map response is skipped.
When every candidate fails, the client throws `StrategyApiException` with a
message telling the user to start the backend or deploy the API path. Passing
`baseUrl` overrides both candidates, which is used by unit tests.

The client also accepts a `tokenProvider` callback. `MainNavigationScreen`
supplies `() => authStore.token`, so every request carries
`Authorization: Bearer <jwt>` once the user signs in. `withToken()` copies the
client while preserving injected test clients and base URLs.

## 5. Why this belongs in the backend

- Playbook values are shared business data, not UI state.
- Rulebook verification and MT5 ticket payloads are audit data produced by the
  service that will eventually read MT5 assignments.
- Draft validation and ownership must be authoritative on the server.
- The Flutter models contain no hard-coded business data.

## 6. Verification

- `cd backend && npm run build` — passed.
- `flutter test` — includes overview/detail/create/API-client and auth suites.
- `flutter analyze` — no new errors or warnings.
- `flutter build web --debug --no-wasm-dry-run` — passed.
- Live endpoint checks are documented in `backend/README.md`.

## 7. Limitations

- The deployed same-origin `/api/strategies` route is not implemented here; the
  local NestJS backend is the working source in this build.
- MT5 assignment, audit report generation and real adherence computation remain
  future backend work.
- Creating a draft persists it for the user but does not add a playbook to the
  public overview catalogue.
