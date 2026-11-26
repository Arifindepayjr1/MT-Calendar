# TradeCanvas historical trade analysis — implementation strategy

> **Superseded by the simplified MT5 chart.** The current chart fetches broker
> candles for the trade's date, frames that session and shows only exact
> entry/exit markers. Timeframe/date controls, full-screen mode, replay and
> persisted user drawings are no longer part of the UI. See `README.md` and
> `implement/mt5_historical_bridge_plan.md` for the current design. The sections
> below are retained as historical context.

## 1. Architecture that was preserved

The existing stack is unchanged:

- TradingView **Lightweight Charts** through `@tradecanvas/chart`.
- Vite ES-module bundle in `chart_engine/`.
- Flutter iframe (web) / WebView (native) bridge.
- NestJS `/api/mt5/*` bridge to an internal Python MetaTrader5 stdio worker.
- Existing trade model, imported prices and persisted user drawings.

No second chart library and no replay layer were introduced. The widget's own
`replay` capability, replay toolbar button and duplicate full-screen button are
explicitly disabled in `ChartWidget` options.

## 2. Broker candle loading

The trade-history chart has exactly one data path:

`Flutter → NestJS /api/mt5/candles → Python MetaTrader5 → connected MT5 terminal`

The exact broker symbol from the imported trade is sent unchanged. The worker
uses `mt5.copy_rates_range()` and returns the whole session around the trade's
UTC execution date. There is no Yahoo Finance proxy, no Cloudflare function and
no dev candle proxy. Start the NestJS backend on port 3000 before running the
chart; an unavailable MT5 terminal produces a visible error, not a substitute
feed.

## 3. Real timeframe switching

`TradeChartWindow` in `lib/services/trade_chart_window.dart` is the single
source of truth for supported intervals (1m, 5m, 15m, 30m, 1h, 4h, 1d) and
their context windows:

| Interval | Before entry | After exit |
| --- | --- | --- |
| 1m | 2 h | 1 h |
| 5m | 6 h | 2 h |
| 15m | 1 day | 4 h |
| 30m | 2 days | 8 h |
| 1h | 3 days | 1 day |
| 4h | 14 days | 3 days |
| 1d | 60 days | 10 days |

These are defaults, not zoom limits. `focusTrade` only calls
`chart.setVisibleRange()`; it never slices the loaded data.

`Mt5CandleService.loadForTrade()` now:

- rejects unsupported intervals before making a request,
- maps the selected interval to the exact MT5 timeframe with no substitution,
- requests the session for the trade's exact broker symbol and UTC date,
- keeps the trade's original entry/SL/TP values untouched,
- surfaces no-data and API errors as `Mt5CandleException`, which the UI shows
  as an empty/error state.

`TradeChartWindow.effective()` resolves the interval used by both inline and
full-screen charts. Selecting a timeframe in either place reloads that real
interval and updates the other view.

## 4. Compact time+price markers (no full-width levels)

`automaticDrawings()` is gone. No `horizontalLine`, `priceLabel`, rectangle,
trade zone or shaded risk/reward drawing is created for a trade. The original
entry, SL and TP values stay untouched in the trade model; only their
presentation changed.

`TradeChartMarkers.build()` in `lib/services/trade_chart_markers.dart` produces
the marker payload sent through `loadSeries`:

- `BUY`/`SELL` entry marker at `openTime` and `openPrice`,
- exit marker at `closeTime` and `closePrice`, labelled `TP`, `SL`,
  `STOP OUT`, `MANUAL EXIT` or `EXIT` from the broker's `closeReason`,
- optional `TP TOUCHED` (green) and `SL TOUCHED` (red) neutral dots at the
  first touching candle and the corresponding level price.

All times are milliseconds like the candle series, so TradeCanvas places them
with `timestampToBarIndex()` (fractional for sub-candle times) and `priceToY()`.
They are never snapped to candle OHLC and stay attached through zoom, scroll,
reload and timeframe changes. `chart.setDrawings()` receives only user
drawings; legacy automatic drawings are filtered out by `meta.traderLogAutomatic`.
Signal markers are not drawings and are not persisted by `getDrawings()`.

