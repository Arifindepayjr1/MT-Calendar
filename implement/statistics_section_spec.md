# Statistics / Performance Analytics Screen

## Goal

Build the `Statistics` tab as a disciplined trading terminal audit screen. It must read from the signed-in user's imported MT5 trades, journals, and saved setups. It must not show fabricated sample numbers when there is no data.

## Visual system

- **Aesthetic:** institutional dark-mode fintech / trading terminal. Clean, high-contrast, data-dense but breathable, subtle 1px hairline borders, 8px–12px rounded containers.
- **Background:** `#111411` deep obsidian charcoal-green.
- **Card surfaces:** `#191C19` low, `#202320` elevated cards.
- **Hairline border:** `#252B25`.
- **Primary accent:** `#B7F7C4` mint terminal green for active pills, positive P&L, progress rings, and primary CTAs.
- **Positive / win:** `#4ADE80` / `#B7F7C4`.
- **Negative / loss / alert:** `#F87171` soft coral red.
- **Primary text:** `#FFFFFF` / `#F0FDF4`.
- **Muted text:** `#889088` / `#94A3B8`.
- **Typography:** Space Grotesk-like geometric headings and crisp numeric readouts, with clean sans-serif/monospace-style handling for timestamps, ratios, and percentages.

## Layout

### Top app bar

- Pinned-style app bar using the existing `HomeAppBar`.
- Left: TradeLog mark + `Statistics` context.
- Right: existing notification/profile affordances.

### Page header and timeframe filter

- Title: `Performance Analytics`.
- Subtitle: `Disciplined execution audit`.
- Right: account selector pill with a green active dot and `All Accounts ▾`; tooltip shows the active broker/account when available.
- Timeframe segmented pills: `7D`, `30D` (default active), `90D`, `YTD`, `Custom`. Active pill is mint with dark text and a small dot.

### 2x2 KPI summary grid

Cards are driven by trades in the selected timeframe:

- **Net Realized P&L** — mint when positive, coral when negative; sub-metric is P&L per trading day.
- **Win Rate** — `N%`; sub-metric `W W • L L`.
- **Profit Factor** — gross profit / gross loss; `—` when not computable.
- **Expectancy (R)** — average R from entry-to-SL risk; sub-metric average win/loss R, or `No SL data to compute R`.

### Discipline Index card

- Shield icon, title `Discipline Index`, subtitle `Execution process adherence`.
- Circular progress ring and horizontal progress bar from logged rules followed vs. violated.
- Main line: `N of M rules honored`, or `No rules logged yet`.
- Emotional departures line from journal emotional state.
- Optional `Institutional Grade` badge at 85% and above.
- Bottom 2-column split:
  - `Followed Rules` with win rate on setups where rules were logged.
  - `Violated Rules` in coral with win rate on deviations.
- `—` is shown where there is no matching trade/journal data.

### Cumulative Growth Curve card

- Header: `Cumulative Growth Curve`, subtitle with closed-trade count, and a net P&L pill.
- Smooth mint line chart with vertical mint gradient fill and data-point nodes.
- Horizontal grid lines plus `Day 1` → `Day N` labels and a compact peak label.
- Empty state when no closed trades exist in the selected timeframe.

### Strategy Playbooks card

- Header: `Strategy Playbooks` and `Sorted by Net P&L`.
- Rows combine strategy names from journals and the signed-in user's saved setups from NestJS drafts.
- Each row shows strategy name, `trades • WR • avg R`, net P&L, and contribution to total net P&L.
- First row with executions receives a `Primary` badge.
- User-created setups with no executions are shown honestly as `0 trades • — WR • — avg R` and `+$0.00`.

### Session Performance card

- Header with clock icon and `UTC / EST` toggle.
- Rows: `London Session`, `New York Session`, `Asian Session` with win rate and net P&L.
- Horizontal mint/coral bars scaled to the largest absolute session P&L.
- Insight callout: if a losing session exists, suggest discontinuing or filtering it; otherwise state that no statistical leak was detected.

### Primary action

- Full-width mint CTA: `Export Audit Report (PDF / CSV)` with download icon.
- Generates and downloads a CSV audit row set for the selected timeframe on web.
- PDF generation is intentionally not wired; the UI label follows the supplied spec but the confirmation states CSV was downloaded.

## Data rules

- Timeframe filtering uses trade close time.
- All amounts respect the active account currency; cent accounts are displayed in USD.
- Never fabricate KPIs, session rows, or strategy telemetry when trades/journals are missing.
- Saved strategies are loaded through the JWT-scoped `StrategyApiService.fetchDrafts()` and only when a token is present.
- API failure must not block the rest of the Statistics screen.

## Files

- `lib/screens/statistics.screen.dart`
- `lib/screens/statistics_export.dart`
- `lib/screens/statistics_export_web.dart`
- `lib/screens/statistics_export_stub.dart`
- `lib/screens/main_navigation.screen.dart` (tab wiring)
