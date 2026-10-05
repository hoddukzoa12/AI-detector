# Picker Quick Multi-Select — Phase 1 (Decomposition) Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Untangle the picker by extracting standalone pieces of `picker-ui.ts` into focused content modules, with zero user-visible change.

**Architecture:** Move the already-standalone functions (`buildIframePanel`/`startPickerInIframe`, `buildPreviewPanel`, `buildSessionPanel`) into their own content global-script files, and introduce `picker-session.ts` as the sole writer of the `selectionSession` global. The `startPicker` controller is left untouched (it calls these as globals) and shrinks to itself + `hideTargetElement`. Phase 2 (quick-toggle + `picker-hover` + controller rewrite) is a separate plan.

**Tech Stack:** TypeScript content global scripts (no import/export; shared global scope; load order set by three content-script lists), Manifest V3.

---

## Working context

- Worktree: `/Users/jeonghan/Documents/WORK/WORKSPACE/apps/chrome-extension-mono-wt-infocutter-pickerquick`
- Run from: `cd vibecode-chrome-extension-infocutter`
- Verification gate per task: `./infocutter check` (lint + typecheck + test).
- Strict rule: **no `//` line comments** (block `/* */` allowed). New content global-script files start with `/* eslint-disable @typescript-eslint/no-unused-vars */` (functions defined in one file are used cross-file, so they look "unused" locally — existing pattern).
- Content scripts share one global scope. Moving a global `function` between files does NOT change its call sites; it only requires the new file to be registered in the three content-script lists so it loads at runtime. TypeScript will flag a duplicate (TS2393) if a function is left in both files, so each move = delete-from-old + add-to-new.
- Three content-script lists (keep in sync, insert each new file between `picker-analysis.js` and `picker-ui.js`):
  - `public/manifest.json` → `content_scripts[0].js`
  - `scripts/build.mjs` → `contentScriptFiles`
  - `src/background/service-worker.ts` → `contentScriptFiles`

## File structure (end state of Phase 1)

- `src/content/picker-session.ts` (new) — sole writer of `selectionSession`: `sessionAdd`, `sessionRemove`, `sessionRename`, `sessionClear`, `sessionPersist`.
- `src/content/picker-iframe.ts` (new) — `buildIframePanel`, `startPickerInIframe`.
- `src/content/picker-refine-panel.ts` (new) — `buildPreviewPanel`.
- `src/content/picker-session-panel.ts` (new) — `buildSessionPanel`.
- `src/content/picker-ui.ts` (slimmed) — `startPicker` controller + `hideTargetElement` only.
- `selectionSession` / `selectionSessionPalette` stay declared in `src/content/state.ts` (unchanged).

---

## Task 1: `picker-session.ts` — encapsulate session writes

**Files:**
- Create: `src/content/picker-session.ts`
- Modify: `src/content/picker-ui.ts` (remove `persistSelectionSession`; replace 6 write sites)
- Modify: `public/manifest.json`, `scripts/build.mjs`, `src/background/service-worker.ts` (register)

- [ ] **Step 1: Create the session module**

Create `src/content/picker-session.ts`:

```ts
/* eslint-disable @typescript-eslint/no-unused-vars */

function sessionAdd(entry: PickerSessionEntry): void {
  selectionSession = [...selectionSession, entry];
}

function sessionRemove(cardId: string): void {
  selectionSession = selectionSession.filter((entry) => entry.cardId !== cardId);
}

function sessionRename(cardId: string, name: string): void {
  selectionSession = selectionSession.map((entry) => (
    entry.cardId === cardId
      ? { ...entry, cardName: name.trim() || entry.cardName }
      : entry
  ));
}

function sessionClear(): void {
  selectionSession = [];
}

async function sessionPersist(): Promise<void> {
  for (const card of selectionSession) {
    await addSiteRule(ownerPageUrl(), card.selector, card.frameScope, {
      cardId: card.cardId,
      cardName: card.cardName
    });
  }

  selectionSession = [];
  applySelectionSessionHighlights();
}
```

