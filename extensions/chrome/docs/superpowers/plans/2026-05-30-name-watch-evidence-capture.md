# Name Watch & Evidence Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Register watched names (with aliases); when matched text appears on any page, mask it from the victim, and on confirmation capture a full-page screenshot, hash it, and save a tamper-evident PDF evidence package for a defamation complaint.

**Architecture:** New domain package `infocutter-watch` (pure logic, injected as `globalThis.InfocutterWatch` IIFE) shared by content/background/options. A content runtime scans text, masks matches, and shows a confirm chip. On confirm, the background orchestrates a scroll-stitch full-page capture (`chrome.scripting` + `captureVisibleTab`), hands tiles to an offscreen document that stitches via canvas, stamps metadata, computes SHA-256 hashes, and builds a PDF with jsPDF. The PDF + raw PNG/HTML/manifest are saved via `chrome.downloads`; metadata is logged append-only in IndexedDB.

**Tech Stack:** TypeScript, Manifest V3, `chrome.storage.local`, IndexedDB, `chrome.offscreen`, `chrome.downloads`, `chrome.scripting`, jsPDF (MIT, vendored), `node:test`.

**Reference spec:** `docs/superpowers/specs/2026-05-30-name-watch-evidence-capture-design.md`

---

## File Structure

**Created:**
- `packages/infocutter-watch/src/index.ts` — domain types + normalize/migrate + matching helpers (pure, no DOM/chrome)
- `src/shared/watch-storage.ts` — chrome.storage.local read/write/mutations for watch store
- `src/shared/evidence-db.ts` — IndexedDB append-only evidence record store
- `src/content/watch-runtime.ts` — scan, mask, confirm chip, trigger capture
- `src/content/dom-block.ts` — shared block-container inference (extracted from text-block-runtime)
- `src/offscreen/index.ts` — stitch tiles, stamp header, hash, build PDF
- `public/offscreen.html` — offscreen document host
- `src/options/name-watch.ts` — options "이름 감시" tab (targets + settings + evidence list)
- `tests/watch.test.ts` — domain + storage unit tests

**Modified:**
- `src/shared/constants.ts` — add `WATCH_STORAGE_KEY`, `WATCH_STORAGE_VERSION`
- `src/content/constants.ts` — mirror keys + new message types + mask attr/ids
- `src/shared/messages.ts` — new message types
- `src/content/text-block-runtime.ts` — use shared `dom-block.ts` helpers
- `src/content/index.ts` — boot watch-runtime
- `src/background/service-worker.ts` — `captureEvidence` handler + offscreen lifecycle + downloads + queue
- `src/popup/index.ts`, `src/popup/elements.ts` — watch global toggle + counts
- `src/options/index.ts`, `src/options/elements.ts` — register new tab
- `public/manifest.json` — `offscreen`, `unlimitedStorage` perms; `optional_permissions: ["downloads"]`; content_scripts js order
- `scripts/build.mjs` — generate `watch-package.js` IIFE; add `watch-runtime.js`/`watch-package.js` to `contentScriptFiles`; copy offscreen; wire offscreen into manifest
- `tsconfig.packages.json` — already globs `packages/**/*.ts` (no change needed; verify)
- `package.json` — `pipe:test` glob to run all `dist/tests/*.test.js`
- `vendor/jspdf.js` (created) + build copy step

---

## Phase 1 — Domain package `infocutter-watch` (pure, TDD)

### Task 1: Watch domain types + factory + normalize

**Files:**
- Create: `packages/infocutter-watch/src/index.ts`
- Test: `tests/watch.test.ts`

- [ ] **Step 1: Write the failing test**

Create `tests/watch.test.ts`:

```ts
import test from "node:test";
import assert from "node:assert/strict";

import {
  WATCH_STORAGE_VERSION,
  createWatchTarget,
  emptyWatchStore,
  normalizeWatchStore,
  watchTerms,
  matchTerms
} from "../packages/infocutter-watch/src/index.js";

void test("emptyWatchStore returns versioned empty store", () => {
  const store = emptyWatchStore();
  assert.equal(store.version, WATCH_STORAGE_VERSION);
  assert.equal(store.settings.globalEnabled, true);
  assert.equal(store.settings.autoMask, true);
  assert.deepEqual(store.targets, []);
});

void test("createWatchTarget normalizes name and aliases", () => {
  const target = createWatchTarget({ name: "  김철순 ", aliases: ["철순", "  ", "철순"] });
  assert.equal(target.name, "김철순");
  assert.deepEqual(target.aliases, ["철순"]);
  assert.equal(target.enabled, true);
  assert.equal(typeof target.id, "string");
  assert.ok(target.id.length > 0);
});

void test("normalizeWatchStore drops invalid targets and coerces settings", () => {
  const store = normalizeWatchStore({
    version: 1,
    settings: { globalEnabled: false, autoMask: "nope" },
    targets: [
      { id: "a", name: "김철순", aliases: ["철순"], enabled: true, createdAt: "x", updatedAt: "y" },
      { id: "b", name: "", aliases: [] },
      "garbage"
    ]
  });
  assert.equal(store.settings.globalEnabled, false);
  assert.equal(store.settings.autoMask, true);
  assert.equal(store.targets.length, 1);
  assert.equal(store.targets[0]?.name, "김철순");
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run pipe:packages && tsc -p tsconfig.json && node --test dist/tests/watch.test.js`
Expected: FAIL — module `infocutter-watch` not found / exports undefined.

