import { ChartWidget } from '@tradecanvas/chart/widget';

const TIMEFRAMES = ['1m', '5m', '15m', '30m', '1h', '4h', '1d'];
const AUTO_PREFIX = 'traderlog:auto:';
const app = document.getElementById('chart');
const status = document.getElementById('status');
const isPrototype = new URLSearchParams(location.search).has('prototype');

let widget;
let chart;
let trade = null;
let timeframe = '1h';
let currentBars = [];
let restoring = false;
let saveTimer;
let dataSource = 'Yahoo Finance';
let sourceNote = 'Historical OHLC';
let hasRealVolume = false;

function notify(type, payload = {}) {
  const message = JSON.stringify({ type, payload });
  if (window.TraderLogChartBridge?.postMessage) {
    window.TraderLogChartBridge.postMessage(message);
  } else if (window.parent !== window) {
    window.parent.postMessage({ source: 'traderlog-chart', message }, location.origin);
  } else if (isPrototype) {
    document.documentElement.dataset.lastMessage = type;
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
    }));
}

function formatPrice(value) {
  const abs = Math.abs(value);
  return value.toFixed(abs >= 100 ? 2 : abs >= 1 ? 4 : 5);
}

// No automatic horizontalLine/priceLabel drawings are created: the trade is
// shown only with compact time+price markers. Legacy automatic drawings that
// may already be stored are filtered out by validUserDrawings().

// Fallback used only by the built-in prototype payload, which has no Dart
// marker builder. Normal loads send ready-made markers from TradeChartMarkers.
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

function validUserDrawings(drawings) {
  if (!Array.isArray(drawings)) return [];
  return drawings.filter((drawing) => drawing && typeof drawing.id === 'string' &&
    !drawing.meta?.traderLogAutomatic && Array.isArray(drawing.anchors));
}

function baseStatus() {
  return dataSource + ' · ' + sourceNote + ' · ' + timeframe.toUpperCase();
}

function applySeries(payload) {
  const nextBars = barsFromPayload(payload.candles);
  if (!nextBars.length) { notify('chartError', { message: 'No valid OHLC bars were supplied to the chart.' }); return; }
  const nextTrade = payload.trade;
  if (!nextTrade || typeof nextTrade.id !== 'string') { notify('chartError', { message: 'Trade data is missing or invalid.' }); return; }
  restoring = true;
  trade = nextTrade;
  timeframe = TIMEFRAMES.includes(payload.timeframe) ? payload.timeframe : '1h';
  currentBars = nextBars;
  dataSource = payload.dataSource || 'Yahoo Finance';
  sourceNote = payload.sourceNote || 'Historical OHLC';
  hasRealVolume = currentBars.some((bar) => Number.isFinite(bar.volume));
  try {
    widget.setData(currentBars);
    chart.setVolumeVisible(hasRealVolume);
    // Only user drawings are persistent. Automatic levels used to be stored
    // as locked drawings; legacy copies are dropped by validUserDrawings().
    chart.setDrawings(validUserDrawings(payload.drawings));
    const markers = Array.isArray(payload.markers)
      ? payload.markers
      : automaticMarkers(trade);
    chart.setSignalMarkers(
      markers.filter((marker) => marker && Number.isFinite(marker.time) &&
        Number.isFinite(marker.price)),
    );
  } finally { restoring = false; }
  status.textContent = baseStatus() + ' · historical';
  if (isPrototype) document.documentElement.dataset.prototypeBars = String(currentBars.length);
  notify('seriesLoaded', {
    timeframe,
    bars: currentBars.length,
    source: dataSource,
    hasVolume: hasRealVolume,
  });
}

// Zoom to the actual trade window. The app already fetched the correct
// historical time range, so this only changes the visible span — no replay and
// no data slicing.
function focusTradeWindow() {
  if (!chart || !currentBars.length || !trade) return;
  const barMs = {
    '1m': 60_000, '5m': 300_000, '15m': 900_000, '30m': 1_800_000,
    '1h': 3_600_000, '4h': 14_400_000, '1d': 86_400_000,
  }[timeframe] ?? 3_600_000;
  const entry = Date.parse(trade.openTime) || currentBars[0].time;
  const close = Date.parse(trade.closeTime) || entry;
  const last = currentBars[currentBars.length - 1].time;
  try {
    chart.setVisibleRange(entry - 4 * barMs, Math.max(close, last) + 4 * barMs);
  } catch {
    chart.fitContent();
  }
}

