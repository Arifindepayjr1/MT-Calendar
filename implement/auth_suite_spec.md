# TradeLog Authentication Suite — Implementation Spec

## Scope

Three mobile screens in the "Disciplined Ledger" dark theme plus local
persistence of the uploaded MT5 report. The backend remains the source of truth
for accounts and JWTs; the imported report belongs to the device so signing in
can never discard it.

## Theme tokens

`lib/theme/ledger_theme.dart` centralises the palette:
`#111411` background, `#191C19/#202320/#2B2E2A/#373A36` surfaces, `#B7F7C4`
mint accent, `#F0FDF4` primary text, `#889088/#94A3B8` muted text,
`#252B25/#2D352D` hairline borders and `#4ADE80/#F87171` status colours.
Headers and numeric fields use tabular/Space-Grotesk-style geometry with
monospace labels for terminal data.

## Screens

### 1. Log In (`lib/screens/auth/login_step.screen.dart`)

Pinned app bar (back chevron, centred "Log In" + chart mark, profile avatar).
Centred padlock hero, "Welcome Back, Trader", terminal email field with a
syntax check badge and `AUTHORIZED ONLY` tag, masked master cipher with a
reveal toggle, "Trust this terminal (30 days)" checkbox, "Forgot Cipher?", the
mint `Sign In to TradeLog →` CTA, registration switch and TLS footnote.

Submitting calls `POST /api/auth/login` through `AuthApiService`. The trust
checkbox is passed to `AuthStore.saveSession(..., remember:)`; unchecked means
the JWT lives only for the current app run.

### 2. Create Account (`lib/screens/auth/create_account_step.screen.dart`)

Pinned bar, `STEP 1 OF 2: TRADER PROFILE` + 50% progress, headline and
description, trader handle, broker/work email, a 2x2 selectable framework grid
(ICT / SMC, Price Action, Order Flow (DOM), Scalp Execution), vault passphrase
with a live four-segment entropy meter, Pro-Sync callout, terms checkbox and
`Send Verification Code →`.

Submitting calls `POST /api/auth/request-code`. The returned development
`devCode` is carried into the next step; production requires an email/SMS
provider.

### 3. OTP Verification (`lib/screens/auth/otp_verification_step.screen.dart`)

Pinned bar, shield hero, destination email chip with edit affordance, six
PIN slots with auto-advance/cursor, clipboard paste chip, 46-second resend
countdown + "Resend SMS", institutional token banner, 3x4 custom numeric
keypad (biometric / 0 / backspace), `Verify & Launch TradeLog →` and TLS
footnote. Hardware keyboard digits and backspace are also accepted.

Verifying calls `POST /api/auth/verify-code`, saves the JWT and lands on the
TradeLog Home tab. Resend reissues the code and restarts the timer.

`lib/screens/auth.screen.dart` coordinates the three steps and their shared
loading/error state. `main()` shows the suite first; authentication is required,
so the root login step has no guest bypass and no back route to Home. Back is
only shown on Create Account / OTP to move between auth steps. Settings can
reopen the suite at any time.

## Imported report persistence

`lib/services/trade_import_store.dart` serializes the parsed MT5 report —
trades (via `Trade.toJson`/`fromJson`), account name, broker, currency, balance
and sync subtitle — under `traderlog_import_v1` in SharedPreferences.

- `HomeScreen.initState()` rehydrates from `TradeImportStore.data`.
- `HomeScreen._uploadFile()` saves immediately after parsing, before any
  navigation.
- `MainNavigationScreen` reads the store for the Home/Calendar/Strategies tabs
  and rebuilds when it changes.
- `AuthStore.clear()` never touches the import store.
- Settings shows the saved trade count so the trader can confirm it survived.

This means: import report → log in → same report; restart app → same report;
sign out → same report.

## Backend OTP support

`backend/src/auth/auth-code.entity.ts` stores a bcrypt-hashed code, the hashed
passphrase, name, framework, expiry and attempt counter in `auth_codes`.
`/auth/request-code` replaces any previous code for the email and, when
`SMTP_APP_PASSWORD` is configured, emails the 6-digit code with Nodemailer via
Gmail to that same address; `/auth/verify-code` validates, creates the user with
the stored hash, deletes the code and returns the normal JWT response. Without
SMTP configured, `AUTH_DEV_CODE=true` echoes the code in `devCode` as a local
fallback and the OTP screen shows a "Local dev code" hint.

## Verification

- `flutter test` — 64 tests (login, create→OTP→launch, OTP API client, import
  persistence, sign-in/out preserving imports, existing suites).
- `flutter analyze` — no errors/warnings (12 pre-existing info lints).
- `flutter build web --debug --no-wasm-dry-run` — passes.
- `cd backend && npm run build` — passes.
- Live API: request-code `200`, wrong code `401`, verify-code `200` with the
  selected framework, `/auth/me` `200`, duplicate request `409`, login with the
  OTP-created account `200`.