- [ ] **Step 3: Write minimal implementation**

Create `packages/infocutter-watch/src/index.ts`:

```ts
export const WATCH_STORAGE_VERSION = 1 as const;

export type WatchTarget = {
  id: string;
  name: string;
  aliases: string[];
  enabled: boolean;
  createdAt: string;
  updatedAt: string;
};

export type WatchSettings = {
  globalEnabled: boolean;
  autoMask: boolean;
};

export type WatchStore = {
  version: typeof WATCH_STORAGE_VERSION;
  settings: WatchSettings;
  targets: WatchTarget[];
};

function generateWatchId(): string {
  return `iw-${Math.random().toString(36).slice(2, 10)}-${Date.now().toString(36)}`;
}

function cleanTerm(value: unknown): string {
  return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function uniqueNonEmpty(values: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const value of values) {
    if (value.length > 0 && !seen.has(value)) {
      seen.add(value);
      result.push(value);
    }
  }
  return result;
}

export function emptyWatchStore(): WatchStore {
  return {
    version: WATCH_STORAGE_VERSION,
    settings: { globalEnabled: true, autoMask: true },
    targets: []
  };
}

export function createWatchTarget(input: { name: string; aliases?: string[]; id?: string }): WatchTarget {
  const timestamp = new Date().toISOString();
  return {
    id: input.id && input.id.length > 0 ? input.id : generateWatchId(),
    name: cleanTerm(input.name),
    aliases: uniqueNonEmpty((input.aliases ?? []).map(cleanTerm)),
    enabled: true,
    createdAt: timestamp,
    updatedAt: timestamp
  };
}

function normalizeWatchTarget(candidate: unknown): WatchTarget | null {
  if (!candidate || typeof candidate !== "object") {
    return null;
  }
  const record = candidate as Record<string, unknown>;
  const name = cleanTerm(record.name);
  if (name.length === 0) {
    return null;
  }
  const timestamp = new Date().toISOString();
  return {
    id: typeof record.id === "string" && record.id.length > 0 ? record.id : generateWatchId(),
    name,
    aliases: uniqueNonEmpty(Array.isArray(record.aliases) ? record.aliases.map(cleanTerm) : []),
    enabled: record.enabled !== false,
    createdAt: typeof record.createdAt === "string" ? record.createdAt : timestamp,
    updatedAt: typeof record.updatedAt === "string" ? record.updatedAt : timestamp
  };
}

export function normalizeWatchStore(candidate: unknown): WatchStore {
  if (!candidate || typeof candidate !== "object") {
    return emptyWatchStore();
  }
  const record = candidate as Record<string, unknown>;
  const settings = (record.settings ?? {}) as Record<string, unknown>;
  const targets = Array.isArray(record.targets)
    ? record.targets.map(normalizeWatchTarget).filter((target): target is WatchTarget => target !== null)
    : [];
  return {
    version: WATCH_STORAGE_VERSION,
    settings: {
      globalEnabled: settings.globalEnabled !== false,
      autoMask: settings.autoMask !== false
    },
    targets
  };
}

export function watchTerms(store: WatchStore): string[] {
  const terms: string[] = [];
  for (const target of store.targets) {
    if (!target.enabled) {
      continue;
    }
    for (const term of [target.name, ...target.aliases]) {
      const normalized = term.toLowerCase();
      if (normalized.length >= 2) {
        terms.push(normalized);
      }
    }
  }
  return uniqueNonEmpty(terms);
}

export function matchTerms(text: string, terms: string[]): string | null {
  const haystack = text.replace(/\s+/g, " ").toLowerCase();
  for (const term of terms) {
    if (haystack.includes(term)) {
      return term;
    }
  }
  return null;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run pipe:packages && tsc -p tsconfig.json && node --test dist/tests/watch.test.js`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add packages/infocutter-watch/src/index.ts tests/watch.test.ts
git commit -m "feat(infocutter): add infocutter-watch domain package"
```

### Task 2: Matching helpers — term length guard + alias match

**Files:**
- Modify: `tests/watch.test.ts`

- [ ] **Step 1: Write the failing test** — append to `tests/watch.test.ts`:

```ts
void test("watchTerms excludes disabled targets and short terms", () => {
  const store = normalizeWatchStore({
    targets: [
      { name: "김철순", aliases: ["철", "철순이"], enabled: true },
      { name: "이영희", aliases: [], enabled: false }
    ]
  });
  const terms = watchTerms(store);
  assert.ok(terms.includes("김철순"));
  assert.ok(terms.includes("철순이"));
  assert.ok(!terms.includes("철"), "1글자 별칭은 제외");
  assert.ok(!terms.includes("이영희"), "비활성 대상 제외");
});

