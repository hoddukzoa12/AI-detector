# Infocutter Keyboard Shortcuts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add four Chrome keyboard commands (launch picker, toggle global, toggle current-site profile, toggle peek) with on-page toast feedback.

**Architecture:** A `chrome.commands.onCommand` listener in the background service-worker routes each command to the active tab. The two storage-writing toggles reuse the existing content message handlers (background computes the flipped `enabled` and sends it to the top frame with a `toast: true` flag). Peek is a new per-tab content toggle that swaps the single `[attr]{display:none}` hide rule for a translucent reveal rule; it broadcasts to all frames and toasts only in the top frame.

**Tech Stack:** Manifest V3, TypeScript (global content scripts + ES-module background/shared), `chrome.commands`, `chrome.action` badge, node:test.

---

## Working context

- Worktree: `/Users/jeonghan/Documents/WORK/WORKSPACE/apps/chrome-extension-mono-wt-infocutter-shortcuts`
- Run all commands from the extension dir: `cd vibecode-chrome-extension-infocutter`
- Verification gate per task: `./infocutter check` (= `pipe:lint && pipe:typecheck && pipe:test`; `pipe:test` builds first).
- Strict repo rule: **no `//` line comments** in committed files (block `/* */` allowed). Content scripts that define globals used cross-file need a `/* eslint-disable @typescript-eslint/no-unused-vars */` header (existing pattern).
- Content scripts are global scripts (no import/export); they share one global scope. Background and `src/shared/**` are ES modules.

## File structure

- `src/shared/messages.ts` (modify) — add `togglePeek` message type.
- `src/content/constants.ts` (modify) — add `togglePeek` to the content-side `messageTypes` copy.
- `src/shared/commands.ts` (new, ES module) — command-id constants + `toggleCommandMessage(id)`; the only node-testable unit.
- `tests/commands.test.ts` (new) — unit test for `toggleCommandMessage`.
- `src/content/peek.ts` (new global script) — `infocutterPeekActive` flag, `toggleInfocutterPeek()`, `hiddenAttrCss(attr)`.
- `src/content/selector-engine.ts` (modify line 339) — use `hiddenAttrCss(SELECTOR_HIDDEN_ATTR)`.
- `src/content/text-block-runtime.ts` (modify line 376) — use `hiddenAttrCss(TEXT_BLOCK_HIDDEN_ATTR)`.
- `src/content/toast.ts` (new global script) — `showToast(text)`.
- `src/content/index.ts` (modify) — add `togglePeek` handler; add `toast`-gated `showToast` calls inside the `toggleGlobalEnabled` / `toggleSiteEnabled` handlers.
- `public/manifest.json` (modify) — add `commands` block; add `peek.js`/`toast.js` to `content_scripts[0].js`.
- `scripts/build.mjs` (modify) — add `peek.js`/`toast.js` to `contentScriptFiles`.
- `src/background/service-worker.ts` (modify) — add `peek.js`/`toast.js` to its `contentScriptFiles`; add the `chrome.commands.onCommand` listener.

---

## Task 1: Add the `togglePeek` message type

**Files:**
- Modify: `src/shared/messages.ts`
- Modify: `src/content/constants.ts`

- [ ] **Step 1: Add to the shared message map**

In `src/shared/messages.ts`, add the new entry to the `messageTypes` object (after `toggleGlobalEnabled`):

```ts
  toggleGlobalEnabled: "infocutter/toggle-global-enabled",
  togglePeek: "infocutter/toggle-peek",
  toggleTextBlockProfileEnabled: "infocutter/toggle-text-block-profile-enabled",
```

- [ ] **Step 2: Add to the content-side copy**

In `src/content/constants.ts`, add the same entry to the content `messageTypes` object (after `toggleGlobalEnabled`):

```ts
  toggleGlobalEnabled: "infocutter/toggle-global-enabled",
  togglePeek: "infocutter/toggle-peek",
  toggleTextBlockProfileEnabled: "infocutter/toggle-text-block-profile-enabled",
```

- [ ] **Step 3: Verify**

Run: `./infocutter check`
Expected: PASS (lint + typecheck + 11 existing tests).

- [ ] **Step 4: Commit**

```bash
git add src/shared/messages.ts src/content/constants.ts
git commit -m "feat(infocutter): add togglePeek message type"
```

---

## Task 2: `src/shared/commands.ts` + unit test (TDD)