- [ ] **Step 2: Remove `persistSelectionSession` from picker-ui.ts**

Delete the entire `persistSelectionSession` function from `src/content/picker-ui.ts` (it now lives in `picker-session.ts` as `sessionPersist`):

```ts
async function persistSelectionSession(): Promise<void> {
  for (const card of selectionSession) {
    await addSiteRule(ownerPageUrl(), card.selector, card.frameScope, {
      cardId: card.cardId,
      cardName: card.cardName
    });
  }

  selectionSession = [];
  applySelectionSessionHighlights();
}
```

- [ ] **Step 3: Replace the 6 write sites in picker-ui.ts**

In `buildSessionPanel`, the rename handler — replace:
```ts
    nameInput.addEventListener("input", () => {
      selectionSession = selectionSession.map((entry) => (
        entry.cardId === card.cardId
          ? {
              ...entry,
              cardName: nameInput.value.trim() || entry.cardName
            }
          : entry
      ));
    });
```
with:
```ts
    nameInput.addEventListener("input", () => {
      sessionRename(card.cardId, nameInput.value);
    });
```

In `buildSessionPanel`, the remove handler — replace:
```ts
    removeButton.addEventListener("click", () => {
      selectionSession = selectionSession.filter((entry) => entry.cardId !== card.cardId);
      buildSessionPanel(onDone, onCancel);
    });
```
with:
```ts
    removeButton.addEventListener("click", () => {
      sessionRemove(card.cardId);
      buildSessionPanel(onDone, onCancel);
    });
```

In `startPicker`, the add-card callback — replace:
```ts
          selectionSession.push({
            cardId: generateId(),
            cardName,
            createdAt: new Date().toISOString(),
            frameScope: currentFrameScope(),
            selector: selectedSelector
          });
```
with:
```ts
          sessionAdd({
            cardId: generateId(),
            cardName,
            createdAt: new Date().toISOString(),
            frameScope: currentFrameScope(),
            selector: selectedSelector
          });
```

