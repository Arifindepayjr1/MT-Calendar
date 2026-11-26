# Backend Auth & Postgres Persistence — Implementation Specification

## 1. Purpose

Strategy catalogue data, rulebooks, user accounts and drafts now live entirely
in `backend/`. The backend uses NestJS + TypeORM + Postgres, issues JWT access
tokens on sign-up/login, and protects draft creation and draft listing with a
Bearer-token guard. Flutter keeps only decoding models and HTTP clients.

## 2. Files added and changed

| File | Purpose |
| --- | --- |
| `backend/src/app.module.ts` | Loads `.env`, registers TypeORM `postgres` connection and `AuthModule`. |
| `backend/src/main.ts` | Adds global `ValidationPipe` (whitelist + transform) in front of all `/api` routes. |
| `backend/src/auth/user.entity.ts` | `users` table: uuid id, unique email, name, hidden bcrypt hash. |
| `backend/src/auth/auth.models.ts` | Sign-up/sign-in DTOs with class-validator rules and auth response types. |
| `backend/src/auth/auth.service.ts` | Email normalisation, bcrypt hashing/comparison, JWT issuance, conflict/unauthorized errors. |
| `backend/src/auth/auth.controller.ts` | `POST /api/auth/signup`, `POST /api/auth/login` (`/signin` alias), `GET /api/auth/me`. |
| `backend/src/auth/jwt.strategy.ts` | Passport JWT strategy; validates the token subject still exists in Postgres. |
| `backend/src/auth/jwt-auth.guard.ts` | Reusable `AuthGuard('jwt')`. |
| `backend/src/auth/current-user.decorator.ts` | Injects the validated user (or a single field) into protected handlers. |
| `backend/src/auth/auth.module.ts` | Registers user repository, Passport, JwtModule and exports auth providers. |
| `backend/src/strategies/entities/*.ts` | TypeORM entities for playbooks, rules, MT5 tickets and per-user drafts. |
| `backend/src/strategies/strategy-category.enum.ts` | Single source of truth for allowed category strings. |
| `backend/src/strategies/strategies.seed.ts` | Four playbooks with their rules and tickets, inserted on first run. |
| `backend/src/strategies/strategies.service.ts` | Reads from Postgres, builds DTOs, saves/lists drafts for the authenticated user. |
| `backend/src/strategies/strategies.controller.ts` | Public catalogue/detail routes plus Bearer-protected draft routes. |
| `backend/src/strategies/strategy.models.ts` | Validated `CreateStrategyDto` and all response interfaces. |
| `backend/.env.example`, `backend/docker-compose.yml` | Local configuration and Postgres 16 container. |
| `backend/README.md` | Setup, data model, endpoint and API-client docs. |
| `backend/bruno/auth/*`, `backend/bruno/strategies/*` | Bruno requests with token capture and protected requests. |
| `backend/postman/*.json` | Postman collection and local environment. |
| `lib/model/auth.model.dart` | Decodes JWT session and public user. |
| `lib/services/auth_api_service.dart` | Sign-up/login/me client with server-aware errors. |
| `lib/services/auth_store.dart` | JWT/user session holder with optional SharedPreferences persistence. |
| `lib/screens/auth.screen.dart` | Dark-theme sign in / sign up form. |
| `lib/screens/settings.screen.dart` | Settings tab with session status, sign-in and sign-out controls. |
| `lib/main.dart`, `lib/screens/main_navigation.screen.dart` | Initialise the store and attach the Bearer token to strategy requests. |
| `test/auth_api_service_test.dart`, `test/auth_screen_test.dart` | Client and widget coverage for auth. |
| `implement/backend_auth_and_database_spec.md` | This document. |

## 3. Database

TypeORM connects with `autoLoadEntities: true`; `DB_SYNCHRONIZE=true` creates
the schema in development. `docker-compose.yml` exposes Postgres on host port
`5433` with a named volume. A local Postgres cluster on that port works too.

Tables:

- `users` — uuid pk, unique lowercased email, display name, `passwordHash`
  (`select: false`), nullable `framework`, `createdAt`.
- `auth_codes` — uuid pk, email, bcrypt-hashed 6-digit code and password hash
  (both `select: false`), name, framework, `expiresAt`, `attempts`, `createdAt`.
  Short-lived; deleted when a code is consumed or replaced.
- `playbooks` — stable slug pk, card metrics, hero/telemetry metrics, status and
  sync labels, jsonb badges.
- `strategy_rules` — uuid pk, `entry | risk` group, position, text, verified,
  cascade delete from playbook.
- `strategy_trades` — uuid pk, position, pair, lots, entry, exit, pnl,
  compliant, cascade delete from playbook.
