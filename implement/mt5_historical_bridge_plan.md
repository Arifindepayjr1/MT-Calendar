# MT5 Historical Trade Review — Implementation Plan & Summary

## Decision

The user asked **not to use FastAPI** because the project already has a NestJS
backend. The public HTTP API therefore stays entirely in NestJS.

The official `MetaTrader5` package is Python-only, so NestJS owns and spawns one
**internal Python stdio worker**. The worker is not an HTTP server and is never
exposed on a port. Communication is newline-delimited JSON over stdin/stdout
with request IDs, pending promises and timeouts.

```text
Flutter app
  → NestJS /api/mt5/*        (only public HTTP API, validation + cache)
    → Python MT5 worker      (child process, stdio JSON, read-only)
      → MetaTrader5 Python package
        → local MT5 terminal → broker history
```

No trading operations are exposed. No MT5 password is stored in source code.

## Local environment

- Python 3.12.10 is available via `py -3.12`; Python 3.15 is the default but is
  too new for the MetaTrader5 wheel. Use the `backend/.venv` created with
  `py -3.12 -m venv .venv`.
- Live verification used `C:\Program Files\MetaTrader 5\terminal64.exe`, broker
  `Exness Technologies Ltd`, server `Exness-MT5Real37`, symbol `XAUUSDc`.
- A second broker terminal is installed at
  `C:\Program Files\VT Markets (Pty) MT5 Terminal\terminal64.exe`. The exact
  broker symbol from the imported trade is always used verbatim; symbols are
  never guessed or normalized to Yahoo-style tickers.
- The chart engine is TradeCanvas (`@tradecanvas/chart` 2.16.0) in
  `chart_engine/`, built into `web/trade_chart/` and `assets/trade_chart/`.
  It is preserved; only its data source and payload were extended.

## Implemented components

### 1. Python stdio worker — `backend/mt5_worker.py`

One JSON request per line. Commands:

- `status` — initialize/terminal/broker/connection info. Failures are reported
  in the reply; they do not crash the worker.
- `symbols` — `mt5.symbols_get()` with an optional case-insensitive search and
  a bounded response. Symbols are **not** filtered to visible-only, because
  hidden broker symbols are still valid for history.
- `candles` — `mt5.copy_rates_range()` over a bounded UTC window around the
  requested date, with `mt5.copy_rates_from_pos()` as a bounded fallback.
- `latest` — `mt5.copy_rates_from_pos()` for the most recent real bars.
- `ticks` — `mt5.copy_ticks_range()` for read-only tick samples.

Every reply has `id`, `ok`, and either `data` or `error`. The worker never writes
passwords, account numbers or tokens. It reuses one initialized MT5 connection
for the process lifetime and reports a clear disconnected/error state when
initialization fails.

### 2. Full-session selection

For intraday timeframes (M1–H4):

1. Validate `date` (`YYYY-MM-DD`) and `timeframe`
   (`M1/M5/M15/M30/H1/H4/D1`).
2. Fetch a bounded UTC window covering the requested date and nearby broker
   activity, capped by `MT5_MAX_REQUEST_BARS` (default 5000).
3. Sort and de-duplicate bars by timestamp.
4. Infer broker sessions from real data gaps. A gap larger than
   `MT5_SESSION_GAP_MULTIPLIER × timeframe seconds` (default 3×) starts a new
   session, bounded by `MT5_MAX_SESSION_HOURS` (default 30). This follows the
   broker's actual data rather than assuming local midnight.
5. Select the real session overlapping the requested UTC date; when several
   sessions touch it, pick the one with the most bars on that date.
6. If there is no broker history for that date (weekend/holiday), return
   `candles: []` with `reason: "no_data_for_date"` or `"no_broker_history"`.
   Nothing is fabricated.
7. Return the **entire selected session**, including bars before entry and after
   exit. Bars are never trimmed to trade entry/exit.

For D1, a small centered window of real daily bars (default 14) is returned so
surrounding context is still available.

Returned candles use UTC ISO-8601 strings plus numeric epoch seconds, and carry
`tickVolume`, `spread` and `realVolume` when the broker supplies them:

```json
{
  "symbol": "XAUUSDc",
  "date": "2026-11-24",
  "timeframe": "M15",
  "source": "mt5",
  "timezone": "UTC",
  "sessionStart": "2026-11-23T23:00:00Z",
  "sessionEnd": "2026-11-24T21:45:00Z",
  "reason": null,
  "count": 92,
  "candles": [
    {
      "timestamp": 1763937600,
      "time": "2026-11-23T23:00:00Z",
      "open": 2651.12,
      "high": 2653.40,
      "low": 2650.88,
      "close": 2652.91,
      "tickVolume": 1832,
      "spread": 12,
      "realVolume": 0
    }
  ]
}
```

A broker-reported `0` real volume is kept as real data; the Flutter client
never converts it into a fabricated non-zero volume.

### 3. NestJS module — `backend/src/mt5/`

- `mt5.module.ts`, `mt5.controller.ts`, `mt5.service.ts`, `mt5.models.ts`.
- `Mt5Service` spawns the Python venv worker, manages request IDs, pending
  promises, startup/exit handling, request timeouts and an in-memory TTL cache
  keyed by `command + payload`.
- Controller routes use individual `@Query()` decorators so the application's
  global `ValidationPipe({ whitelist: true })` cannot strip parameters.