After Step 2, two `selectionSession = [];` statements remain in `picker-ui.ts` — both are session-cancel handlers inside `startPicker` (one in the add-card callback's cancel branch, one in the end-of-session cancel branch). Replace **each** `selectionSession = [];` with `sessionClear();`.

There are two calls to `persistSelectionSession();` in `picker-ui.ts`. Replace **each** `await persistSelectionSession();` with `await sessionPersist();`.

- [ ] **Step 4: Register picker-session.js in the three lists**

In each of `public/manifest.json` (`content_scripts[0].js`), `scripts/build.mjs` (`contentScriptFiles`), and `src/background/service-worker.ts` (`contentScriptFiles`), insert `"src/content/picker-session.js"` on the line immediately BEFORE `"src/content/picker-ui.js"`. (Mind the JSON commas in the manifest.)

- [ ] **Step 5: Verify**

Run: `./infocutter check`
Expected: PASS (lint + typecheck + tests). Typecheck confirms no duplicate/undefined globals.
Then confirm load order:
```bash
node -e "const m=require('./dist/manifest.json'); const js=m.content_scripts[0].js; if(!(js.indexOf('src/content/picker-session.js')>=0 && js.indexOf('src/content/picker-session.js')<js.indexOf('src/content/picker-ui.js'))) throw new Error('order: '+js.join(',')); console.log('order ok')"
```
Expected: `order ok`.

- [ ] **Step 6: Commit**

```bash
git add src/content/picker-session.ts src/content/picker-ui.ts public/manifest.json scripts/build.mjs src/background/service-worker.ts
git commit -m "refactor(infocutter): extract picker-session as sole session writer"
```

---

## Task 2: `picker-iframe.ts` — extract the iframe flow

**Files:**
- Create: `src/content/picker-iframe.ts`
- Modify: `src/content/picker-ui.ts` (remove two functions)
- Modify: the three content-script lists (register)

- [ ] **Step 1: Create the file with the header**

Create `src/content/picker-iframe.ts` containing exactly this first line, then the two moved functions below it:
```ts
/* eslint-disable @typescript-eslint/no-unused-vars */
```

- [ ] **Step 2: Move `buildIframePanel` and `startPickerInIframe` verbatim**

Cut the **entire** `buildIframePanel` function (from `function buildIframePanel(` through its matching closing `}`) and the **entire** `async function startPickerInIframe(iframeElement: HTMLIFrameElement): Promise<boolean> {` function from `src/content/picker-ui.ts`, and paste both verbatim into `src/content/picker-iframe.ts` after the header line. Do not modify their bodies. They reference only globals (`PICKER_PREVIEW_PANEL_ID`, `iframeAccessMode`, `generateId`, `PICKER_FRAME_MESSAGE_TYPE`, `PICKER_FRAME_ACK_TYPE`, etc.) which remain resolvable in the shared global scope.

- [ ] **Step 3: Register picker-iframe.js**

In all three content-script lists, insert `"src/content/picker-iframe.js"` immediately BEFORE `"src/content/picker-ui.js"` (so the order becomes `... picker-session, picker-iframe, picker-ui`).

- [ ] **Step 4: Verify**

Run: `./infocutter check`
Expected: PASS. (If TS2393 "duplicate function" appears, the function was not fully removed from picker-ui.ts — fix and re-run.)

- [ ] **Step 5: Commit**

```bash
git add src/content/picker-iframe.ts src/content/picker-ui.ts public/manifest.json scripts/build.mjs src/background/service-worker.ts
git commit -m "refactor(infocutter): extract picker-iframe panel and frame entry"
```

---

## Task 3: `picker-refine-panel.ts` — extract the precise panel

**Files:**
- Create: `src/content/picker-refine-panel.ts`
- Modify: `src/content/picker-ui.ts` (remove `buildPreviewPanel` + its preceding block comment)
- Modify: the three content-script lists (register)

- [ ] **Step 1: Create the file with the header**

Create `src/content/picker-refine-panel.ts` with this first line:
```ts
/* eslint-disable @typescript-eslint/no-unused-vars */
```

- [ ] **Step 2: Move `buildPreviewPanel` verbatim**

Cut the **entire** `buildPreviewPanel` function (from `function buildPreviewPanel(` through its matching closing `}` — it is large, ~460 lines, ending just before `function buildIframePanel`) from `src/content/picker-ui.ts` and paste it verbatim into `src/content/picker-refine-panel.ts` after the header line. Also delete the now-stale block comment directly above it in picker-ui.ts:
```ts
/*
 * The preview panel intentionally remains imperative DOM code.
 * Keeping it in one file makes the picker interaction easier to debug during real browsing.
 */
```
Do not modify the function body.

- [ ] **Step 3: Register picker-refine-panel.js**

In all three content-script lists, insert `"src/content/picker-refine-panel.js"` immediately BEFORE `"src/content/picker-ui.js"`.

- [ ] **Step 4: Verify**

Run: `./infocutter check`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/content/picker-refine-panel.ts src/content/picker-ui.ts public/manifest.json scripts/build.mjs src/background/service-worker.ts
git commit -m "refactor(infocutter): extract picker-refine-panel (preview panel)"
```

---

## Task 4: `picker-session-panel.ts` — extract the session panel

**Files:**
- Create: `src/content/picker-session-panel.ts`
- Modify: `src/content/picker-ui.ts` (remove `buildSessionPanel`)
- Modify: the three content-script lists (register)

- [ ] **Step 1: Create the file with the header**

Create `src/content/picker-session-panel.ts` with this first line:
```ts
/* eslint-disable @typescript-eslint/no-unused-vars */
```

- [ ] **Step 2: Move `buildSessionPanel` verbatim**

Cut the **entire** `buildSessionPanel` function (from `function buildSessionPanel(onDone: () => void, onCancel: () => void): HTMLDivElement | null {` through its matching closing `}`) from `src/content/picker-ui.ts` and paste it verbatim into `src/content/picker-session-panel.ts` after the header line. Its body already calls `sessionRename`/`sessionRemove` (from Task 1) and `applySelectionSessionHighlights` (picker-overlay) — all globals, no change needed.

- [ ] **Step 3: Register picker-session-panel.js**

In all three content-script lists, insert `"src/content/picker-session-panel.js"` immediately BEFORE `"src/content/picker-ui.js"`.

- [ ] **Step 4: Verify**

Run: `./infocutter check`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/content/picker-session-panel.ts src/content/picker-ui.ts public/manifest.json scripts/build.mjs src/background/service-worker.ts
git commit -m "refactor(infocutter): extract picker-session-panel"
```

---

## Task 5: Tidy the controller header + final verification

**Files:**
- Modify: `src/content/picker-ui.ts` (trim the now-stale top block comment)

- [ ] **Step 1: Update the stale grouping comment**

At the top of `src/content/picker-ui.ts`, below the `/* eslint-disable @typescript-eslint/no-unused-vars */` line, there is a block comment beginning `/*` that says the panel/iframe/session UI "stay together on purpose". Replace that block comment with:
```ts
/*
 * Picker controller: wires DOM events to the picker modules
 * (picker-session, picker-overlay, picker-analysis, picker-refine-panel,
 * picker-session-panel, picker-iframe). Holds the per-session controller state.
 */
```

- [ ] **Step 2: Confirm picker-ui.ts is now controller + hideTargetElement only**

Run:
```bash
grep -nE '^(function |async function )' src/content/picker-ui.ts
```
Expected: only `startPicker` and `hideTargetElement` remain.

- [ ] **Step 3: Full gate + built manifest order**

Run: `./infocutter check`
Then:
```bash
node -e "const js=require('./dist/manifest.json').content_scripts[0].js; const want=['picker-overlay','picker-analysis','picker-session','picker-iframe','picker-refine-panel','picker-session-panel','picker-ui'].map(n=>'src/content/'+n+'.js'); const idx=want.map(f=>js.indexOf(f)); if(idx.some(i=>i<0)||idx.slice(1).some((v,i)=>v<idx[i])) throw new Error('order: '+js.join(',')); console.log('order ok')"
```
Expected: `./infocutter check` PASS and `order ok`.

- [ ] **Step 4: Manual behavior-identical check (devtools MCP)**

Load `dist/` and confirm the picker behaves exactly as before this phase: start picker, click an element → preview panel opens, "카드에 담기" adds a card and the session panel lists it with numbered highlight, add a second card, "완료 적용" hides+persists both, "세션 취소" discards, iframe click still offers the frame panel. No behavior change is expected.

- [ ] **Step 5: Commit**

```bash
git add src/content/picker-ui.ts
git commit -m "refactor(infocutter): retitle picker-ui as the controller"
```

---

## Self-review notes (reconciled with spec)

- Phase 1 covers only the standalone extractions + `picker-session` writer (spec §Scope Phase 1). `picker-hover` and the quick-toggle/refine-by-card changes are Phase 2 (separate plan).
- Sole-writer rule: all `selectionSession` assignments now live in `picker-session.ts` (Task 1); other files only read it (spec §Architecture "Key rule").
- Pure verbatim moves keep behavior identical; `./infocutter check` (typecheck catches duplicate/missing globals) plus the devtools pass are the gates (spec §Testing).
- Three content-script lists kept in sync each task, ordered picker-session → picker-iframe → picker-refine-panel → picker-session-panel → picker-ui (spec §Scope).