- `strategy_drafts` — uuid pk, owning user, full form payload (jsonb arrays),
  created timestamp.

`StrategiesService.onModuleInit` seeds the four playbooks only when the table is
empty. All reads afterwards come from Postgres, so editing a row changes every
client on its next fetch.

## 4. Auth flow

1. `POST /api/auth/signup` validates email, 8–72 character password and name,
   lowercases the email, hashes the password with bcrypt (12 rounds) and saves
   the user. A duplicate email returns `409`.
2. `POST /api/auth/login` (alias `/signin`) loads the hidden hash explicitly,
   compares it, and returns `401` on any mismatch.
3. Both responses contain `{ accessToken, tokenType: 'Bearer', expiresIn,
   user: { id, email, name } }`. `JWT_SECRET` and `JWT_EXPIRES_IN` come from
   `.env` with development defaults.
4. `JwtStrategy` reads the Bearer header, checks expiry/signature and rejects
   tokens whose `sub` no longer exists in `users`.
5. `GET /api/auth/me` returns the validated public user.
6. The Create Account → OTP path uses `POST /auth/request-code` to store a
   hashed 6-digit code (10-minute TTL, five attempts) and `POST /auth/verify-code`
   to create the user with the stored hash and return the same JWT shape.
   With `SMTP_APP_PASSWORD` set, Nodemailer emails the code to the registered
   address and `devCode` is omitted; otherwise development echoes it as a
   fallback so the OTP screen remains testable.

Protected strategy routes use `@UseGuards(JwtAuthGuard)` and
`@CurrentUser('id')`, so a draft can never be attributed to another account.

## 5. Endpoints

| Method | Path | Auth | Purpose |
| --- | --- | --- | --- |
| POST | `/api/auth/signup` | public | Create account, return JWT |
| POST | `/api/auth/login` | public | Login, return JWT |
| POST | `/api/auth/request-code` | public | Issue hashed OTP, return devCode in dev |
| POST | `/api/auth/verify-code` | public | Redeem OTP, create user, return JWT |
| GET | `/api/auth/me` | Bearer | Current public user |
| GET | `/api/strategies` | public | Overview cards and KPIs |
| GET | `/api/strategies/:id` | public | Rulebook detail |
| GET | `/api/strategies/drafts` | Bearer | Current user's drafts |
| POST | `/api/strategies` | Bearer | Persist a new draft |
| GET | `/api/mt5/candles` | public | Real MT5 broker OHLC session |

Validation failures return Nest's standard 400 payload. Missing/invalid tokens
return 401; unknown strategy ids return 404 with `{"error":"Strategy not found."}`.

## 6. Flutter session flow

`AuthStore` is initialised in `main()` from SharedPreferences, so a token
survives app restarts. `main()` also initialises `TradeImportStore`; the local
MT5 report is stored under its own SharedPreferences key and is never cleared
by sign-in or sign-out. The app opens on the three-screen auth suite; there is
no guest bypass and the root login step has no back route to Home. The Settings
tab can also open the suite. A successful login or OTP verification saves
`AuthSession` to the store.
`MainNavigationScreen` gives `StrategyApiService` a `tokenProvider` closure that
reads `authStore.token` at request time, so draft POSTs use the current token
and public catalogue reads remain unchanged. `HomeScreen` rehydrates from
`TradeImportStore.data` on construction, so the imported report is still there
after login and after a restart.

## 7. API client tooling

- Bruno: `backend/bruno` collection, `local` environment. `auth/Sign up` and
  `auth/Login` save `accessToken` to the `token` variable via a post-response
  script. `auth/Request code` saves `devCode` to `otp` and `auth/Verify code`
  saves a fresh token. Protected requests send `Authorization: Bearer {{token}}`.
- Postman: import `backend/postman/TraderLog.postman_collection.json` and
  `TraderLog.local.postman_environment.json`. The collection test scripts write
  the same `token`/`otp` variables.

## 8. Verification

- `cd backend && npm run build` — compiles all modules.
- Live checks after starting Postgres and the API:
  sign-up → 201, duplicate sign-up → 409, login → 200, bad login → 401,
  `/auth/me` without token → 401, with token → 200,
  `/strategies` and `/strategies/pb_silver_bullet` → 200,
  `/strategies/drafts` → 200, `POST /strategies` with token → 201 and persists
  across backend restarts.

## 9. Limitations

- `DB_SYNCHRONIZE=true` is development convenience; production needs migrations.
- Seed playbooks are still sample data, not derived from live MT5 executions.
- The Flutter client's auth UI stores its token locally and does not yet refresh
  tokens; the backend issues a long-lived 7-day token by default.