function scheduleAnalysisSave() {
  if (restoring || isPrototype || !trade) return;
  clearTimeout(saveTimer);
  saveTimer = setTimeout(() => {
    const drawings = chart.getDrawings().filter((drawing) => !drawing.meta?.traderLogAutomatic);
    notify('analysisChanged', {
      tradeId: trade.id, symbol: trade.symbol, timeframe, drawings,
      settings: { theme: 'dark', ui: 'terminal', timeframe },
    });
  }, 400);
}

const PRESETS = [
  ['Bullish FVG', 'rectangle', { color: '#45C48B', fillColor: '#45C48B', fillOpacity: 0.2, lineWidth: 1.5, text: 'Bullish FVG', textColor: '#B7F7C4' }],
  ['Bearish FVG', 'rectangle', { color: '#FF7C7C', fillColor: '#FF7C7C', fillOpacity: 0.2, lineWidth: 1.5, text: 'Bearish FVG', textColor: '#FFB5B5' }],
  ['Order Block', 'rectangle', { color: '#4C8DFF', fillColor: '#4C8DFF', fillOpacity: 0.17, lineWidth: 1.5, text: 'Order Block' }],
  ['Breaker Block', 'rectangle', { color: '#B38CFF', fillColor: '#B38CFF', fillOpacity: 0.17, lineWidth: 1.5, text: 'Breaker Block' }],
  ['Mitigation Block', 'rectangle', { color: '#F3B65B', fillColor: '#F3B65B', fillOpacity: 0.17, lineWidth: 1.5, text: 'Mitigation Block' }],
  ['Premium Zone', 'rectangle', { color: '#FF7C7C', fillColor: '#FF7C7C', fillOpacity: 0.13, lineWidth: 1, text: 'Premium' }],
  ['Discount Zone', 'rectangle', { color: '#45C48B', fillColor: '#45C48B', fillOpacity: 0.13, lineWidth: 1, text: 'Discount' }],
  ['BSL · Buy-Side Liquidity', 'horizontalLine', { color: '#74A5FF', lineWidth: 1.5, lineStyle: 'dashed', text: 'BSL' }],
  ['SSL · Sell-Side Liquidity', 'horizontalLine', { color: '#FF9D85', lineWidth: 1.5, lineStyle: 'dashed', text: 'SSL' }],
  ['BOS', 'horizontalLine', { color: '#F3B65B', lineWidth: 1.5, text: 'BOS' }],
  ['MSS', 'horizontalLine', { color: '#B38CFF', lineWidth: 1.5, text: 'MSS' }],
  ['CHOCH', 'horizontalLine', { color: '#64C8D7', lineWidth: 1.5, text: 'CHOCH' }],
];

function addSmcMenu() {
  widget.addToolbarDropdown({
    id: 'traderlog-smc-presets', label: 'ICT / SMC presets', text: 'SMC', icon: 'layers', side: 'left',
    items: () => PRESETS.map(([label, tool, style]) => ({
      label,
      onSelect: () => {
        chart.setDrawingStyle(style);
        chart.setDrawingTool(tool);
        chart.setStayInDrawingMode(true);
        notify('presetSelected', { label, tool });
      },
    })),
  });
}