**Files:**
- Create: `src/shared/commands.ts`
- Test: `tests/commands.test.ts`

- [ ] **Step 1: Write the failing test**

Create `tests/commands.test.ts`:

```ts
import test from "node:test";
import assert from "node:assert/strict";

import { commandIds, toggleCommandMessage } from "../src/shared/commands.js";
import { messageTypes } from "../src/shared/messages.js";

void test("toggleCommandMessage maps toggle commands to their message types", () => {
  assert.equal(toggleCommandMessage(commandIds.toggleGlobal), messageTypes.toggleGlobalEnabled);
  assert.equal(toggleCommandMessage(commandIds.toggleSiteProfile), messageTypes.toggleSiteEnabled);
  assert.equal(toggleCommandMessage(commandIds.togglePeek), messageTypes.togglePeek);
});

void test("toggleCommandMessage returns null for non-toggle and unknown ids", () => {
  assert.equal(toggleCommandMessage(commandIds.launchPicker), null);
  assert.equal(toggleCommandMessage("nope"), null);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npm run pipe:test`
Expected: FAIL — build error `Cannot find module '../src/shared/commands.js'`.

- [ ] **Step 3: Write the implementation**

Create `src/shared/commands.ts`:

```ts
import { messageTypes } from "./messages.js";
import type { MessageType } from "./messages.js";

export const commandIds = {
  launchPicker: "launch-picker",
  toggleGlobal: "toggle-global",
  toggleSiteProfile: "toggle-site-profile",
  togglePeek: "toggle-peek"
} as const;

export type CommandId = (typeof commandIds)[keyof typeof commandIds];

export function toggleCommandMessage(commandId: string): MessageType | null {
  switch (commandId) {
    case commandIds.toggleGlobal:
      return messageTypes.toggleGlobalEnabled;
    case commandIds.toggleSiteProfile:
      return messageTypes.toggleSiteEnabled;
    case commandIds.togglePeek:
      return messageTypes.togglePeek;
    default:
      return null;
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `./infocutter check`
Expected: PASS — 13 tests (11 existing + 2 new).

- [ ] **Step 5: Commit**

```bash
git add src/shared/commands.ts tests/commands.test.ts
git commit -m "feat(infocutter): add command-id map with unit test"
```

---

## Task 3: `src/content/peek.ts` + wire render functions

**Files:**
- Create: `src/content/peek.ts`
- Modify: `src/content/selector-engine.ts:339`
- Modify: `src/content/text-block-runtime.ts:376`

- [ ] **Step 1: Create the peek module**

Create `src/content/peek.ts`:

```ts
/* eslint-disable @typescript-eslint/no-unused-vars */

let infocutterPeekActive = false;

function toggleInfocutterPeek(): boolean {
  infocutterPeekActive = !infocutterPeekActive;
  return infocutterPeekActive;
}

function hiddenAttrCss(attr: string): string {
  if (infocutterPeekActive) {
    return `[${attr}] { opacity: 0.35 !important; outline: 1px dashed rgba(217, 119, 6, 0.9) !important; }`;
  }

  return `[${attr}] { display: none !important; }`;
}
```

- [ ] **Step 2: Use it for selector rules**

In `src/content/selector-engine.ts`, replace the line (currently 339):

```ts
  style.textContent = `[${SELECTOR_HIDDEN_ATTR}] { display: none !important; }`;
```

with:

```ts
  style.textContent = hiddenAttrCss(SELECTOR_HIDDEN_ATTR);
```

- [ ] **Step 3: Use it for text-block rules**

In `src/content/text-block-runtime.ts`, replace the line (currently 376):

```ts
  style.textContent = `[${TEXT_BLOCK_HIDDEN_ATTR}] { display: none !important; }`;
```

with:

```ts
  style.textContent = hiddenAttrCss(TEXT_BLOCK_HIDDEN_ATTR);
```

- [ ] **Step 4: Verify**

Run: `./infocutter check`
Expected: PASS. (`hiddenAttrCss` resolves as a global since `peek.ts` is in the `src/**` compilation; no manifest registration is needed for typecheck.)

- [ ] **Step 5: Commit**

```bash
git add src/content/peek.ts src/content/selector-engine.ts src/content/text-block-runtime.ts
git commit -m "feat(infocutter): add peek state and reveal CSS swap"
```

---

## Task 4: `src/content/toast.ts`

**Files:**
- Create: `src/content/toast.ts`

- [ ] **Step 1: Create the toast module**

Create `src/content/toast.ts`:

```ts
/* eslint-disable @typescript-eslint/no-unused-vars */

