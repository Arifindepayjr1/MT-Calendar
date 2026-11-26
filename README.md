# trader_log

A new Flutter project.

## Authentication and saved MT5 reports

The app opens on a three-screen terminal auth suite — Log In, Create Account
and OTP Verification — backed by the NestJS JWT endpoints in `backend/`. Log In
uses `POST /api/auth/login`; Create Account requests a 6-digit code and the OTP
screen redeems it for a JWT. With `SMTP_APP_PASSWORD` set in `backend/.env`,
Nodemailer emails that code from `arifindepayjr@gmail.com` to the address typed
on Create Account; otherwise development shows the code on the OTP screen.
Authentication is required: the root login screen has no guest bypass and no
back route to Home. Settings can reopen the suite at any time. See
`implement/auth_suite_spec.md` for the full design.

Strategies saved from Create Strategy are owned by the signed-in user in
Postgres through `POST /api/strategies`. Saving closes the form and returns to
the refreshed Strategies tab, where the setup appears at the top of **All
Setups** with a "Your Setup" badge. It filters by category and opens the exact
same `Strategy Details` screen as a shared playbook — hero, stats, rules, trade
log and actions — with honest zero/empty stats until MT5 trades are assigned.
After login, the tab calls the
Bearer-protected `GET /api/strategies/drafts`; another account's setups are
never returned. Signed-out users see only the shared playbook catalogue.

Uploaded MT5 HTML/Excel reports are parsed on the Home tab and saved to
`SharedPreferences` by `TradeImportStore`. They survive login, sign-out and app
restarts: importing a report, logging in, then reopening the app shows the same
trades, balance and account context. Charts show broker candles only: there are
no saved drawings or annotation layers.

## Trade chart

Tapping a trade opens its detail screen and a TradeCanvas candlestick chart
hosted in a WebView (an iframe in the web build). The chart loads **only MT5
broker history** through the existing NestJS backend:

```text
Flutter → NestJS /api/mt5/candles → internal Python stdio worker → local MT5 terminal
```

The exact broker symbol from the imported trade (for example `XAUUSDc`) is
passed through unchanged — no futures mapping or symbol guessing. For the
trade's UTC execution date, the worker returns the **entire broker session**:
real bars before entry and after exit are kept, never trimmed to the trade
duration. Weekends and holidays return an explicit empty result with a reason;
nothing is fabricated. Times are UTC, bars are sorted and de-duplicated, and
tick volume, spread and broker real volume are carried into the chart tooltip
when available.

The chart is intentionally plain: opening a trade fetches MT5 candles for that
trade's exact broker symbol and UTC date, then frames the full broker session
around the trade. There are no drawing tools, annotation layers, timeframe or
date pickers, replay, full-screen mode, or refresh controls.

`BUY`/`SELL` and the exit marker (`TP`, `SL`, `STOP OUT`, `MANUAL EXIT` or
neutral `EXIT`) sit at the imported execution time and price, including
sub-candle seconds. There are no full-width entry/SL/TP lines, rectangles,
zones or shaded areas. The crosshair tooltip shows real OHLC, real/tick volume
and spread only when the provider supplied them.

If MT5 is disconnected, the symbol is unavailable, or the backend is not
running, the chart shows a clear MT5 error with a Retry button. There is no
alternative data provider and no fallback feed. The chart displays
`Data Source: MT5 | Broker: <broker> | Symbol: <broker symbol>` only when the
backend confirms the series came from MT5 and reports the connected broker.

Design notes are in `implement/mt5_historical_bridge_plan.md`; Windows setup is
in `implement/mt5_windows_setup.md`.

Chart sources live in `chart_engine/`. After changing the chart source:

```sh
cd chart_engine
npm install
npm run build
cd ..
```

The build refreshes both `web/trade_chart/` (used by the web iframe) and
`assets/trade_chart/` (used by native WebViews). If the generated chunk
filenames change, update the explicit asset list in `pubspec.yaml`.

Native WebViews load the bundled chart from a loopback HTTP server because ES
modules are blocked on `file://` origins. iOS/macOS allow local networking via
`NSAllowsLocalNetworking`; Android enables cleartext traffic for the local
address. Windows uses WebView2 and requires the WebView2 runtime.

## Candlestick data endpoint

- `GET /api/mt5/candles?symbol=<exact broker symbol>&date=YYYY-MM-DD&timeframe=M15`
  on the NestJS backend (port 3000). It is read-only and uses the locally
  logged-in MT5 terminal through an internal Python stdio worker. There is no
  FastAPI service, no second HTTP port and no Yahoo Finance proxy.
- `GET /api/mt5/status` reports the terminal connection, broker and server.

`flutter run -d chrome` does not serve backend routes automatically. Start
`npm run start:prod` in `backend/` before opening the chart.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