void test("matchTerms returns matched term via substring, case/space-insensitive", () => {
  const terms = watchTerms(normalizeWatchStore({ targets: [{ name: "김철순", aliases: [] }] }));
  assert.equal(matchTerms("어제  김철순 씨가", terms), "김철순");
  assert.equal(matchTerms("관계 없는 문장", terms), null);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run pipe:packages && tsc -p tsconfig.json && node --test dist/tests/watch.test.js`
Expected: PASS already if Task 1 impl is correct; if any assertion fails, fix `watchTerms`/`matchTerms` in `packages/infocutter-watch/src/index.ts` to satisfy them. (This task locks matching behavior with explicit tests.)

- [ ] **Step 3: Commit**

```bash
git add tests/watch.test.ts
git commit -m "test(infocutter): lock watch term matching behavior"
```

---

## Phase 2 — Storage wiring

### Task 3: Constants for watch storage

**Files:**
- Modify: `src/shared/constants.ts`
- Modify: `src/content/constants.ts`

- [ ] **Step 1: Add to `src/shared/constants.ts`** (after the NETWORK_RULE lines):

```ts
export const WATCH_STORAGE_KEY = "infocutter.watchStore";
export const WATCH_STORAGE_VERSION = 1;
export const WATCH_MASK_ATTR = "data-infocutter-watch-mask";
export const WATCH_CHIP_ID = "infocutter-watch-chip";
```

- [ ] **Step 2: Mirror in `src/content/constants.ts`** (this file is ambient-global for content scripts; add alongside existing `const` declarations):

```ts
const WATCH_STORAGE_KEY = "infocutter.watchStore";
const WATCH_STORAGE_VERSION = 1;
const WATCH_MASK_ATTR = "data-infocutter-watch-mask";
const WATCH_CHIP_ID = "infocutter-watch-chip";
```

- [ ] **Step 3: Add message types in `src/content/constants.ts`** `messageTypes` object AND `src/shared/messages.ts` `messageTypes` object (keep both in sync):

```ts
  getWatchState: "infocutter/get-watch-state",
  captureEvidence: "infocutter/capture-evidence",
  toggleWatchGlobalEnabled: "infocutter/toggle-watch-global-enabled",
  toggleWatchAutoMask: "infocutter/toggle-watch-auto-mask"
```

- [ ] **Step 4: Verify typecheck**

Run: `npm run pipe:typecheck`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/shared/constants.ts src/content/constants.ts src/shared/messages.ts
git commit -m "feat(infocutter): add watch storage constants and message types"
```

### Task 4: Watch storage read/write/mutations

**Files:**
- Create: `src/shared/watch-storage.ts`
- Modify: `tests/watch.test.ts`

- [ ] **Step 1: Write the failing test** — append to `tests/watch.test.ts`:

```ts
import { applyWatchMutation } from "../src/shared/watch-storage.js";

void test("applyWatchMutation add/toggle/remove target", () => {
  let store = emptyWatchStore();
  store = applyWatchMutation(store, { kind: "add", name: "김철순", aliases: ["철순이"] });
  assert.equal(store.targets.length, 1);
  const id = store.targets[0]!.id;

  store = applyWatchMutation(store, { kind: "toggle", id, enabled: false });
  assert.equal(store.targets[0]!.enabled, false);

  store = applyWatchMutation(store, { kind: "setGlobalEnabled", enabled: false });
  assert.equal(store.settings.globalEnabled, false);

  store = applyWatchMutation(store, { kind: "remove", id });
  assert.equal(store.targets.length, 0);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npm run pipe:packages && tsc -p tsconfig.json && node --test dist/tests/watch.test.js`
Expected: FAIL — `applyWatchMutation` not found.

- [ ] **Step 3: Write implementation** — Create `src/shared/watch-storage.ts`:

```ts
import {
  createWatchTarget,
  emptyWatchStore,
  normalizeWatchStore
} from "../../packages/infocutter-watch/src/index.js";
import type { WatchStore } from "../../packages/infocutter-watch/src/index.js";
import { WATCH_STORAGE_KEY } from "./constants.js";

export type WatchMutation =
  | { kind: "add"; name: string; aliases: string[] }
  | { kind: "remove"; id: string }
  | { kind: "toggle"; id: string; enabled: boolean }
  | { kind: "setAliases"; id: string; aliases: string[] }
  | { kind: "setGlobalEnabled"; enabled: boolean }
  | { kind: "setAutoMask"; enabled: boolean };

export function applyWatchMutation(store: WatchStore, mutation: WatchMutation): WatchStore {
  const now = new Date().toISOString();
  switch (mutation.kind) {
    case "add":
      return { ...store, targets: [...store.targets, createWatchTarget({ name: mutation.name, aliases: mutation.aliases })] };
    case "remove":
      return { ...store, targets: store.targets.filter((target) => target.id !== mutation.id) };
    case "toggle":
      return {
        ...store,
        targets: store.targets.map((target) =>
          target.id === mutation.id ? { ...target, enabled: mutation.enabled, updatedAt: now } : target)
      };
    case "setAliases":
      return {
        ...store,
        targets: store.targets.map((target) =>
          target.id === mutation.id
            ? { ...createWatchTarget({ name: target.name, aliases: mutation.aliases, id: target.id }), enabled: target.enabled, createdAt: target.createdAt }
            : target)
      };
    case "setGlobalEnabled":
      return { ...store, settings: { ...store.settings, globalEnabled: mutation.enabled } };
    case "setAutoMask":
      return { ...store, settings: { ...store.settings, autoMask: mutation.enabled } };
    default:
      return store;
  }
}

export async function readWatchStore(): Promise<WatchStore> {
  const result = await chrome.storage.local.get(WATCH_STORAGE_KEY);
  return normalizeWatchStore(result[WATCH_STORAGE_KEY]);
}

export async function writeWatchStore(store: WatchStore): Promise<void> {
  await chrome.storage.local.set({ [WATCH_STORAGE_KEY]: store });
}

export async function mutateWatchStore(mutation: WatchMutation): Promise<WatchStore> {
  const next = applyWatchMutation(await readWatchStore(), mutation);
  await writeWatchStore(next);
  return next;
}

export { emptyWatchStore };
```

- [ ] **Step 4: Run test to verify it passes**

Run: `npm run pipe:packages && tsc -p tsconfig.json && node --test dist/tests/watch.test.js`
Expected: PASS.

- [ ] **Step 5: Update `package.json` `pipe:test` to run all test files** — change the script to:

```json
    "pipe:test": "npm run pipe:build && node --test dist/tests/",
```

- [ ] **Step 6: Verify full test run**

Run: `npm run pipe:test`
Expected: PASS (selector + watch suites).

- [ ] **Step 7: Commit**

```bash
git add src/shared/watch-storage.ts tests/watch.test.ts package.json
git commit -m "feat(infocutter): watch store mutations + run all test suites"
```

### Task 5: Evidence IndexedDB store (append-only)

**Files:**
- Create: `src/shared/evidence-db.ts`

- [ ] **Step 1: Write implementation** — Create `src/shared/evidence-db.ts`:

```ts
export type EvidenceRecord = {
  id: string;
  sequence: number;
  targetId: string;
  matchedTerm: string;
  url: string;
  pageTitle: string;
  matchedText: string;
  htmlExcerpt: string;
  capturedAt: string;
  pngSha256: string;
  htmlSha256: string;
  pdfFilename: string;
  downloadId: number | null;
};

const DB_NAME = "infocutter-evidence";
const DB_VERSION = 1;
const STORE = "records";

function openDb(): Promise<IDBDatabase> {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);
    request.onupgradeneeded = () => {
      const db = request.result;
      if (!db.objectStoreNames.contains(STORE)) {
        const store = db.createObjectStore(STORE, { keyPath: "id" });
        store.createIndex("byDedup", ["url", "htmlSha256"], { unique: false });
        store.createIndex("bySequence", "sequence", { unique: false });
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

export async function appendEvidence(record: EvidenceRecord): Promise<void> {
  const db = await openDb();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.objectStore(STORE).add(record);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
  db.close();
}

export async function listEvidence(): Promise<EvidenceRecord[]> {
  const db = await openDb();
  const records = await new Promise<EvidenceRecord[]>((resolve, reject) => {
    const tx = db.transaction(STORE, "readonly");
    const request = tx.objectStore(STORE).getAll();
    request.onsuccess = () => resolve(request.result as EvidenceRecord[]);
    request.onerror = () => reject(request.error);
  });
  db.close();
  return records.sort((left, right) => right.sequence - left.sequence);
}

export async function nextSequence(): Promise<number> {
  const records = await listEvidence();
  return records.reduce((max, record) => Math.max(max, record.sequence), 0) + 1;
}

export async function hasEvidenceFor(url: string, htmlSha256: string): Promise<boolean> {
  const records = await listEvidence();
  return records.some((record) => record.url === url && record.htmlSha256 === htmlSha256);
}

export async function deleteEvidence(id: string): Promise<void> {
  const db = await openDb();
  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE, "readwrite");
    tx.objectStore(STORE).delete(id);
    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error);
  });
  db.close();
}
```

- [ ] **Step 2: Verify typecheck**

Run: `npm run pipe:typecheck`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add src/shared/evidence-db.ts
git commit -m "feat(infocutter): append-only evidence IndexedDB store"
```

---

## Phase 3 — Shared DOM helper extraction + content runtime

### Task 6: Extract shared block-container helpers

**Files:**
- Create: `src/content/dom-block.ts`
- Modify: `src/content/text-block-runtime.ts:111-175`

- [ ] **Step 1:** Create `src/content/dom-block.ts` and move these functions out of `text-block-runtime.ts` verbatim (keep them as ambient-global `const`/`function` to match content-script style): `normalizeTextBlockKeyword`, `isIgnoredTextHost`, `isTextBlockContainer`, `preferredTextBlockContainer`. Rename to neutral names: `normalizeBlockText`, `isIgnoredTextHost`, `isBlockContainer`, `preferredBlockContainer`.

- [ ] **Step 2:** In `src/content/text-block-runtime.ts`, delete the moved definitions (lines ~111-175) and replace internal calls (`normalizeTextBlockKeyword`→`normalizeBlockText`, `preferredTextBlockContainer`→`preferredBlockContainer`).

- [ ] **Step 3:** Add `src/content/dom-block.js` to `contentScriptFiles` in BOTH `scripts/build.mjs` (line 7-18 array) and `src/background/service-worker.ts` (line 12-23 array) and `public/manifest.json` content_scripts js — place it BEFORE `text-block-runtime.js` (load-order dependency).

- [ ] **Step 4: Verify build + existing tests still pass**

Run: `npm run pipe:build && npm run pipe:test`
Expected: PASS — text-block behavior unchanged.

- [ ] **Step 5: Commit**

```bash
git add src/content/dom-block.ts src/content/text-block-runtime.ts scripts/build.mjs src/background/service-worker.ts public/manifest.json
git commit -m "refactor(infocutter): extract shared dom-block container helpers"
```

### Task 7: Watch content runtime — scan + mask + chip

**Files:**
- Create: `src/content/watch-runtime.ts`
- Modify: `src/content/index.ts`
- Modify: `public/options.css` is N/A; chip styles are injected inline by runtime.

- [ ] **Step 1:** Create `src/content/watch-runtime.ts` (ambient-global content style). It must:
  - `readWatchState()` via `chrome.runtime.sendMessage({ type: messageTypes.getWatchState })` returning `{ globalEnabled, autoMask, terms }`.
  - Scan with `document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, ...)` rejecting `isIgnoredTextHost`, accepting nodes whose `normalizeBlockText(text)` matches `matchTerms` (use `globalThis.InfocutterWatch.matchTerms`).
  - For each match, resolve `preferredBlockContainer(parent)`, dedupe by a per-page `Set<string>` keyed by `runtimeId(container)`.
  - Mask: set `container.setAttribute(WATCH_MASK_ATTR, "true")`; inject a `<style>` once: `[${WATCH_MASK_ATTR}] { filter: blur(8px) !important; position: relative !important; }`.
  - Render a chip (`WATCH_CHIP_ID`) anchored to the container via `getBoundingClientRect()`, with `[증거 저장]` and `[무시]` buttons. Use a fixed-position overlay div appended to `document.documentElement`, isolated by id + inline styles (picker-ui pattern).
  - `[무시]` → remove mask + chip for that element.
  - `[증거 저장]` → call `captureEvidenceForElement(container, matchedTerm)`.
  - Debounced `MutationObserver` re-scan (120ms, same as text-block `scheduleTextBlockRender`).
  - Gate on `globalEnabled`. If `autoMask` false, skip blur but still show chip.

  `captureEvidenceForElement`:
  - Temporarily remove blur on the element, `container.scrollIntoView({ block: "center" })`, add a highlight outline.
  - `await chrome.runtime.sendMessage({ type: messageTypes.captureEvidence, payload: { matchedTerm, url: location.href, pageTitle: document.title, matchedText: normalizeBlockText(container.textContent).slice(0, 400), htmlExcerpt: container.outerHTML.slice(0, 200000) } })`.
  - On `{ ok: true }` → set element `display: none`, replace chip with "저장됨" toast (auto-dismiss 2s).
  - On `{ ok: false, error }` → restore blur, show "저장 실패 [재시도]" chip.

- [ ] **Step 2:** In `src/content/index.ts`, after existing boot calls, add `void bootWatchRuntime();` (define `bootWatchRuntime` in watch-runtime to do initial scan + observer setup) guarded so it only runs in the top frame if `frameContext` indicates top (reuse existing frame-context helper; iframe support deferred per spec §8).

- [ ] **Step 3:** Add `src/content/watch-runtime.js` to `contentScriptFiles` (build.mjs + service-worker.ts + manifest) AFTER `dom-block.js` and AFTER the watch package (Task 12), BEFORE `index.js`.

- [ ] **Step 4: Manual smoke via build**

Run: `npm run pipe:build`
Expected: build succeeds; `dist/src/content/watch-runtime.js` exists.

- [ ] **Step 5: Commit**

```bash
git add src/content/watch-runtime.ts src/content/index.ts scripts/build.mjs src/background/service-worker.ts public/manifest.json
git commit -m "feat(infocutter): watch content runtime with mask + confirm chip"
```

---

## Phase 4 — Capture pipeline (offscreen + background)

### Task 8: Vendor jsPDF + build copy

**Files:**
- Create: `vendor/jspdf.js` (UMD build of jsPDF, MIT)
- Modify: `scripts/build.mjs`

- [ ] **Step 1:** Download the jsPDF UMD bundle (MIT) into `vendor/jspdf.js`. Pin a version (e.g. 2.5.x). Verify license header present.

- [ ] **Step 2:** In `scripts/build.mjs` `main()`, after `cp(publicDir, distDir)`, add:

```js
  await mkdir(path.join(distDir, "vendor"), { recursive: true });
  await cp(path.join(projectRoot, "vendor/jspdf.js"), path.join(distDir, "vendor/jspdf.js"));
```

- [ ] **Step 3: Verify**

Run: `npm run pipe:build`
Expected: `dist/vendor/jspdf.js` exists.

- [ ] **Step 4: Commit**

```bash
git add vendor/jspdf.js scripts/build.mjs
git commit -m "build(infocutter): vendor jsPDF for evidence PDF generation"
```

### Task 9: Offscreen document — stitch + stamp + hash + PDF

**Files:**
- Create: `public/offscreen.html`
- Create: `src/offscreen/index.ts`
- Modify: `tsconfig.json` (ensure `src/offscreen/**` compiled — it is via `src/**`; verify include)

- [ ] **Step 1:** Create `public/offscreen.html`:

```html
<!doctype html>
<html lang="ko">
  <head><meta charset="utf-8" /><title>infocutter offscreen</title></head>
  <body>
    <script src="vendor/jspdf.js"></script>
    <script type="module" src="src/offscreen/index.js"></script>
  </body>
</html>
```

- [ ] **Step 2:** Create `src/offscreen/index.ts`. It listens for `chrome.runtime.onMessage` with type `infocutter/offscreen-build` carrying `{ tiles: string[] (dataURLs), tileHeight, totalHeight, totalWidth, dpr, meta }`. It must:
  - Create a canvas `totalWidth × min(totalHeight, MAX_PIXELS/totalWidth)`, draw each tile via `createImageBitmap`/`Image` at its y-offset.
  - Draw a header band (filled rect + text) at top with `meta.url`, `meta.pageTitle`, `meta.capturedAt`, `meta.matchedTerm`.
  - `canvas.toBlob` → PNG `ArrayBuffer`; compute `crypto.subtle.digest("SHA-256", pngBuffer)` → hex.
  - Compute `crypto.subtle.digest("SHA-256", new TextEncoder().encode(meta.htmlExcerpt))` → hex.
  - Build PDF with jsPDF: page 1 = image (`doc.addImage(pngDataUrl, "PNG", ...)` scaled to A4 width); page 2 = metadata text (url, title, capturedAt, matchedTerm, pngSha256, htmlSha256) + footer disclaimer string.
  - `doc.output("arraybuffer")` → PDF bytes.
  - Respond with `{ ok: true, pngBase64, htmlBase64, pdfBase64, pngSha256, htmlSha256 }` (base64 for message transport).
  - `MAX_PIXELS = 178_956_970` (canvas area cap; matches browser limits used by GoFullPage-class tools).
  - Footer disclaimer constant: `"본 자료는 소명 참고자료입니다. 다툼이 있는 사건에서는 공증·증거보전 신청·디지털 포렌식 등 추가 절차가 필요할 수 있습니다."`

- [ ] **Step 3: Verify typecheck/build**

Run: `npm run pipe:build`
Expected: PASS; `dist/src/offscreen/index.js` + `dist/offscreen.html` exist.

- [ ] **Step 4: Commit**

```bash
git add public/offscreen.html src/offscreen/index.ts
git commit -m "feat(infocutter): offscreen stitch+stamp+hash+jsPDF pipeline"
```

### Task 10: Background capture orchestration

**Files:**
- Modify: `src/background/service-worker.ts`

- [ ] **Step 1:** Add a capture module section to `service-worker.ts`:
  - `getWatchState` handler: `readWatchStore()` → `{ ok: true, data: { globalEnabled, autoMask, terms: watchTerms(store) } }`.
  - `toggleWatchGlobalEnabled` / `toggleWatchAutoMask` handlers: `mutateWatchStore({ kind: ... })`.
  - `captureEvidence` handler (serialized via a `captureQueue = captureQueue.then(...)` promise chain like `networkRuleApplyQueue`):
    1. `ensureOffscreen()` — `chrome.offscreen.hasDocument?.()`; if not, `chrome.offscreen.createDocument({ url: "offscreen.html", reasons: ["DOM_PARSING", "BLOBS"], justification: "Stitch screenshot tiles and build evidence PDF" })`.
    2. Inject a measure function via `chrome.scripting.executeScript({ target: { tabId }, func: measurePage })` returning `{ totalHeight, totalWidth, innerHeight, dpr }`.
    3. Loop: for each scroll offset, `executeScript` to `window.scrollTo(0, y)`, wait ~250ms, `chrome.tabs.captureVisibleTab(windowId, { format: "png" })`. Catch quota error (`message.includes("MAX_CAPTURE_VISIBLE_TAB_CALLS_PER_SECOND")`) → wait 1000ms and retry (max 3).
    4. Restore original scroll.
    5. Send tiles + meta to offscreen via `chrome.runtime.sendMessage`; await `{ pngBase64, pdfBase64, htmlBase64, pngSha256, htmlSha256 }`.
    6. Dedup: `hasEvidenceFor(url, htmlSha256)` → if true, respond `{ ok: true, deduped: true }` without saving.
    7. Request `downloads` permission if missing: `chrome.permissions.contains({ permissions: ["downloads"] })`; if false `chrome.permissions.request(...)`.
    8. Save files via `chrome.downloads.download({ url: "data:application/pdf;base64," + pdfBase64, filename: "infocutter-evidence/" + sanitize(name) + "/" + iso + ".pdf", conflictAction: "uniquify" })`; same for `.png`, `.html`, and a `.manifest.json` (JSON.stringify of record + hashes).
    9. `appendEvidence({ id, sequence: await nextSequence(), ... })`.
    10. Respond `{ ok: true }`.
  - `sanitize(name)` = `name.replace(/[^\p{L}\p{N}_-]+/gu, "_")`.
  - `measurePage`/scroll funcs are plain functions passed to `executeScript` (serializable, no closures).

- [ ] **Step 2:** Import at top: `readWatchStore`, `mutateWatchStore` from `../shared/watch-storage.js`; `watchTerms` from watch package; `appendEvidence`, `hasEvidenceFor`, `nextSequence` from `../shared/evidence-db.js`. Add the four new message-type branches in the `onMessage` listener.

- [ ] **Step 3: Verify build/typecheck**

Run: `npm run pipe:build && npm run pipe:typecheck`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add src/background/service-worker.ts
git commit -m "feat(infocutter): background capture queue + offscreen + downloads + evidence log"
```

### Task 11: Manifest permissions + offscreen wiring

**Files:**
- Modify: `public/manifest.json`
- Modify: `scripts/build.mjs`

- [ ] **Step 1:** In `public/manifest.json`:
  - `permissions`: add `"offscreen"`, `"unlimitedStorage"` (keep existing).
  - Add `"optional_permissions": ["downloads"]`.
  - Add `"web_accessible_resources"` entry exposing `vendor/jspdf.js`, `offscreen.html`, `src/offscreen/index.js` is loaded by offscreen doc (same-origin, no WAR needed) — only add WAR if Chrome complains.

- [ ] **Step 2:** In `scripts/build.mjs` `main()` manifest rewrite section, no path rewrite needed for offscreen (it's at dist root via public copy). Verify `manifest.content_scripts[0].js = contentScriptFiles` includes the new files in correct order: `... text-blocks-package.js, watch-package.js, constants.js, ... dom-block.js, text-block-runtime.js, watch-runtime.js, ... index.js`.

- [ ] **Step 3: Verify doctor**

Run: `npm run pipe:rebuild`
Expected: build + doctor PASS.

- [ ] **Step 4: Commit**

```bash
git add public/manifest.json scripts/build.mjs
git commit -m "feat(infocutter): manifest offscreen/unlimitedStorage perms + optional downloads"
```

### Task 12: Generate `watch-package.js` IIFE

**Files:**
- Modify: `scripts/build.mjs`

- [ ] **Step 1:** In `scripts/build.mjs`, add a `watchPackageExports` array and `buildContentWatchPackage()` mirroring `buildContentTextBlocksPackage()`:

```js
const watchPackageExports = [
  "WATCH_STORAGE_VERSION",
  "emptyWatchStore",
  "createWatchTarget",
  "normalizeWatchStore",
  "watchTerms",
  "matchTerms"
];

async function buildContentWatchPackage() {
  const sourcePath = path.join(projectRoot, "packages/infocutter-watch/dist/index.js");
  const targetPath = path.join(distDir, "src/content/watch-package.js");
  const source = await readFile(sourcePath, "utf8");
  const script = source.replace(/^export\s+/gm, "");
  await writeFile(
    targetPath,
    `globalThis.InfocutterWatch = (() => {\n${script}\n\nreturn {\n${watchPackageExports.map((name) => `  ${name}`).join(",\n")}\n};\n})();\n`,
    "utf8"
  );
}
```

Call `await buildContentWatchPackage();` in `main()` after `buildContentTextBlocksPackage()`. Add `"src/content/watch-package.js"` to `contentScriptFiles` (position 2, right after text-blocks-package). Mirror the same entry in `src/background/service-worker.ts` `contentScriptFiles` and `public/manifest.json`.

- [ ] **Step 2:** In `src/content/watch-runtime.ts`, declare ambient type for the global: add `declare const InfocutterWatch: typeof import("../../packages/infocutter-watch/src/index.js");` near top, OR add to `src/content/contracts.d.ts` (preferred — matches existing `InfocutterTextBlocks` pattern). Inspect `contracts.d.ts` and follow it.

- [ ] **Step 3: Verify**

Run: `npm run pipe:rebuild`
Expected: `dist/src/content/watch-package.js` exists with `globalThis.InfocutterWatch`; doctor PASS.

- [ ] **Step 4: Commit**

```bash
git add scripts/build.mjs src/background/service-worker.ts public/manifest.json src/content/contracts.d.ts
git commit -m "build(infocutter): generate watch-package IIFE for content scripts"
```

---

## Phase 5 — UI

### Task 13: Popup — watch toggle + counts

**Files:**
- Modify: `src/popup/elements.ts`, `src/popup/index.ts`, `public/popup.html`, `public/popup.css`

- [ ] **Step 1:** Inspect `src/popup/index.ts` + `public/popup.html` to follow existing section pattern. Add a "이름 감시" section: a toggle bound to `toggleWatchGlobalEnabled`, and a line "등록 N · 이 페이지 발견 X · 저장 Y". Read state via `getWatchState` + a content message for per-page counts (add `getWatchPageCounts` message handled by `watch-runtime` returning `{ found, saved }`, OR derive found via re-query; keep simple: show registered count + evidence total from `listEvidence().length`).

- [ ] **Step 2:** Wire elements in `elements.ts` (follow existing accessor pattern). Bind toggle change → `chrome.runtime.sendMessage({ type: messageTypes.toggleWatchGlobalEnabled, enabled })`.

- [ ] **Step 3: Verify build**

Run: `npm run pipe:build`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add src/popup/ public/popup.html public/popup.css
git commit -m "feat(infocutter): popup name-watch toggle and counts"
```

### Task 14: Options — "이름 감시" tab

**Files:**
- Create: `src/options/name-watch.ts`
- Modify: `src/options/index.ts`, `src/options/elements.ts`, `src/options/tabs.ts`, `public/options.html`, `public/options.css`

- [ ] **Step 1:** Inspect `src/options/tabs.ts` (has `resolveActiveTab`) + `public/options.html` to follow the existing tab registration pattern. Add a new tab id `name-watch` with nav button + panel.

- [ ] **Step 2:** Create `src/options/name-watch.ts` rendering three groups:
  - **이름 관리**: input(name) + alias chips input → `mutateWatchStore({ kind: "add" })`; list each target with enable toggle (`toggle`), alias editor (`setAliases`), delete (`remove`).
  - **설정**: global toggle (`setGlobalEnabled`), auto-mask toggle (`setAutoMask`).
  - **증거 목록**: `listEvidence()` rows (name/url/capturedAt/matchedText snippet) + [PDF 열기] (`chrome.downloads.open(downloadId)` or re-open file) + [삭제] (`deleteEvidence` + optional file removal note).
  - All reads via `readWatchStore`/`listEvidence` directly (options page has chrome APIs).

- [ ] **Step 3:** Register render in `src/options/index.ts` boot + on tab activation.

- [ ] **Step 4: Verify build + lint**

Run: `npm run pipe:check`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/options/ public/options.html public/options.css
git commit -m "feat(infocutter): options name-watch tab (targets, settings, evidence)"
```

---

## Phase 6 — End-to-end verification

### Task 15: Build, gates, and manual MCP verification

**Files:** none (verification only)

- [ ] **Step 1: Full gate**

Run: `npm run pipe:rc`
Expected: rebuild + lint + typecheck + tests + package all PASS. No `// ...` line comments (no-comments-gate).

- [ ] **Step 2: Load + manual verify (chrome-devtools MCP, per `vibecode-chrome-devtools-mcp-testing`)**
  - Load `dist/` unpacked.
  - Options → add watch name "테스트이름".
  - Open a page containing that text → confirm chip appears, content blurred.
  - Click [증거 저장] → confirm `downloads` permission prompt → PDF + png + html + manifest saved under `infocutter-evidence/테스트이름/`.
  - Open PDF → screenshot present, header band shows URL/time/name, page 2 shows both SHA-256 hashes + disclaimer footer.
  - Options → 증거 목록 shows the record; revisit page → no duplicate saved (dedup).

- [ ] **Step 3: Commit any fixes, then summarize**

```bash
git add -A
git commit -m "test(infocutter): e2e verification fixes for name-watch evidence"
```

---

## Self-Review Notes (spec coverage)

- Spec §2 flow → Tasks 7,9,10. §3 requirements → all phases. §4.1 package → Task 1. §4.2 storage → Tasks 4,5. §4.3 runtime → Tasks 6,7. §4.4 background → Task 10. §4.5 offscreen → Task 9. §5 integrity (hash/stamp/raw/append-only) → Tasks 5,9,10. §6 UI → Tasks 13,14. §7 manifest/messages/build → Tasks 3,11,12. §9 testing → Tasks 1,2,4 + Task 15. §8 limits (iframe top-only, term-length guard) → Tasks 7,1. §5 disclaimer → Task 9.
- Open items deferred to implementation (spec §12): jsPDF version pin (Task 8), offscreen vs SW canvas (Task 9 uses offscreen), ZIP export for evidence list (Task 14 uses per-file open; ZIP is post-v1).