const INFOCUTTER_TOAST_ID = "infocutter-toast";

function showToast(text: string): void {
  document.getElementById(INFOCUTTER_TOAST_ID)?.remove();

  const toast = document.createElement("div");
  toast.id = INFOCUTTER_TOAST_ID;
  toast.textContent = text;
  toast.style.position = "fixed";
  toast.style.right = "16px";
  toast.style.bottom = "16px";
  toast.style.padding = "10px 14px";
  toast.style.background = "#231f17";
  toast.style.color = "#f7f4eb";
  toast.style.font = '13px "SF Mono", "IBM Plex Mono", ui-monospace, monospace';
  toast.style.borderRadius = "8px";
  toast.style.boxShadow = "0 12px 30px rgba(0,0,0,0.24)";
  toast.style.zIndex = "2147483647";
  toast.style.pointerEvents = "none";
  toast.style.opacity = "1";
  toast.style.transition = "opacity 240ms ease-out";
  document.documentElement.append(toast);

  window.setTimeout(() => {
    toast.style.opacity = "0";
  }, 1500);
  window.setTimeout(() => {
    toast.remove();
  }, 1800);
}
```

- [ ] **Step 2: Verify**

Run: `./infocutter check`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add src/content/toast.ts
git commit -m "feat(infocutter): add transient on-page toast"
```

---

## Task 5: Register `peek.js` + `toast.js` in all three content-script lists

**Files:**
- Modify: `public/manifest.json`
- Modify: `scripts/build.mjs`
- Modify: `src/background/service-worker.ts:12-23`

All three lists must list the same files in the same order. Insert `peek.js` and `toast.js` right after `constants.js`.

- [ ] **Step 1: manifest**

In `public/manifest.json`, in `content_scripts[0].js`, change:

```json
        "src/content/constants.js",
        "src/content/state.js",
```

to:

```json
        "src/content/constants.js",
        "src/content/peek.js",
        "src/content/toast.js",
        "src/content/state.js",
```

- [ ] **Step 2: build.mjs**

In `scripts/build.mjs`, in the `contentScriptFiles` array, change:

```js
  "src/content/constants.js",
  "src/content/state.js",
```

to:

```js
  "src/content/constants.js",
  "src/content/peek.js",
  "src/content/toast.js",
  "src/content/state.js",
```

- [ ] **Step 3: service-worker.ts**

In `src/background/service-worker.ts`, in the `contentScriptFiles` array (lines 12-23), change:

```ts
  "src/content/constants.js",
  "src/content/state.js",
```

to:

```ts
  "src/content/constants.js",
  "src/content/peek.js",
  "src/content/toast.js",
  "src/content/state.js",
```

- [ ] **Step 4: Verify build emits the files in order**

Run: `./infocutter check`
Then run: `node -e "const m=require('./dist/manifest.json'); const js=m.content_scripts[0].js; const i=js.indexOf('src/content/peek.js'); const t=js.indexOf('src/content/toast.js'); const c=js.indexOf('src/content/constants.js'); const idx=js.indexOf('src/content/index.js'); if(!(c<i && i<t && t<idx)) { throw new Error('order wrong: '+js.join(',')); } console.log('order ok')"`
Expected: prints `order ok`, and `dist/src/content/peek.js` + `dist/src/content/toast.js` exist.

- [ ] **Step 5: Commit**

```bash
git add public/manifest.json scripts/build.mjs src/background/service-worker.ts
git commit -m "feat(infocutter): register peek and toast content scripts"
```

---

## Task 6: `togglePeek` handler + toast on toggles in content/index.ts

**Files:**
- Modify: `src/content/index.ts`

- [ ] **Step 1: Add the togglePeek handler**

In `src/content/index.ts`, after the `stopPicker` handler block (currently ends ~line 98), insert:

```ts
      if (type === messageTypes.togglePeek) {
        const active = toggleInfocutterPeek();
        await renderAllRules();
        if (window.top === window) {
          showToast(active ? "peek 켬" : "peek 끔");
        }
        sendResponse({ ok: true, data: { active } });
        return;
      }
```

- [ ] **Step 2: Add a toast to the toggleSiteEnabled handler**

In `src/content/index.ts`, replace the whole `toggleSiteEnabled` block (currently lines 168-183):

