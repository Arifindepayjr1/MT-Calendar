# trader_log

A new Flutter project.

## Advanced trade chart

Each trade opens with a TradeCanvas candlestick chart hosted in a WebView
(an iframe in the web build). It fetches **real Yahoo Finance OHLC candles**
around the trade's open/close timestamps — no replay and no synthetic data.
Choose 1m, 5m, 15m, 30m, 1H, 4H or 1D: each selection reloads the real OHLC
series with its own before/after context, frames the trade window, and keeps
the same selected timeframe in full-screen mode.

Trade levels are shown only as compact markers — there are **no full-width
entry/SL/TP lines, rectangles, zones or shaded areas**. `BUY`/`SELL` and the
exit marker (`TP`, `SL`, `MANUAL EXIT` or neutral `EXIT`) sit at the imported
execution time and price, including sub-candle seconds. Small `TP TOUCHED` and
`SL TOUCHED` dots mark the first candle that reached each level before the
actual exit. The crosshair tooltip shows real OHLC and volume only when the
provider supplied it. The legend reports exact entry/exit times and prices,
first touches, the outcome and the broker's close reason. When one candle
touches both levels, it reports `SL and TP touched in the same candle — exact
order unknown.` instead of guessing.

Full-screen controls provide the timeframe selector, zoom-to-trade, fit-all,
crosshair toggle, refresh and close. You can still draw, measure and save your
own annotation layers; automatic markers are not user drawings and are never
saved. Drawings are stored per trade in `SharedPreferences`, so re-importing
the MT5 statement does not erase your analysis.

Use the **Advanced / Simple** switch above the chart to choose between the
full WebView chart and the lightweight Flutter `CustomPainter` chart.

> XAUUSD/XAGUSD use Yahoo futures contracts (`GC=F`/`SI=F`) as proxies. Their
> prices are not identical to an MT5 spot feed. Imported entry, SL, TP and exit
> prices always remain authoritative; only the candles are proxy data.

The full design notes are in `implement/trade_canvas_replay_strategy.md`.

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

## Candlestick data in the web app

Browsers block direct requests from this app to Yahoo Finance. The web chart now requests `/api/candles` from the app's own origin; `functions/api/candles.js` is the matching Cloudflare Pages Function. It validates the symbol, interval, and requested time range before forwarding the request to Yahoo Finance.

To preview the web app with the function locally, build it and run Cloudflare Pages dev from the repository root:

```sh
flutter build web
npx wrangler pages dev build/web
```

For a hosted web build, deploy `build/web` together with the repository's `functions` directory on Cloudflare Pages so `/api/candles` is served on the same origin. Other hosts need an equivalent same-origin `/api/candles` endpoint that forwards the query to Yahoo Finance. Desktop and mobile builds continue to request Yahoo Finance directly.

`flutter run -d chrome` by itself does not start the Pages Function, so the same-origin endpoint returns 404. The app then falls back to a local dev proxy on `http://127.0.0.1:8787`. Start it in a second terminal before running Flutter:

```sh
cd chart_engine
npm install
npm run dev:proxy
```

The proxy reuses `functions/api/candles.js`, so dev and production apply the same validation. You do not need it when using `wrangler pages dev build/web`.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
