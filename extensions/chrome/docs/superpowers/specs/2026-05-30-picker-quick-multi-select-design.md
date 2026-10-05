# Picker Quick Multi-Select — Design Spec

Date: 2026-05-30
Status: Approved (brainstorming) — pending implementation plan

## Purpose

Make the element picker feel like "click several blocks fast, then apply once."
Today the building blocks already exist — a selection *session* (multiple cards),
numbered highlights of what is already picked, and one batched apply — but the
interaction is heavy: every element forces a trip through the precise preview
panel, and each "add to card" tears down and rebuilds the whole picker via
`startPicker()`. This redesign keeps every existing capability but changes the
default interaction to quick toggling, and untangles the picker controller into
focused modules so the new behavior drops in cleanly (no closure swamp).

## Interaction model (the new default)

- **Hover** highlights the current candidate element (unchanged), and `Tab`
  still cycles overlapping candidates so you can pick which stacked element.
- **Single click = toggle that element into the session**, using a selector that
  matches *only the clicked element*. Clicking an already-selected element
  removes it. No panel opens; the picker stays active — you keep clicking.
- **Already-selected elements stay visible** with numbered colored outlines
  (existing `applySelectionSessionHighlights`), refreshed live after each toggle.
- A **session panel** (bottom-left) lists each card: number, editable name,
  scope, selector, a **다듬기 (refine)** button, and a remove button, plus
  **완료 적용 (apply all)** and **세션 취소 (cancel)**.
- **다듬기** opens the precise panel (match count, 좁히기/넓히기, selector
  candidates) for *that one card*, editing its selector in place; closing returns
  to quick picking.
- **완료 적용** persists every card at once (existing `persistSelectionSession`).
  `Escape` or **세션 취소** discards the session and stops.
- **iframe**: clicking an iframe still offers the iframe choice panel (hide frame
  / enter frame); that flow is preserved.

### Selecting exactly one element

A quick toggle commits a selector that uniquely matches the clicked element:
prefer the highest-ranked candidate from `buildSelectorCandidates(el)` whose match
count is exactly 1; otherwise fall back to `buildSelector(el)` (the precise path
selector). This guarantees "이 요소 하나만" — no accidental over-selection.

### De-selecting (re-click to remove)

On click, resolve the target element, then check whether it already belongs to
the session by testing `element.matches(entry.selector)` against entries in the
same frame scope. Because session selectors match exactly one element, this
reliably identifies a re-click and removes that entry.

## Non-goals (YAGNI)

- No keyboard shortcuts (separate, already-shipped feature).
- No "select all similar" expansion — quick click is element-specific by choice.
- No live hiding during picking; picked elements stay *visible* (marked) so they
  can be seen and toggled; hiding happens only on 완료 적용.
- No change to storage schema, message types, or permissions.
- No modifier-click refine path (refine is reached from the session card button).

## Architecture: untangle the controller into focused modules

Today `startPicker()` is one ~390-line closure holding session data, hover
targeting, overlay state, lifecycle flags, and two giant nested handlers
(`handleClick`, `renderCandidate`). The redesign splits responsibilities so each
file does one thing with a clear interface. All are content global scripts
(no import/export; shared global scope; load order set in the three content-script
lists — manifest, build.mjs, service-worker.ts).

| Module | Responsibility | Interface (representative) |
|---|---|---|
| `picker-session.ts` (new, **data core**) | Owns the selection session; the **only** writer of `selectionSession`. Builds element-specific selectors, toggles/edits entries, persists. | `sessionToggleElement(el)`, `sessionIsSelected(el)`, `sessionRemove(id)`, `sessionUpdateSelector(id, sel)`, `sessionRename(id, name)`, `sessionClear()`, `sessionEntries()`, `sessionPersist()` |
| `picker-hover.ts` (new) | Pointer → ranked target elements; current target; Tab cycling. | `hoverUpdateAt(x, y)`, `hoverCurrentTarget()`, `hoverCycle(dir)`, `hoverReset()` |
| `picker-overlay.ts` (exists) | Highlight rects, label, status badge, session highlights. | unchanged |
| `picker-analysis.ts` (exists) | Element scoring + labels. | unchanged |
| `picker-session-panel.ts` (new) | Renders the session list panel incl. the 다듬기 button. | `renderSessionPanel({ onRefine, onDone, onCancel })` |
| `picker-refine-panel.ts` (new) | The precise panel (formerly `buildPreviewPanel`); edits one existing card. | `openRefinePanel(cardId, { onClose })` |
| `picker-iframe.ts` (new) | iframe choice panel + frame entry. | `buildIframePanel(...)`, `startPickerInIframe(...)` |
| `picker-ui.ts` (controller, slimmed) | Event wiring only: mousemove→hover, click→toggle/iframe, keydown→cycle/escape, scroll/resize→sync; `stopPicker`; `hideTargetElement`. | `startPicker()` |