```ts
      if (type === messageTypes.toggleSiteEnabled) {
        const enabled = "enabled" in message && typeof message.enabled === "boolean" ? message.enabled : null;
        const currentState = await readActiveSiteState(ownerPageUrl());
        if (enabled === null || !currentState.activeProfileId) {
          sendResponse({ ok: false });
          return;
        }

        await setSiteEnabled(currentState.activeProfileId, enabled);
        await renderAllRules();
        sendResponse({
          ok: true,
          data: await readActiveSiteState(ownerPageUrl())
        });
        return;
      }
```

with:

```ts
      if (type === messageTypes.toggleSiteEnabled) {
        const enabled = "enabled" in message && typeof message.enabled === "boolean" ? message.enabled : null;
        const wantsToast = "toast" in message && message.toast === true;
        const currentState = await readActiveSiteState(ownerPageUrl());
        if (enabled === null || !currentState.activeProfileId) {
          if (wantsToast && window.top === window) {
            showToast("이 사이트에 규칙 없음");
          }
          sendResponse({ ok: false });
          return;
        }

        await setSiteEnabled(currentState.activeProfileId, enabled);
        await renderAllRules();
        if (wantsToast) {
          showToast(enabled ? "이 사이트 켬" : "이 사이트 끔");
        }
        sendResponse({
          ok: true,
          data: await readActiveSiteState(ownerPageUrl())
        });
        return;
      }
```

- [ ] **Step 3: Add a toast to the toggleGlobalEnabled handler**

In `src/content/index.ts`, replace the whole `toggleGlobalEnabled` block (currently lines 185-199):

```ts
      if (type === messageTypes.toggleGlobalEnabled) {
        const enabled = "enabled" in message && typeof message.enabled === "boolean" ? message.enabled : null;
        if (enabled === null) {
          sendResponse({ ok: false });
          return;
        }

        await setGlobalEnabled(enabled);
        await renderAllRules();
        sendResponse({
          ok: true,
          data: await readActiveSiteState(ownerPageUrl())
        });
        return;
      }
```

with:

```ts
      if (type === messageTypes.toggleGlobalEnabled) {
        const enabled = "enabled" in message && typeof message.enabled === "boolean" ? message.enabled : null;
        const wantsToast = "toast" in message && message.toast === true;
        if (enabled === null) {
          sendResponse({ ok: false });
          return;
        }

        await setGlobalEnabled(enabled);
        await renderAllRules();
        if (wantsToast) {
          showToast(enabled ? "전역 숨김 켬" : "전역 숨김 끔");
        }
        sendResponse({
          ok: true,
          data: await readActiveSiteState(ownerPageUrl())
        });
        return;
      }
```

- [ ] **Step 4: Verify**

Run: `./infocutter check`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/content/index.ts
git commit -m "feat(infocutter): handle togglePeek and toast on keyboard toggles"
```

---

## Task 7: Add the `commands` block to the manifest

**Files:**
- Modify: `public/manifest.json`

- [ ] **Step 1: Add the commands block**

In `public/manifest.json`, add a top-level `"commands"` key (e.g. directly before `"content_scripts"`):

```json
  "commands": {
    "launch-picker": {
      "suggested_key": { "default": "Alt+Shift+P" },
      "description": "인포커터 선택 모드 시작"
    },
    "toggle-global": {
      "suggested_key": { "default": "Alt+Shift+O" },
      "description": "인포커터 전역 숨김 켜기/끄기"
    },
    "toggle-site-profile": {
      "suggested_key": { "default": "Alt+Shift+S" },
      "description": "현재 사이트 프로필 켜기/끄기"
    },
    "toggle-peek": {
      "suggested_key": { "default": "Alt+Shift+E" },
      "description": "숨긴 요소 임시 보기"
    }
  },