- Public routes:
  - `GET /api/mt5/status` — soft-degrades to HTTP 200 with
    `initialized: false`, `connected: false` and a readable `error`.
  - `GET /api/mt5/symbols?search=`
  - `GET /api/mt5/candles?symbol=&date=&timeframe=`
  - `GET /api/mt5/latest?symbol=&timeframe=&count=`
  - `GET /api/mt5/ticks?symbol=&start=&end=&limit=` (read-only, future live use)
- No WebSocket is implemented. `/api/mt5/ticks` prepares that future work.
- Error mapping: `400` validation/invalid symbol/date/timeframe, `404` unknown
  broker symbol, `502` failed MT5 call, `503` disconnected/package missing/
  worker unavailable, `504` worker timeout. Empty sessions are a successful
  `200` with `candles: []` and a `reason`, not an error.
- Configuration via `backend/.env`: `MT5_PYTHON`, `MT5_WORKER_PATH`,
  `MT5_TERMINAL_PATH`, `MT5_REQUEST_TIMEOUT_MS`, `MT5_CACHE_TTL_SECONDS`,
  `MT5_SESSION_GAP_MULTIPLIER`, `MT5_MAX_SESSION_HOURS`, `MT5_MAX_REQUEST_BARS`.

### 4. Flutter integration

- `lib/services/mt5_candle_service.dart` calls the NestJS `/api/mt5/*` routes
  with the existing `baseUrl`/injectable `http.Client` pattern. It maps the
  chart interval to the exact MT5 timeframe (`1m→M1`, `5m→M5`, `15m→M15`,
  `30m→M30`, `1h→H1`, `4h→H4`, `1d→D1`), sends the trade's exact broker symbol
  and UTC execution date, and never trims the returned session.
- `MarketCandle`/`MarketCandleSeries` live in
  `lib/services/market_candle.dart`. They are provider-neutral containers with
  no request logic. Source, session bounds, reason, broker and date are carried
  into the chart.
- `TradeCandleService` is an MT5-only facade over `Mt5CandleService`. An MT5
  failure is surfaced as a clear error; there is no fallback provider, no
  `yahoo-fallback` source and no Yahoo proxy call anywhere in the chart flow.
- `lib/widgets/trade_candlestick_chart.dart` and `trade_chart_webview.dart` wire
  the existing trade-detail chart to the MT5-only facade. Opening a trade fetches
  one broker-session series for the trade's exact symbol and UTC date and opens
  framed on that date. There are no date pickers, timeframe selectors, refresh,
  replay, full-screen controls or saved drawing layers.
- `TradeChartMarkers.entryExit()` uses the actual execution timestamp and price:
  `BUY`/`SELL` entry and `TP`/`SL`/`STOP OUT`/`MANUAL EXIT`/`EXIT` exit. No
  full-width entry/SL/TP lines, rectangles or zones are drawn.

### 5. Chart engine — `chart_engine/src/main.js`

- `setData()` receives the full MT5 session only; no synthetic or replay data.
- Loads carry `dataSource`, `source`, `sourceNote`, `sessionDate`,
  `sessionStart`, `sessionEnd` and `sessionReason`. The chart frames the full
  broker session around the trade on every load.
- Built-in TradeCanvas toolbar, drawing tools, object tree, save/load and replay
  are disabled; only pan, zoom and crosshair remain.
- Candle tooltips show real OHLC plus real/tick volume and spread when supplied.
- Generated bundles in `web/trade_chart/` and `assets/trade_chart/` were rebuilt
  with `npm run build` in `chart_engine/`.

## Tests and verification

- `backend`: `.\.venv\Scripts\python.exe -m pytest tests/test_mt5_worker.py -q`
  → **15 passed** (fake MT5: connected/disconnected, unknown symbol, available
  session, weekend/holiday, unsorted/duplicate bars, timeframes, ticks).
- `frontend`: `flutter test`, including MT5 service tests for exact
  symbol/date/timeframe mapping, full-session ordering and volume fields,
  adjacent-date override, HTTP errors, empty weekend result, broker metadata and
  MT5-only failure propagation. `test/mt5_chart_flow_test.dart` taps a completed
  trade in Trade History and verifies the single `/api/mt5/candles` request,
  the absence of `/api/candles` and the visible `Data Source: MT5` badge.
- `flutter analyze` → no errors; only pre-existing informational lints.
- `flutter build web --debug --no-wasm-dry-run` → passed.
- `backend`: `npm run build` → passed.
- `chart_engine`: `npm run build` → passed and synced chart assets.
- Live API check: `/api/mt5/status` reported connected to
  `Exness Technologies Ltd` / `Exness-MT5Real37`;
  `/api/mt5/candles?symbol=XAUUSDc&date=2026-11-24&timeframe=M15` returned
  92 real bars from `2026-11-23T23:00:00Z`, proving full-session context.

## Documentation

- `implement/mt5_windows_setup.md` — Windows setup, endpoints and safety notes.
- `backend/README.md`, `backend/.env.example`, `backend/requirements-mt5.txt`.
- Root `README.md` — MT5-only chart flow, endpoint overview and chart build
  instructions.
- Both implementation docs are allowlisted in the root `.gitignore` so they can
  be versioned.

## Future work

- Add `/ws/mt5/market` for live ticks if live updating is requested; stream
  incremental updates instead of calling `setData()` per tick.
- No trading or order endpoints are planned.