**Key rule:** no module mutates `selectionSession` directly — all writes go
through `picker-session.ts`. `picker-overlay`/panels read it but never write.

The controller's click handler collapses to roughly:

```
const el = hoverCurrentTarget();
if (!el) { stopPicker(); return; }
if (el is iframe) { buildIframePanel(...); return; }
sessionToggleElement(el);
syncOverlay();                 // redraw highlights
renderSessionPanel({ ... });   // refresh list
```

No `startPicker()` restart. No nested `renderCandidate` swamp — that logic moves
into `picker-refine-panel.ts`, reached only on demand.

## Data flow

1. **Quick toggle:** click → controller resolves `hoverCurrentTarget()` →
   `sessionToggleElement(el)` (adds element-specific card or removes existing) →
   controller redraws overlay highlights + session panel. Picker stays active.
2. **Refine:** session card 다듬기 → `openRefinePanel(cardId)`. The panel
   re-resolves the live element via `document.querySelector(entry.selector)`,
   rebuilds the depth chain, and lets the user narrow/widen/choose a candidate;
   each change calls `sessionUpdateSelector(cardId, newSelector)` and redraws.
   If the element can no longer be found, the panel shows "요소를 찾을 수 없음".
   Closing returns to quick picking.
3. **Apply:** 완료 적용 → `sessionPersist()` (writes each card via `addSiteRule`)
   → `renderAllRules()` → `stopPicker()`.
4. **Cancel/Escape:** `sessionClear()` → `stopPicker()`.

## Edge cases

- Empty session + 완료 적용: button disabled (existing behavior).
- Re-click an element whose selector no longer matches (DOM changed): treated as
  a new add, not a remove — acceptable and predictable.
- Refine target removed from DOM: refine panel reports it; the card keeps its old
  selector until edited or removed.
- iframe entry: unchanged; on entering a frame the outer picker tears down as it
  does today.
- Overlapping/stacked elements: `Tab` cycles candidates before the click decides.

## Testing

The picker is entirely content-side (global scripts), which `node:test` cannot
import, so it has no unit tests today and this feature keeps that boundary. The
pure array operations inside `picker-session.ts` (add / remove-by-id /
update-by-id / find) are written as small, obviously-correct helpers.

Verification is the chrome-devtools MCP flow (`vibecode-chrome-devtools-mcp-testing`):
click several blocks → each gets a numbered outline and a session-panel row;
re-click one → it de-selects; 다듬기 → precise panel narrows/widens that card;
완료 적용 → all hide at once and persist; reload → rules still applied; iframe
click still offers the frame panel. `./infocutter check` (lint + typecheck +
existing tests) must stay green throughout.

## Scope

The user explicitly wants well-separated modules, not a minimal patch. To keep
risk low, implement in **two phases**, each independently green
(`./infocutter check`) and shippable:

**Phase 1 — behavior-preserving decomposition (standalone functions).** Extract
the parts that are already standalone functions, with **no user-visible change**:
- `picker-session.ts` becomes the sole writer of `selectionSession`; existing
  write sites (panel rename/remove, controller add/clear, persist) route through
  its API. Reads stay as-is.
- `picker-iframe.ts` (`buildIframePanel` + `startPickerInIframe`),
  `picker-refine-panel.ts` (`buildPreviewPanel`), `picker-session-panel.ts`
  (`buildSessionPanel`) extracted verbatim; still launched the same way.
- Register the new content scripts in the three lists (manifest, build.mjs,
  service-worker.ts), between `picker-analysis.js` and `picker-ui.js`.
- The controller (`startPicker`) is unchanged and behaves identically; verifiable
  via devtools. `picker-ui.ts` shrinks to the controller + `hideTargetElement`.

**Phase 2 — quick-toggle interaction + controller untangle.** On top of the clean
modules:
- Extract `picker-hover.ts` (hover candidate state + Tab cycling) out of the
  `startPicker` closure — this is feasible only here because it is bound up with
  the controller rewrite.
- Replace the controller's click flow with `sessionToggleElement` (element-specific
  selector, no restart, no panel); re-click removes.
- Switch the refine panel to `openRefinePanel(cardId)` editing one existing card;
  add the 다듬기 button to the session panel.
- Slim `picker-ui.ts` to event wiring + lifecycle (~200 lines).

Each phase is its own implementation plan. No unrelated refactoring beyond what
untangling the controller requires.