```

- [ ] **Step 2: Verify it survives the build**

Run: `./infocutter check`
Then: `node -e "const m=require('./dist/manifest.json'); const k=Object.keys(m.commands||{}); if(k.length!==4) throw new Error('commands missing: '+JSON.stringify(k)); console.log('commands ok', k.join(','))"`
Expected: prints `commands ok launch-picker,toggle-global,toggle-site-profile,toggle-peek` (build.mjs does not strip the `commands` key).

- [ ] **Step 3: Commit**

```bash
git add public/manifest.json
git commit -m "feat(infocutter): declare four keyboard commands"
```

---

## Task 8: Background `chrome.commands.onCommand` listener

**Files:**
- Modify: `src/background/service-worker.ts`

- [ ] **Step 1: Import the command map**

In `src/background/service-worker.ts`, add after the existing storage import (line 4):

```ts
import { commandIds, toggleCommandMessage } from "../shared/commands.js";
```

- [ ] **Step 2: Add a top-frame toggle sender helper**

In `src/background/service-worker.ts`, add this function next to `sendMessageToTopFrame` (after line 224):

```ts
async function sendToggleToTopFrame(tabId: number, messageType: string, enabled: boolean): Promise<void> {
  await chrome.tabs.sendMessage(tabId, { type: messageType, enabled, toast: true }, { frameId: 0 });
}
```

- [ ] **Step 3: Add the onCommand listener**

In `src/background/service-worker.ts`, add at the end of the file (after the final `chrome.storage.onChanged` listener):

```ts
chrome.commands.onCommand.addListener((command, tab) => {
  void (async () => {
    const tabId = tab?.id;
    const url = tab?.url ?? "";
    if (typeof tabId !== "number" || !isSupportedUrl(url)) {
      return;
    }

    const ready = await ensureTabReady(tabId);
    if (!ready) {
      return;
    }

    if (command === commandIds.launchPicker) {
      await sendMessageToAllFrames(tabId, messageTypes.stopPicker);
      pickerFocusByTab.set(tabId, {
        focused: true,
        frameScope: null,
        label: "메인 문서 선택 중"
      });
      await sendMessageToTopFrame(tabId, messageTypes.startPicker);
      return;
    }

    if (command === commandIds.togglePeek) {
      await sendMessageToAllFrames(tabId, messageTypes.togglePeek);
      return;
    }

    const toggleMessage = toggleCommandMessage(command);
    if (!toggleMessage) {
      return;
    }

    const store = await readStore();
    if (command === commandIds.toggleGlobal) {
      await sendToggleToTopFrame(tabId, toggleMessage, !store.settings.globalEnabled);
      return;
    }

    if (command === commandIds.toggleSiteProfile) {
      const profile = findMatchingProfile(store, url);
      await sendToggleToTopFrame(tabId, toggleMessage, !(profile?.enabled ?? true));
    }
  })().catch((error: unknown) => {
    console.warn("인포커터 단축키 처리에 실패했습니다", error);
  });
});
```

- [ ] **Step 4: Verify**

Run: `./infocutter check`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/background/service-worker.ts
git commit -m "feat(infocutter): route keyboard commands to picker and toggles"
```

---

## Task 9: Final build + manual end-to-end verification

**Files:** none (verification only)

- [ ] **Step 1: Full release-candidate build**

Run: `./infocutter rc`
Expected: PASS through rebuild + check + package; `dist-package/infocutter-v0.1.0.zip` produced.

- [ ] **Step 2: Load and verify via chrome-devtools MCP**

Use the `vibecode-chrome-devtools-mcp-testing` flow to load `dist/` and verify on a content-rich page:

- `Alt+Shift+P` → picker overlay appears.
- Create at least one hide rule, then:
  - `Alt+Shift+E` → hidden element reappears translucent with a dashed amber outline; toast "peek 켬". Press again → re-hidden; toast "peek 끔".
  - `Alt+Shift+O` → element show/hide flips; toast "전역 숨김 끔"/"전역 숨김 켬"; toolbar badge count clears/returns.
  - `Alt+Shift+S` on a page with a matching profile → toast "이 사이트 끔"/"이 사이트 켬"; on a page with no profile → toast "이 사이트에 규칙 없음".
- Confirm `chrome://extensions/shortcuts` lists all four commands as rebindable.

- [ ] **Step 3: Confirm no regressions**

Run: `./infocutter check`
Expected: PASS (13 tests).

---

## Self-review notes (already reconciled with spec)

- Badge: no new code; the existing `updateBadgeForTab` + background `storage.onChanged` already flips the count badge on global/site toggle (spec §Feedback/Badge).
- Peek reveal omits `display:none` and adds `opacity`/`outline`, so the single `[attr]` rule alone controls visibility (spec §Peek mechanism).
- Toggle messages reused as-is; `toast` flag keeps popup-triggered toggles silent (spec §Command mapping).
- Three content-script lists kept in sync (spec §Components).
- Only `src/shared/commands.ts` is node-tested; content/manifest/background verified by `./infocutter check` + devtools (spec §Testing).
