# Infocutter Keyboard Shortcuts — Design Spec

Date: 2026-05-30
Status: Approved (brainstorming) — pending implementation plan

## Purpose

Give infocutter four keyboard shortcuts (Chrome `commands` API) so the core
actions work without opening the popup or context menu:

1. Launch the element picker on the active tab.
2. Toggle the global hide switch (`settings.globalEnabled`).
3. Toggle the profile matching the active tab's URL.
4. Toggle "peek" — temporarily reveal hidden elements on the active tab.

Feedback for toggles is given two ways: a toolbar action badge (global state)
and a short on-page toast.

## Non-goals (YAGNI)

- No custom in-extension UI for rebinding keys; users rebind at
  `chrome://extensions/shortcuts` (Chrome provides this for free).
- Peek is not persisted; it resets on page reload.
- No "hold to peek" — Chrome commands are discrete key events, so peek is a
  toggle.
- No new permissions beyond the existing manifest surface.

## Approach (selected: A — background-centric)

`chrome.commands.onCommand` lives in the background service-worker (the
lifecycle/orchestration layer per AGENTS.md). It routes each command to the
active tab, reusing existing message handlers wherever possible.

### Command → action mapping

| command | background action | reuses |
|---|---|---|
| `launch-picker` | `ensureTabReady` → `stopPicker` (all frames) → `startPicker` (top frame) | existing `startPickerFlow` sequence |
| `toggle-global` | send `toggleGlobalEnabled` to the **top frame** | existing content handler |
| `toggle-site-profile` | send `toggleSiteEnabled` to the **top frame** | existing content handler |
| `toggle-peek` | send `togglePeek` to **all frames** | new |

Frame targeting matters: the two storage-writing toggles go to the **top frame
only**, so there is a single storage write and a single toast; `storage.onChanged`
then re-renders every frame and updates the badge. Peek writes no storage and is
purely visual per document, so it broadcasts to **all frames** (each manages its
own style element and flag).

The two toggles reuse the content handlers the popup/context-menu already use,
so the only genuinely new runtime surface is the `onCommand` router plus the
peek and toast modules.

### Default key bindings