## 5. Accurate TP/SL detection

`analyseTradeLevels()` in `lib/services/trade_level_analysis.dart` is pure and
unit-testable. It inspects only candles from entry through the actual exit:

- BUY: TP when `high >= TP`, SL when `low <= SL`.
- SELL: TP when `low <= TP`, SL when `high >= SL`.
- Missing SL/TP never produces a touch.
- A candle touching both levels is reported as ambiguous; no order is assumed.
- Entry/exit outside the loaded series is flagged rather than guessed.

The Flutter legend shows exact entry/exit times and prices, first touch times,
trade outcome and the broker close reason. Same-candle double touches use the
exact message `SL and TP touched in the same candle — exact order unknown.`
A wick touch is displayed separately from "Broker closed at TP/SL" because OHLC
evidence alone cannot prove the broker's fill.

## 6. Crosshair and controls

The JS bridge emits a compact `crosshairMoved` message with time, OHLC and a
nullable volume. Flutter shows a readable OHLC(V) overlay; volume is omitted
when the provider did not supply it. TradeCanvas continues to draw price/time
axis crosshair labels.

Inline and full-screen charts expose zoom-to-trade, fit-all and crosshair
toggle. Full-screen adds the timeframe selector, refresh and close. User
analysis remains in `SharedPreferences`.

## 7. Data accuracy

Candles are the connected broker's own OHLC from MT5. Imported entry, SL, TP
and exit prices are authoritative and are never replaced by candle values. The
service handles invalid JSON, non-JSON responses, 404/503 errors, unsupported
intervals, empty sessions and missing volume without fabricating data. The
chart's `Data Source: MT5 | Broker: … | Symbol: …` badge is shown only when the
backend confirmed `source: "mt5"`.

## 8. Bridge messages

Flutter → JS: `loadSeries`, `restoreAnalysis`, `captureAnalysis`, `focusTrade`,
`fitAll`, `toggleCrosshair`.

JS → Flutter: `chartReady`, `seriesLoaded`, `chartError`, `analysisChanged`,
`timeframeChanged`, `crosshairMoved`, `crosshairChanged`, `barSelected`,
`drawingCreated`, `drawingUpdated`, `drawingDeleted`.

`decodeChartMessage()` tolerates malformed JSON and nested payloads.

## 9. Verification

- `flutter analyze` — no errors or warnings; 12 pre-existing info lints remain
  in unrelated widget files.
- `flutter test` — 17 tests pass, including timeframe windows, buy/sell hit
  detection, same-candle ambiguity, missing levels/data, out-of-range trades,
  bridge decoding and payload integrity.
- `flutter build web --debug` — succeeds.
- `cd chart_engine && npm run build` — regenerates both chart bundles.
- Live API smoke test: `/api/mt5/status` reports the connected broker, and
  `/api/mt5/candles` returns real broker bars for the requested symbol/date.

Manual check:

```sh
cd backend && npm run start:prod
# second terminal
flutter run -d web-server --web-port=8080
# open http://localhost:8080 and tap a completed trade
```

## 10. Limitations

- MT5 broker history retention is controlled by the broker/terminal; an old
  trade may have no bars for a fine timeframe. The app shows that reason
  instead of substituting another provider or interval.
- "Latest candle" reads the newest real MT5 bar; the ticks endpoint prepares
  live data but no WebSocket stream is implemented.
- Candle/symbol responses are cached in NestJS for `MT5_CACHE_TTL_SECONDS`.
- A candle that touches both SL and TP cannot be ordered from OHLC alone;
  lower-timeframe or tick data would be required to resolve it.
- The chart requires a running NestJS backend and a logged-in MT5 terminal;
  there is no offline or third-party chart feed.

## 11. Calendar typography

| Location | Before | After |
| --- | --- | --- |
| Monthly Net P&L | 23 | 27 |
| Day session P&L | 20 | 24 |
| Per-trade profit | 12 | 14 |
| Per-day profit in grid | 8 | 10 |
