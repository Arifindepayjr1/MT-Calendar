import { ChartWidget } from '@tradecanvas/chart/widget';

const TIMEFRAMES = ['1m', '5m', '15m', '30m', '1h', '4h', '1d'];
const AUTO_PREFIX = 'traderlog:auto:';
const app = document.getElementById('chart');
const status = document.getElementById('status');

let widget;
let chart;
let trade = null;
let timeframe = '1h';
let currentBars = [];
let dataSource = 'Unconfirmed';
let sourceNote = 'No data loaded';
let hasRealVolume = false;
let sessionStart = null;
let sessionEnd = null;
let sessionReason = null;

function notify(type, payload = {}) {
  const message = JSON.stringify({ type, payload });
  if (window.TraderLogChartBridge?.postMessage) {
    window.TraderLogChartBridge.postMessage(message);
  } else if (window.parent !== window) {
    window.parent.postMessage({ source: 'traderlog-chart', message }, location.origin);
  }
}

function barsFromPayload(candles) {
  return (Array.isArray(candles) ? candles : [])
    .filter((c) => [c.time, c.open, c.high, c.low, c.close].every(Number.isFinite))
    .map((c) => ({
      time: Math.round(c.time * 1000),
      open: c.open,
      high: c.high,
      low: c.low,
      close: c.close,
      // Only pass volume the provider actually supplied. A fabricated 0 would
      // be indistinguishable from a real flat-volume session in the tooltip.
      ...(Number.isFinite(c.volume) ? { volume: c.volume } : {}),
      ...(Number.isFinite(c.tickVolume) ? { tickVolume: c.tickVolume } : {}),
      ...(Number.isFinite(c.spread) ? { spread: c.spread } : {}),
      ...(Number.isFinite(c.realVolume) ? { realVolume: c.realVolume } : {}),
    }));
}

function formatPrice(value) {
  const abs = Math.abs(value);
  return value.toFixed(abs >= 100 ? 2 : abs >= 1 ? 4 : 5);
}

// No drawings are created or persisted. The trade is shown only with compact
// time+price markers at its exact imported execution values.

// Fallback for hosts that do not send ready-made markers. Normal loads send
// markers from TradeChartMarkers at the trade's exact time and price.
// TradeCanvas positions these at the exact supplied time and price (including
// fractional sub-candle times), never at candle OHLC.
function automaticMarkers(t) {
  const buy = String(t.type).toLowerCase() === 'buy';
  const entry = Date.parse(t.openTime);
  const exit = Date.parse(t.closeTime);
  if (!Number.isFinite(entry) || !Number.isFinite(exit)) return [];
  const reason = String(t.closeReason ?? 'unknown');
  const exitColors = {
    takeProfit: '#2ED47A',
    stopLoss: '#FF4D4D',
    stopOut: '#FF4D4D',
    manual: '#F3B65B',
    other: '#B9C3BC',
    unknown: '#B9C3BC',
  };
  const exitLabels = {
    takeProfit: 'TP',
    stopLoss: 'SL',
    stopOut: 'STOP OUT',
    manual: 'MANUAL EXIT',
    other: 'EXIT',
    unknown: 'EXIT',
  };
  return [
    {
      id: AUTO_PREFIX + t.id + ':entry-marker',
      time: entry,
      price: Number(t.openPrice),
      direction: buy ? 'long' : 'short',
      confidence: 1,
      source: 'TraderLog entry',
      color: '#FFFFFF',
      label: `${buy ? 'BUY' : 'SELL'} ${formatPrice(Number(t.openPrice))}`,
      meta: { traderLogAutomatic: true, tradeId: String(t.id) },
    },
    {
      id: AUTO_PREFIX + t.id + ':exit-marker',
      time: exit,
      price: Number(t.closePrice),
      direction: buy ? 'short' : 'long',
      confidence: 1,
      source: 'TraderLog exit',
      color: exitColors[reason] ?? '#B9C3BC',
      label: `${exitLabels[reason] ?? 'EXIT'} ${formatPrice(Number(t.closePrice))}`,
      meta: { traderLogAutomatic: true, tradeId: String(t.id) },
    },
  ];
}

function baseStatus() {
  return dataSource + ' · ' + sourceNote + ' · ' + timeframe.toUpperCase();
}

function applySeries(payload) {
  const nextBars = barsFromPayload(payload.candles);
  if (!nextBars.length) { notify('chartError', { message: 'No valid OHLC bars were supplied to the chart.' }); return; }
  const nextTrade = payload.trade;
  if (!nextTrade || typeof nextTrade.id !== 'string') { notify('chartError', { message: 'Trade data is missing or invalid.' }); return; }
  trade = nextTrade;
  timeframe = TIMEFRAMES.includes(payload.timeframe) ? payload.timeframe : '1h';
  currentBars = nextBars;
  // The Flutter host only sends dataSource 'MT5' when the NestJS bridge
  // confirmed `source: "mt5"`. Never label an unconfirmed payload as MT5.
  dataSource = payload.dataSource === 'MT5' ? 'MT5' : 'Unconfirmed';
  sourceNote = payload.sourceNote || 'Broker history';
  sessionStart = Number.isFinite(payload.sessionStart) ? payload.sessionStart : null;
  sessionEnd = Number.isFinite(payload.sessionEnd) ? payload.sessionEnd : null;
  sessionReason = typeof payload.sessionReason === 'string' ? payload.sessionReason : null;
  hasRealVolume = currentBars.some((bar) => Number.isFinite(bar.volume));
  widget.setData(currentBars);
  chart.setVolumeVisible(hasRealVolume);
  const markers = Array.isArray(payload.markers)
    ? payload.markers
    : automaticMarkers(trade);
  chart.setSignalMarkers(
    markers.filter((marker) => marker && Number.isFinite(marker.time) &&
      Number.isFinite(marker.price)),
  );
  status.textContent = baseStatus() + ' · historical';
  notify('seriesLoaded', {
    timeframe,
    bars: currentBars.length,
    source: dataSource,
    hasVolume: hasRealVolume,
    sessionStart,
    sessionEnd,
    sessionReason,
  });
}

