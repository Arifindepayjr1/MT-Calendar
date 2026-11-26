# MT5 Historical Review — Windows Setup

The public API is still the existing NestJS backend on port `3000`. There is no
FastAPI service and no second HTTP port. NestJS spawns a small Python worker
over stdin/stdout; the worker uses the official `MetaTrader5` package and is
read-only.

```text
Flutter app → NestJS /api/mt5/* → Python stdio worker → local MT5 terminal → broker history
```

## 1. Install the Python 3.12 environment

The official `MetaTrader5` wheel is available for Python 3.12. Python 3.15 is
too new, so pin the interpreter explicitly.

From `backend/`:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements-mt5.txt
```

Run the worker unit tests:

```powershell
.\.venv\Scripts\python.exe -m pytest tests/test_mt5_worker.py -q
```

No broker terminal is needed for these tests; they inject a fake MT5 module.

## 2. Start and log in to MetaTrader 5

1. Open the broker terminal you use for the journal. Live verification used
   `C:\Program Files\MetaTrader 5\terminal64.exe` with broker
   `Exness Technologies Ltd` and server `Exness-MT5Real37`. A second terminal
   exists at `C:\Program Files\VT Markets (Pty) MT5 Terminal\terminal64.exe`.
2. Log in to the broker account that has the historical data.
3. Leave the terminal running. The Python package connects to that terminal;
   it does not ask for, store, or transmit your MT5 password.

If multiple terminals are installed, set the exact terminal in `backend/.env`:

```dotenv
MT5_TERMINAL_PATH=C:\Program Files\MetaTrader 5\terminal64.exe
```

All worker defaults are optional. Other tunable values are documented in
`backend/.env.example`.

## 3. Start NestJS

From `backend/`:

```powershell
npm run build
npm run start:prod
```

The MT5 routes are added automatically to the existing API:

| Endpoint | Purpose |
| --- | --- |
| `GET /api/mt5/status` | Terminal initialized/connected, broker and server names, error if disconnected |
| `GET /api/mt5/symbols?search=XAU` | Exact broker symbols available from the terminal |
| `GET /api/mt5/candles?symbol=XAUUSDc&date=2026-11-24&timeframe=M15` | Full broker session OHLC candles |
| `GET /api/mt5/latest?symbol=XAUUSDc&timeframe=M15&count=200` | Latest real candles for “go to latest” |
| `GET /api/mt5/ticks?symbol=XAUUSDc&start=...&end=...` | Read-only ticks for future live-candle work |

Use the **exact symbol from the imported trade**; the example above uses the
verified Exness symbol `XAUUSDc`, not a guessed or Yahoo-style ticker.

Quick checks:

```powershell
curl http://127.0.0.1:3000/api/mt5/status
curl "http://127.0.0.1:3000/api/mt5/symbols?search=XAU"
curl "http://127.0.0.1:3000/api/mt5/candles?symbol=XAUUSDc&date=2026-11-24&timeframe=M15"
```

`status` soft-degrades to HTTP 200 with `initialized: false`, `connected: false`
and a readable `error` when the terminal is closed or not logged in. Candle
requests return clear errors: `400` for validation problems, `404` for an
unknown broker symbol, `502` for a failed MT5 call, `503` when MT5/the worker is
unavailable, and `504` if the worker times out. A weekend or holiday is a
successful `200` with `candles: []` and a `reason` — no candles are fabricated.

## 4. Timezone and session behavior

- MT5 candle times are emitted as UTC ISO-8601 strings (`...Z`) and epoch
  seconds. The response includes `"timezone": "UTC"`.
- For M1–H4, the worker asks MT5 for a bounded UTC window covering the requested
  date plus nearby broker activity. It groups real bars into broker sessions
  using observed gaps and a maximum session span, then returns every bar in the
  sessions overlapping the requested date. This preserves price action before
  entry and after exit and does not assume midnight in the PC timezone.
- Weekends and holidays return `candles: []` with a `reason` such as
  `no_broker_history` or `no_data_for_date`; no candles are fabricated.
- Duplicate timestamps are removed and bars are sorted by timestamp.
- D1 returns a centered window of real daily bars around the requested date.
- `copy_rates_range()` is the primary history call. `copy_rates_from_pos()` is
  used for latest-candle requests and as a bounded fallback. `copy_ticks_range()`
  powers the read-only ticks endpoint.

## 5. App behavior

Tapping a trade loads MT5 broker history first through `/api/mt5/candles`. The
chart shows the whole broker session, including bars before entry and after
exit, with exact `BUY`/`SELL` and exit markers at the imported execution prices.
Toolbar controls let you choose another session date (UTC), timeframe, fit the
full session, inspect the latest real candle and reload. Zoom/scroll is kept
when data reloads.

If MT5 is unavailable or the symbol is unknown, the chart shows the MT5 error
and a Retry button. No other data provider is contacted and no candles are
fabricated. The `Data Source: MT5 | Broker: … | Symbol: …` badge appears only
when the backend confirmed `source: "mt5"` and reported the connected broker.

## 6. Scope and safety

- The bridge exposes no order operations. It only calls
  `initialize`, `terminal_info`, `account_info`, `version`, `last_error`,
  `symbols_get`, `symbol_info`, `symbol_select`, `copy_rates_range`,
  `copy_rates_from_pos`, and `copy_ticks_range`.
- No MT5 password, login, or account number is returned by `/status`.
- The Python worker binds no port and is spawned by NestJS with stdio only.
- Repeated candle/symbol requests are cached in NestJS for
  `MT5_CACHE_TTL_SECONDS` (default 60 seconds).

## 7. Future live data

`/api/mt5/ticks` is ready for live-candle preparation. When a WebSocket is
added, it should stream tick updates under `/ws/mt5/market` and the TradeCanvas
chart should apply incremental updates, never a full `setData()` per tick.
No WebSocket is implemented yet; historical review is fully available now.