function onReady(readyChart, readyWidget) {
  chart = readyChart;
  widget = readyWidget;
  chart.setSignalMarkerStyle({
    showLabel: true,
    showConfidence: false,
    arrowSize: 10,
  });
  addSmcMenu();
  chart.on('drawingCreate', (event) => { notify('drawingCreated', { id: event.data?.id, tool: event.data?.type }); scheduleAnalysisSave(); });
  chart.on('drawingUpdate', (event) => { notify('drawingUpdated', { id: event.data?.id }); scheduleAnalysisSave(); });
  chart.on('drawingRemove', (event) => { notify('drawingDeleted', { id: event.data?.id }); scheduleAnalysisSave(); });
  chart.on('drawingSelect', (event) => notify('drawingSelected', event.data || {}));
  chart.on('historyChange', (event) => notify('undoRedoChanged', event.data || {}));
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
    });
  });
  chart.on('crosshairLeave', () => notify('crosshairMoved', { time: null }));
  chart.on('stateChange', scheduleAnalysisSave);
  notify('chartReady', { version: '2.16.0' });
  if (isPrototype) {
    document.getElementById('prototype').style.display = 'block';
    applySeries(makePrototypeData());
  }
}

function dispatch(raw) {
  let message = raw;
  if (typeof raw === 'string') {
    try { message = JSON.parse(raw); }
    catch { notify('chartError', { message: 'Invalid message from TraderLog.' }); return; }
  }
  if (!message || typeof message.type !== 'string') return;
  if (message.type === 'loadSeries') applySeries(message.payload || {});
  else if (message.type === 'restoreAnalysis') {
    restoring = true;
    try {
      chart.setDrawings(validUserDrawings(message.payload?.drawings));
    } finally { restoring = false; }
  } else if (message.type === 'captureAnalysis') {
    const drawings = chart.getDrawings().filter((drawing) => !drawing.meta?.traderLogAutomatic);
    notify('analysisSnapshot', { timeframe, drawings, settings: { theme: 'dark', ui: 'terminal', timeframe } });
  } else if (message.type === 'focusTrade') focusTradeWindow();
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
  toolbar: true, drawingTools: true, trading: false, watchlist: false,
  symbolInfo: false, alerts: false, layouts: false, statusBar: true,
  rangeBar: true, fullscreen: false, objectTree: true,
  timeframes: TIMEFRAMES, customTimeframes: false, resampleTimeframes: false,
  // This is a historical trade view. Hide the library's replay capability,
  // replay toolbar button and duplicate full-screen button entirely.
  features: {
    replay: false,
    'toolbar.replay': false,
    fullscreen: false,
    'toolbar.fullscreen': false,
  },
  chartOptions: {
    chartType: 'candlestick', renderer: isPrototype ? 'canvas' : 'auto', autoScale: true, pageScroll: false,
    features: {
      drawings: true, drawingUndoRedo: true, trading: false,
      panning: true, zooming: true, crosshair: true,
      // Flutter renders the tooltip so it can omit provider-missing volume.
      crosshairTooltip: false,
      saveLoad: true,
    },
  },
  onReady,
  onTimeframeChange: (nextTimeframe) => {
    if (!TIMEFRAMES.includes(nextTimeframe)) return;
    timeframe = nextTimeframe;
    if (!restoring && !isPrototype) notify('timeframeChanged', { timeframe });
  },
});

function makePrototypeData() {
  const candles = [];
  const end = Date.now() - 60 * 60 * 1000;
  let price = 2350;
  for (let i = 0; i < 180; i++) {
    const open = price;
    const change = Math.sin(i / 6) * 1.8 + Math.cos(i / 11) * 1.1;
    const close = open + change;
    candles.push({ time: Math.floor((end - (180 - i) * 3600 * 1000) / 1000), open, close, high: Math.max(open, close) + 1.2, low: Math.min(open, close) - 1.1, volume: 100 + i });
    price = close;
  }
  const openTime = candles[110].time * 1000;
  const closeTime = candles[145].time * 1000;
  return {
    timeframe: '1h', dataSource: 'Prototype OHLC', sourceNote: 'synthetic test data', candles, drawings: [],
    trade: { id: 'prototype-trade', symbol: 'XAUUSD', type: 'buy', volume: 0.1, openPrice: candles[110].open, closePrice: candles[145].close, stoploss: candles[105].low, takeProfit: candles[160].high, openTime: new Date(openTime).toISOString(), closeTime: new Date(closeTime).toISOString(), netProfit: 10 },
  };
}