// Zoom to the full broker session supplied by MT5. The app already fetched
// every real bar before entry and after exit; this only changes the visible
// span — no replay and no data slicing.
function focusTradeWindow() {
  if (!chart || !currentBars.length || !trade) return;
  const barMs = {
    '1m': 60_000, '5m': 300_000, '15m': 900_000, '30m': 1_800_000,
    '1h': 3_600_000, '4h': 14_400_000, '1d': 86_400_000,
  }[timeframe] ?? 3_600_000;
  const entry = Date.parse(trade.openTime) || currentBars[0].time;
  const close = Date.parse(trade.closeTime) || entry;
  const last = currentBars[currentBars.length - 1].time;
  const from = sessionStart ?? entry - 4 * barMs;
  const to = sessionEnd ?? Math.max(close, last) + 4 * barMs;
  try {
    chart.setVisibleRange(from, to);
  } catch {
    chart.fitContent();
  }
}

function onReady(readyChart, readyWidget) {
  chart = readyChart;
  widget = readyWidget;
  chart.setSignalMarkerStyle({
    showLabel: true,
    showConfidence: false,
    arrowSize: 10,
  });
  chart.on('barClick', (event) => notify('barSelected', event.data || {}));
  chart.on('crosshairMove', (event) => {
    const data = event.data || {};
    const bar = data.bar;
    // The built-in tooltip is disabled below because it would render the
    // library's missing-volume placeholder as 0. Flutter's overlay only shows
    // volume when the provider actually supplied it.
    notify('crosshairMoved', {
      time: data.time ?? bar?.time ?? null,
      open: bar?.open ?? null,
      high: bar?.high ?? null,
      low: bar?.low ?? null,
      close: bar?.close ?? null,
      volume: hasRealVolume && Number.isFinite(bar?.volume) ? bar.volume : null,
      tickVolume: Number.isFinite(bar?.tickVolume) ? bar.tickVolume : null,
      spread: Number.isFinite(bar?.spread) ? bar.spread : null,
      realVolume: Number.isFinite(bar?.realVolume) ? bar.realVolume : null,
    });
  });
  chart.on('crosshairLeave', () => notify('crosshairMoved', { time: null }));
  notify('chartReady', { version: '2.16.0' });
}

function dispatch(raw) {
  let message = raw;
  if (typeof raw === 'string') {
    try { message = JSON.parse(raw); }
    catch { notify('chartError', { message: 'Invalid message from TraderLog.' }); return; }
  }
  if (!message || typeof message.type !== 'string') return;
  if (message.type === 'loadSeries') applySeries(message.payload || {});
  else if (message.type === 'focusTrade' || message.type === 'fitSession') focusTradeWindow();
  else if (message.type === 'fitAll') chart?.fitContent();
  else if (message.type === 'toggleCrosshair') {
    if (!chart) return;
    const next = chart.getCrosshairMode() === 'hidden' ? 'normal' : 'hidden';
    chart.setCrosshairMode(next);
    notify('crosshairChanged', { visible: next !== 'hidden' });
  }
}

window.TraderLogChartApi = { dispatch };
window.addEventListener('message', (event) => {
  if (event.source !== window.parent || event.data?.source !== 'traderlog-chart-command') return;
  dispatch(event.data.message);
});
window.addEventListener('error', (event) => notify('chartError', { message: String(event.message || 'Chart script error.') }));
window.addEventListener('unhandledrejection', (event) => notify('chartError', { message: String(event.reason || 'Chart error.') }));

widget = new ChartWidget(app, {
  symbol: 'TraderLog', timeframe, theme: 'dark', ui: 'terminal', locale: 'en',
  toolbar: false, drawingTools: false, trading: false, watchlist: false,
  symbolInfo: false, alerts: false, layouts: false, statusBar: true,
  rangeBar: false, fullscreen: false, objectTree: false,
  timeframes: TIMEFRAMES, customTimeframes: false, resampleTimeframes: false,
  features: {
    replay: false,
    'toolbar.replay': false,
    fullscreen: false,
    'toolbar.fullscreen': false,
  },
  chartOptions: {
    chartType: 'candlestick', renderer: 'auto', autoScale: true, pageScroll: false,
    features: {
      drawings: false, drawingUndoRedo: false, trading: false,
      panning: true, zooming: true, crosshair: true,
      // Flutter renders the tooltip so it can omit provider-missing volume.
      crosshairTooltip: false,
      saveLoad: false,
    },
  },
  onReady,
});

