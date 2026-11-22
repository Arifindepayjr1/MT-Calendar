# TradeCanvas historical trade analysis — implementation strategy

## 1. Architecture that was preserved

The existing stack is unchanged:

- TradingView **Lightweight Charts** through `@tradecanvas/chart`.
- Vite ES-module bundle in `chart_engine/`.
- Flutter iframe (web) / WebView (native) bridge.
- Cloudflare Pages candle function in `functions/api/candles.js`.
- Local development proxy in `chart_engine/scripts/dev-candles.mjs`.
- Existing trade model, imported prices and persisted user drawings.

No second chart library and no replay layer were introduced. The widget's own
`replay` capability, replay toolbar button and duplicate full-screen button are
explicitly disabled in `ChartWidget` options.

## 2. Web dev candle loading

Browsers block direct Yahoo Finance requests from the app origin. The web
chart requests `/api/candles` on its own origin; the Cloudflare Pages function
validates the request and forwards it to Yahoo.

- `npx wrangler pages dev build/web` serves both static files and the function.
- `flutter run -d chrome` only serves static files. Unknown paths return
  `index.html` (HTTP 200 with HTML), so the service treats a non-JSON body as
  "function missing" and falls back to `http://127.0.0.1:8787/api/candles`.

The fallback proxy imports the exact production `onRequest` handler and adds
CORS headers, so validation is identical in dev and production.

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

`YahooCandleService.loadForTrade()` now:

- rejects unsupported intervals before making a request,
- uses the exact requested interval with no silent substitution,
- derives `period1`/`period2` from the selected window,
- keeps the trade's original entry/SL/TP values untouched,
- surfaces no-data and API errors as `CandleDataException`, which the UI shows
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

XAUUSD/XAGUSD map to Yahoo futures (`GC=F`/`SI=F`) and are labelled as proxies,
not MT5 spot prices. Imported MT5 entry, SL, TP and exit prices are authoritative
and are never replaced by candle values. The candle service handles invalid
JSON, non-JSON dev-server responses, 404s, 429s, unsupported intervals, empty
responses and missing volume without fabricating data.

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
- Local smoke tests: the dev proxy and Pages function reject invalid intervals
  and return real Yahoo OHLC for valid requests.

Manual check:

```sh
cd chart_engine && npm run dev:proxy
# second terminal
flutter run -d web-server --web-port=8080
# open http://localhost:8080
```

Or, without the proxy:

```sh
flutter build web
npx wrangler pages dev build/web
```

## 10. Limitations

- Yahoo minute/hour data has provider retention limits; an old trade may have
  no data for a fine timeframe. The app shows that error instead of silently
  substituting another interval.
- "Live" refresh is bounded by the 7-day recency rule and the proxy's 30 s
  cache; it is the latest Yahoo candle, not tick streaming.
- Gold/silver candles are futures proxies and may not match the broker's spot
  feed. Imported trade prices remain the source of truth.
- A candle that touches both SL and TP cannot be ordered from OHLC alone;
  lower-timeframe or tick data would be required to resolve it.
- The dev proxy is only for local development; hosted builds need a real
  same-origin `/api/candles` endpoint.

## 11. Calendar typography

| Location | Before | After |
| --- | --- | --- |
| Monthly Net P&L | 23 | 27 |
| Day session P&L | 20 | 24 |
| Per-trade profit | 12 | 14 |
| Per-day profit in grid | 8 | 10 |