Rebindable at `chrome://extensions/shortcuts`. Exactly four commands carry a
suggested key (Chrome's recommended limit), using low-conflict `Alt+Shift`:

| command | suggested key |
|---|---|
| `launch-picker` | `Alt+Shift+P` |
| `toggle-global` | `Alt+Shift+O` |
| `toggle-site-profile` | `Alt+Shift+S` |
| `toggle-peek` | `Alt+Shift+E` |

## Components & file changes

New / changed files:

- Content-script registration lives in **three** lists that must stay in sync,
  all gaining `src/content/peek.js` and `src/content/toast.js` in matching order
  (placed after `constants.js`, before `index.js`):
  - `public/manifest.json` → `content_scripts[0].js`
  - `scripts/build.mjs` → `contentScriptFiles`
  - `src/background/service-worker.ts` → `contentScriptFiles` (used by
    `ensureContentScript` re-injection)
- `public/manifest.json` — also add the `commands` block (4 commands + suggested
  keys).
- `src/shared/commands.ts` (new) — pure command-id constants + a
  `toggleCommandMessage(id)` mapping, imported by the background and unit-tested.
- `src/shared/messages.ts` — add `togglePeek: "infocutter/toggle-peek"`.
- `src/background/service-worker.ts` — add the `chrome.commands.onCommand`
  listener (no badge changes; the existing badge already updates on storage
  change).
- `src/content/peek.ts` (new global content script) — owns `peekActive` flag +
  the reveal/hide CSS decision.
- `src/content/toast.ts` (new global content script) — `showToast(text)`.
- `src/content/index.ts` — add a `togglePeek` message handler; call
  `showToast(...)` inside the existing `toggleGlobalEnabled` / `toggleSiteEnabled`
  handlers with the resulting state.
- selector + text-block render functions — consult `peekActive` when building
  their style text.

## Peek mechanism

State: a per-tab runtime flag `peekActive` in `peek.ts` (not persisted). Reset
to hidden on reload — intended.

Hiding today is applied by two `<style>` elements: selector rules
(`STYLE_ELEMENT_ID`) and text-block rules (`TEXT_BLOCK_STYLE_ELEMENT_ID`, of
the form `[attr] { display: none !important; }`). Peek swaps `display:none` for
a reveal rule on both:

```
peekActive=false (default): <selector> { display: none !important; }
peekActive=true  (peek):    <selector> { opacity: .35 !important;
                                          outline: 1px dashed rgba(217,119,6,.9) !important; }
```

Revealed elements appear translucent with a dashed outline, signalling "normally
hidden".

The render functions (`renderRules` / `renderTextBlockRules`) read `peekActive`
when generating style text, so a re-render triggered while peek is on (e.g. a
`storage.onChanged`) keeps the reveal styling.

Toggle flow: `togglePeek` message → `peekActive = !peekActive` →
`renderAllRules()` → styles flip hide↔reveal. Broadcast to all frames so iframes
peek in step with the top document; each frame toggles its own flag. The toast
(`"peek 켬" / "peek 끔"`) is shown **only by the top frame** (frame-context
already distinguishes top vs iframe), so a page with iframes still gets a single
toast.

Edge case: if `globalEnabled` is false nothing is hidden, so peek has nothing to
reveal; the toast still confirms the toggle.

## Feedback

### Badge (global state)

No new badge code. The background already drives a per-tab action badge via
`updateBadgeForTab` (enabled-rule count with amber background when active, empty
when global/profile is off or no rules), and a `chrome.storage.onChanged`
listener already recomputes it for every tab on any local storage change. So a
keyboard `toggle-global` / `toggle-site-profile` already flips the badge
(count ↔ empty) for free. Adding a separate "OFF" text would clobber the count,
so we rely on the existing badge and let the toast carry the explicit on/off
wording.

### Toast (per action)

`toast.ts` exposes `showToast(text)`: a single bottom-right fixed `<div>`,
high z-index, `pointer-events: none`, auto fade-out after ~1.5s, replacing any
existing instance. Called from the content handlers:

- `toggleGlobalEnabled` → "전역 숨김 켬" / "전역 숨김 끔"
- `toggleSiteEnabled` → "이 사이트 켬" / "이 사이트 끔"; if no profile matches
  the URL → "이 사이트에 규칙 없음"
- `togglePeek` → "peek 켬" / "peek 끔"

## Error handling & edge cases

- Commands fired on a restricted tab (`chrome://`, extension pages, no content
  script) — `ensureTabReady` already guards picker launch; toggle/peek messages
  to such tabs fail silently (no toast). Acceptable.
- No active tab / no tab id — onCommand handler no-ops.
- `toggle-site-profile` with no matching profile — content handler shows the
  "규칙 없음" toast rather than creating a profile.
- Peek left on, then user reloads — page loads hidden (flag reset); consistent.

## Testing

Only ES-module code under `src/shared/` and `packages/` is reachable by
`node:test` (content scripts are global scripts with no exports, so they cannot
be imported). The testable unit:

1. `toggleCommandMessage(id)` in `src/shared/commands.ts`: each toggle command id
   maps to the expected message type; non-toggle / unknown ids return `null`.

The peek CSS swap lives in content (`peek.ts`) and is not node-testable; it plus
the rest of the Chrome-API glue (onCommand registration, badge, cross-frame
messaging, toast) is verified manually via the chrome-devtools MCP flow: launch
picker by key, toggle global/site and observe the badge + toast, peek shows
translucent dashed elements and re-hides on the second press.

## Layering check (AGENTS.md)

- `background` — owns the `onCommand` router and badge (orchestration/lifecycle).
- `content` — owns peek state, toast rendering, and toggle execution (page
  interaction).
- `shared` — only the new message-type constant.
- No business logic added to popup or service worker beyond routing.
