# Trade Details Screen

## Purpose

Trade Details presents the imported facts for one closed execution alongside its user-authored journal entry. Broker data stays on `Trade`; journal notes, psychology ratings, and screenshot references stay on `Journal`. The screen does not fill missing broker values with estimates.

## Navigation flow

1. Calendar builds its execution list from trades whose local close date matches the selected date. Tapping a date cell changes that selection.
2. An execution row shows the symbol, side, volume, close status, P&L, and saved execution note.
3. Tapping the row opens `TradeDetailScreen` with that `Trade` and the `Journal` looked up by `trade.id`.
4. **Edit Journal Entry** opens the inline journal form. Existing values are loaded from the trade's current journal.
5. Saving returns a `Journal` with `tradeId == trade.id` through the callback. Main navigation stores it under that trade ID; Calendar then shows the saved execution note. Reopening the trade loads the same entry.
6. Importing another MT5 report replaces the trade list and account metadata only. The journal map remains untouched. Imported trades use a stable ticket-based ID, so matching tickets continue to resolve to the same journal during the app session.

## UI hierarchy

### Header and performance summary

- Back button, **Trade Details** title, and a neutral profile avatar.
- Asset symbol, BUY/SELL side, lot size, and WIN/LOSS/BREAK EVEN badge.
- Prominent signed net P&L and realized R multiple. Realized R is price movement in the trade direction divided by the absolute entry-to-stop distance.
- Local entry and exit timestamps, elapsed duration, and an independent close-status badge.
- Close status comes from `Trade.closeReason`: TP HIT (mint), SL HIT or STOP OUT (red), and MANUAL, OTHER EXIT, or UNKNOWN (neutral). The outcome badge comes from net P&L.

### MT5 execution telemetry

- Broker/account label and MT5 report badge. EA verification is marked unavailable because the current execution model has no verification field.
- Responsive two-column metrics: ticket ID, entry price, exit price, stop-loss level/distance, take-profit level/distance, commission, swap, fees, risk capital, planned R:R, and realized R:R.
- FX stop and target distances are shown in pips for six-letter pairs (0.0001, or 0.01 for JPY pairs). Non-FX pip distances are unavailable.
- Planned R:R is calculated only when both levels are present. Realized R:R uses the signed realized R multiple. Missing data appears as `--`.
- The grid uses the available card width and the details content is capped at 920 px on wide displays.

### Journal and psychology

Read view displays all selected strategies/playbooks, 4H market bias, trading session, session narrative, emotional state, discipline grade, pre-entry rating, trade-holding rating, the rule-compliance checklist, execution notes, and key takeaway. Missing fields display `--`.

Edit view provides multi-select chips for reusable strategies, market-bias and emotion selectors, multi-select session chips, a session narrative field, 0–10 rating controls, three rule checkboxes, execution notes, and a key-takeaway field. A trade may have zero, one, or multiple strategies. Narrow layouts wrap chips onto additional lines and stack other fields.

Save retains an existing journal ID and creation time, writes all selected strategy IDs/names, and updates its timestamp and editable fields. Legacy single strategy fields remain populated from the first selection for compatibility. The imported `Trade` is never mutated by journal edits.

### Attachments

- The first two attachments appear in panels labelled **15M Setup** and **1M Execution & Exit**. Extra attachments appear in a removable list.
- **Add Screenshot** opens the image picker. New image bytes are stored as data URIs in `Journal.attachments`, so previews do not depend on temporary picker paths.
- Data-URI images and HTTP(S) image URLs can be previewed. Unsupported legacy local paths show an unavailable placeholder.
- Available previews support in-panel pan/zoom and an expanded dialog with additional zoom. Removing an image marks the journal as edited; the removal is applied when saved.
- Empty panels show a neutral image placeholder. No chart prices or market data are generated.

### Sticky action

A full-width mint button stays below the independently scrolling details content. It says **Edit Journal Entry** in read view and opens the form, scrolling the journal section into view; while editing it says **Save Journal Entry** and saves the current values. Safe-area padding is applied at the bottom.

## Data model relationships

- `Trade` supplies ID, account ID, ticket, symbol, direction, volume, prices, stop/target, timestamps, gross/net P&L, commission, swap, fee, and close reason. Existing JSON conversion is unchanged.
- `Journal` supplies the editable strategies, bias, session, narrative, emotion, ratings, rules, lesson, notes, and attachments. It relates to one execution through `tradeId` and may reference multiple strategies through `strategyIds`; existing single-strategy JSON fields remain readable.
- Main navigation keeps a map keyed by trade ID and passes it to Calendar. Calendar passes the matching entry into Trade Details and writes a saved entry back under the same ID.
- Reimport updates trades and account metadata without clearing or replacing journal records. The current app stores this map in memory; durable storage across process restarts is outside the current architecture.

## Calendar integration

- Selecting a date cell filters executions by local close date.
- Each execution shows TP HIT, SL HIT, MANUAL, STOP OUT, OTHER, or UNKNOWN from `closeReason`; this is independent of the win/loss result.
- Row tap opens Trade Details for that execution and resolves its journal by trade ID.
- Save updates the root journal map. On return, the execution row shows the updated execution note.
- MT5 reimport changes execution data and account metadata; it does not merge journal fields into trades or replace the journal map.

## Empty states

- A trade without a journal shows a short prompt; the edit form can create the first entry.
- Unknown risk capital and EA verification show `--` or an explicit unavailable status. Missing stop/target levels and unavailable R values are not inferred.
- Missing screenshots show neutral placeholders with an add-screenshot action. Unreadable or unsupported attachments show an unavailable message.
- Calendar keeps its existing rest-day and no-import states when the selected date has no executions.

## Responsive behavior

- Details content scrolls independently from the fixed bottom action. On wide viewports it is centered and capped at 920 px.
- Telemetry remains a two-column grid sized from its actual available width, including when embedded in a narrow window.
- Journal summary fields stack label and value on narrow cards; form and attachment controls remain in the same scroll view.
- Image panels fill their available width and expose touch pan/zoom plus an expanded preview.

## Implementation boundaries

- No EA verification or risk-capital field is available, so both remain unavailable. Commission, swap, and fee come directly from the imported trade.
- Pips are calculated only for supported six-character FX pairs. Realized R is unavailable without a nonzero stop distance.
- No model fields or JSON representations are changed by this screen. Journals remain separate from imported executions.
- Screenshot data is stored as image data URIs in the existing journal attachment strings. Very large attachment collections may need a file-backed store if durable persistence is introduced.
