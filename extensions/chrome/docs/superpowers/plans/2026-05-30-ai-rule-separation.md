# AI Rule Separation Interface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give AI-generated hide rules a fully separate, typed home (own types, own storage key, own DOM lane) so they can never mix with manual rules.

**Architecture:** A new `aiRuleStore` (key `infocutter.aiRuleStore`, v1) with its own shared types + storage module, plus a content render lane (`ai-runtime.ts`) using its own marker attribute + style element. Mirrors the existing four-store / selector-render patterns; touches manual code only via one orchestration line and one storage-change line. AI population (LiteLLM) is out of scope.

**Tech Stack:** TypeScript — shared ES modules (background/options/tests) + content global scripts; Manifest V3; node:test.

---

## Working context

- Worktree: `/Users/jeonghan/Documents/WORK/WORKSPACE/apps/chrome-extension-mono-wt-infocutter-aisep`
- Run from: `cd vibecode-chrome-extension-infocutter`
- Gate per task: `./infocutter check` (lint + typecheck + test). `pipe:test` runs `node --test 'dist/tests/*.js'` (glob) — new test files are auto-collected; no package.json change needed.
- Strict: no `//` line comments (`/* */` allowed). New content global-script files start with `/* eslint-disable @typescript-eslint/no-unused-vars */`.
- All magic values go in constants (single source). Categories are a `const` array with the type derived from it.
- Content (`content/*.ts`) are global scripts (no import/export); shared (`shared/*.ts`) are ES modules. Content mirrors shared types as ambient `*Record` interfaces in `content/contracts.d.ts` (existing convention).

## File structure

- `src/shared/constants.ts` (modify) — `AI_RULE_STORAGE_KEY`, `AI_RULE_STORAGE_VERSION`, `AI_RULE_CATEGORIES`.
- `src/content/constants.ts` (modify) — `AI_RULE_STORAGE_KEY`, `AI_HIDDEN_ATTR`, `AI_STYLE_ELEMENT_ID`.
- `src/shared/ai-types.ts` (new) — `AiRuleCategory`, `AiRule`, `AiSiteRules`, `AiRuleStore`.
- `src/shared/ai-rule-storage.ts` (new) — normalize + read/write + match + mutations.
- `tests/ai-rule-storage.test.ts` (new) — unit tests.
- `src/content/contracts.d.ts` (modify) — ambient `AiRuleRecord`/`AiSiteRulesRecord`/`AiRuleStoreRecord`.
- `src/content/ai-runtime.ts` (new) — `renderAiRules()` lane.
- `src/content/render-coordinator.ts` (modify) — call `renderAiRules()`.
- `src/content/index.ts` (modify) — re-render on `AI_RULE_STORAGE_KEY` change.
- Three content-script lists (manifest, build.mjs, service-worker.ts) — register `ai-runtime.js`.

---

## Task 1: Constants

**Files:** Modify `src/shared/constants.ts`, `src/content/constants.ts`

- [ ] **Step 1: shared constants**

Append to `src/shared/constants.ts`:
```ts
export const AI_RULE_STORAGE_KEY = "infocutter.aiRuleStore";
export const AI_RULE_STORAGE_VERSION = 1;
export const AI_RULE_CATEGORIES = ["violence", "sexual", "gore", "hate", "shock", "other"] as const;
```

- [ ] **Step 2: content constants**

In `src/content/constants.ts`, append (after the existing `const` declarations, before any `messageTypes` object if present — anywhere among the top-level consts is fine):
```ts
const AI_RULE_STORAGE_KEY = "infocutter.aiRuleStore";
const AI_HIDDEN_ATTR = "data-infocutter-ai-hidden";
const AI_STYLE_ELEMENT_ID = "infocutter-ai-style-rules";
```

- [ ] **Step 3: Verify**

Run: `./infocutter check`
Expected: PASS. (The new content consts are unused so far — covered by the file's eslint-disable header.)

- [ ] **Step 4: Commit**

```bash
git add src/shared/constants.ts src/content/constants.ts
git commit -m "feat(infocutter): add AI rule store constants"
```

---

## Task 2: AI types

**Files:** Create `src/shared/ai-types.ts`

- [ ] **Step 1: Create the types**

Create `src/shared/ai-types.ts`:
```ts
import { AI_RULE_CATEGORIES } from "./constants.js";

export type AiRuleCategory = (typeof AI_RULE_CATEGORIES)[number];

export interface AiRule {
  id: string;
  selector: string;
  enabled: boolean;
  category: AiRuleCategory;
  reason: string;
  confidence: number;
  model: string;
  createdAt: string;
}

export interface AiSiteRules {
  id: string;
  matchers: string[];
  enabled: boolean;
  generatedAt: string;
  rules: AiRule[];
}

export interface AiRuleStore {
  version: number;
  settings: { globalEnabled: boolean };
  sites: AiSiteRules[];
}
```

- [ ] **Step 2: Verify**

Run: `./infocutter check`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add src/shared/ai-types.ts
git commit -m "feat(infocutter): add AI rule types derived from category constant"
```

---

## Task 3: AI rule storage module + unit tests (TDD)

**Files:** Create `src/shared/ai-rule-storage.ts`, `tests/ai-rule-storage.test.ts`

- [ ] **Step 1: Write the failing test**

Create `tests/ai-rule-storage.test.ts`:
```ts
import test from "node:test";
import assert from "node:assert/strict";

import { findMatchingAiSite, normalizeAiRuleStore } from "../src/shared/ai-rule-storage.js";

void test("normalizeAiRuleStore returns an empty v1 store for unknown input", () => {
  const store = normalizeAiRuleStore(undefined);
  assert.equal(store.version, 1);
  assert.equal(store.settings.globalEnabled, true);
  assert.deepEqual(store.sites, []);
});

void test("normalizeAiRuleStore coerces an unknown category to 'other' and drops selectorless rules", () => {
  const store = normalizeAiRuleStore({
    version: 1,
    settings: { globalEnabled: false },
    sites: [{
      id: "s1",
      matchers: ["https://example.com/*"],
      enabled: true,
      generatedAt: "2026-05-30T00:00:00.000Z",
      rules: [
        { id: "r1", selector: ".ad", enabled: true, category: "nonsense", reason: "x", confidence: 0.9, model: "m", createdAt: "t" },
        { id: "r2", enabled: true }
      ]
    }]
  });
  assert.equal(store.settings.globalEnabled, false);
  assert.equal(store.sites.length, 1);
  assert.equal(store.sites[0].rules.length, 1);
  assert.equal(store.sites[0].rules[0].category, "other");
});

void test("findMatchingAiSite matches by URL matcher", () => {
  const store = normalizeAiRuleStore({
    version: 1,
    settings: { globalEnabled: true },
    sites: [{ id: "s1", matchers: ["https://example.com/*"], enabled: true, generatedAt: "t", rules: [] }]
  });
  assert.equal(findMatchingAiSite(store, "https://example.com/page")?.id, "s1");
  assert.equal(findMatchingAiSite(store, "https://other.com/")?.id, undefined);
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `npm run pipe:test`
Expected: FAIL — cannot find module `../src/shared/ai-rule-storage.js`.

- [ ] **Step 3: Implement the module**

Create `src/shared/ai-rule-storage.ts`:
```ts
import { AI_RULE_CATEGORIES, AI_RULE_STORAGE_KEY, AI_RULE_STORAGE_VERSION } from "./constants.js";
import { matchesUrl } from "./storage-matchers.js";
import type { AiRule, AiRuleCategory, AiRuleStore, AiSiteRules } from "./ai-types.js";

function generateAiId(): string {
  if (typeof crypto !== "undefined" && typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `ai-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

function emptyAiRuleStore(): AiRuleStore {
  return {
    version: AI_RULE_STORAGE_VERSION,
    settings: { globalEnabled: true },
    sites: []
  };
}

function normalizeCategory(value: unknown): AiRuleCategory {
  return AI_RULE_CATEGORIES.includes(value as AiRuleCategory) ? (value as AiRuleCategory) : "other";
}

function normalizeAiRule(raw: unknown): AiRule | null {
  if (!raw || typeof raw !== "object") {
    return null;
  }
  const selector = Reflect.get(raw, "selector");
  if (typeof selector !== "string" || selector.length === 0) {
    return null;
  }
  const id = Reflect.get(raw, "id");
  const enabled = Reflect.get(raw, "enabled");
  const reason = Reflect.get(raw, "reason");
  const confidence = Reflect.get(raw, "confidence");
  const model = Reflect.get(raw, "model");
  const createdAt = Reflect.get(raw, "createdAt");
  return {
    id: typeof id === "string" && id.length > 0 ? id : generateAiId(),
    selector,
    enabled: typeof enabled === "boolean" ? enabled : true,
    category: normalizeCategory(Reflect.get(raw, "category")),
    reason: typeof reason === "string" ? reason : "",
    confidence: typeof confidence === "number" ? confidence : 0,
    model: typeof model === "string" ? model : "",
    createdAt: typeof createdAt === "string" ? createdAt : new Date(0).toISOString()
  };
}

function normalizeAiSite(raw: unknown): AiSiteRules | null {
  if (!raw || typeof raw !== "object") {
    return null;
  }
  const matchersValue = Reflect.get(raw, "matchers");
  const matchers = Array.isArray(matchersValue)
    ? matchersValue.filter((matcher): matcher is string => typeof matcher === "string" && matcher.length > 0)
    : [];
  const rulesValue = Reflect.get(raw, "rules");
  const rules = Array.isArray(rulesValue)
    ? rulesValue.map(normalizeAiRule).filter((rule): rule is AiRule => rule !== null)
    : [];
  const id = Reflect.get(raw, "id");
  const enabled = Reflect.get(raw, "enabled");
  const generatedAt = Reflect.get(raw, "generatedAt");
  return {
    id: typeof id === "string" && id.length > 0 ? id : generateAiId(),
    matchers,
    enabled: typeof enabled === "boolean" ? enabled : true,
    generatedAt: typeof generatedAt === "string" ? generatedAt : new Date(0).toISOString(),
    rules
  };
}

export function normalizeAiRuleStore(candidate: unknown): AiRuleStore {
  if (!candidate || typeof candidate !== "object") {
    return emptyAiRuleStore();
  }
  const settingsValue = Reflect.get(candidate, "settings");
  const globalEnabled =
    settingsValue &&
    typeof settingsValue === "object" &&
    "globalEnabled" in settingsValue &&
    typeof settingsValue.globalEnabled === "boolean"
      ? settingsValue.globalEnabled
      : true;
  const sitesValue = Reflect.get(candidate, "sites");
  const sites = Array.isArray(sitesValue)
    ? sitesValue.map(normalizeAiSite).filter((site): site is AiSiteRules => site !== null)
    : [];
  return {
    version: AI_RULE_STORAGE_VERSION,
    settings: { globalEnabled },
    sites
  };
}

export async function readAiRuleStore(): Promise<AiRuleStore> {
  const result = await chrome.storage.local.get(AI_RULE_STORAGE_KEY);
  return normalizeAiRuleStore(result[AI_RULE_STORAGE_KEY]);
}

export async function writeAiRuleStore(store: AiRuleStore): Promise<void> {
  await chrome.storage.local.set({ [AI_RULE_STORAGE_KEY]: store });
}

export function findMatchingAiSite(store: AiRuleStore, url: string): AiSiteRules | null {
  return store.sites.find((site) => site.matchers.some((matcher) => matchesUrl(matcher, url))) ?? null;
}

export async function setAiGlobalEnabled(enabled: boolean): Promise<AiRuleStore> {
  const store = await readAiRuleStore();
  const next: AiRuleStore = { ...store, settings: { globalEnabled: enabled } };
  await writeAiRuleStore(next);
  return next;
}

export async function setAiSiteEnabled(siteId: string, enabled: boolean): Promise<AiRuleStore> {
  const store = await readAiRuleStore();
  const next: AiRuleStore = {
    ...store,
    sites: store.sites.map((site) => (site.id === siteId ? { ...site, enabled } : site))
  };
  await writeAiRuleStore(next);
  return next;
}

export async function setAiRuleEnabled(siteId: string, ruleId: string, enabled: boolean): Promise<AiRuleStore> {
  const store = await readAiRuleStore();
  const next: AiRuleStore = {
    ...store,
    sites: store.sites.map((site) => (
      site.id === siteId
        ? { ...site, rules: site.rules.map((rule) => (rule.id === ruleId ? { ...rule, enabled } : rule)) }
        : site
    ))
  };
  await writeAiRuleStore(next);
  return next;
}

export async function replaceAiSiteRules(
  matchers: string[],
  rules: { selector: string; category: AiRuleCategory; reason: string; confidence: number }[],
  model: string
): Promise<AiRuleStore> {
  const store = await readAiRuleStore();
  const timestamp = new Date().toISOString();
  const site: AiSiteRules = {
    id: generateAiId(),
    matchers,
    enabled: true,
    generatedAt: timestamp,
    rules: rules.map((rule) => ({
      id: generateAiId(),
      selector: rule.selector,
      enabled: true,
      category: normalizeCategory(rule.category),
      reason: rule.reason,
      confidence: rule.confidence,
      model,
      createdAt: timestamp
    }))
  };
  const sameMatchers = (left: string[], right: string[]): boolean =>
    left.length === right.length && left.every((matcher, index) => matcher === right[index]);
  const existingIndex = store.sites.findIndex((candidate) => sameMatchers(candidate.matchers, matchers));
  const sites = existingIndex >= 0
    ? store.sites.map((candidate, index) => (index === existingIndex ? site : candidate))
    : [...store.sites, site];
  const next: AiRuleStore = { ...store, sites };
  await writeAiRuleStore(next);
  return next;
}

export async function clearAiRules(): Promise<AiRuleStore> {
  const store = await readAiRuleStore();
  const next: AiRuleStore = { ...store, sites: [] };
  await writeAiRuleStore(next);
  return next;
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `./infocutter check`
Expected: PASS — the three new tests pass (suite count rises by 3).

- [ ] **Step 5: Commit**

```bash
git add src/shared/ai-rule-storage.ts tests/ai-rule-storage.test.ts
git commit -m "feat(infocutter): add separate AI rule storage module with tests"
```

---

## Task 4: Content render lane + wiring

**Files:** Modify `src/content/contracts.d.ts`, `src/content/render-coordinator.ts`, `src/content/index.ts`; Create `src/content/ai-runtime.ts`; register in three lists.

- [ ] **Step 1: Ambient content types**

Append to `src/content/contracts.d.ts`:
```ts
interface AiRuleRecord {
  id: string;
  selector: string;
  enabled: boolean;
}

interface AiSiteRulesRecord {
  id: string;
  matchers: string[];
  enabled: boolean;
  rules: AiRuleRecord[];
}

interface AiRuleStoreRecord {
  version: number;
  settings: { globalEnabled: boolean };
  sites: AiSiteRulesRecord[];
}
```

- [ ] **Step 2: Create the render lane `src/content/ai-runtime.ts`**

```ts
/* eslint-disable @typescript-eslint/no-unused-vars */

function clearAiHiddenMarkers(): void {
  document.querySelectorAll(`[${AI_HIDDEN_ATTR}]`).forEach((element) => {
    element.removeAttribute(AI_HIDDEN_ATTR);
  });
}

function ensureAiStyleElement(): HTMLStyleElement {
  const existing = document.getElementById(AI_STYLE_ELEMENT_ID);
  if (existing instanceof HTMLStyleElement) {
    return existing;
  }
  const style = document.createElement("style");
  style.id = AI_STYLE_ELEMENT_ID;
  document.documentElement.append(style);
  return style;
}

function normalizeAiStoreForContent(candidate: unknown): AiRuleStoreRecord {
  const empty: AiRuleStoreRecord = { version: 1, settings: { globalEnabled: true }, sites: [] };
  if (!candidate || typeof candidate !== "object") {
    return empty;
  }
  const settingsValue = Reflect.get(candidate, "settings");
  const globalEnabled =
    settingsValue && typeof settingsValue === "object" && "globalEnabled" in settingsValue && typeof settingsValue.globalEnabled === "boolean"
      ? settingsValue.globalEnabled
      : true;
  const sitesValue = Reflect.get(candidate, "sites");
  const sites: AiSiteRulesRecord[] = Array.isArray(sitesValue)
    ? sitesValue
        .filter((site): site is Record<string, unknown> => !!site && typeof site === "object")
        .map((site) => {
          const matchersValue = Reflect.get(site, "matchers");
          const rulesValue = Reflect.get(site, "rules");
          const enabled = Reflect.get(site, "enabled");
          const id = Reflect.get(site, "id");
          return {
            id: typeof id === "string" ? id : "",
            matchers: Array.isArray(matchersValue) ? matchersValue.filter((m): m is string => typeof m === "string") : [],
            enabled: typeof enabled === "boolean" ? enabled : true,
            rules: Array.isArray(rulesValue)
              ? rulesValue
                  .filter((rule): rule is Record<string, unknown> => !!rule && typeof rule === "object")
                  .map((rule) => {
                    const selector = Reflect.get(rule, "selector");
                    const ruleEnabled = Reflect.get(rule, "enabled");
                    const ruleId = Reflect.get(rule, "id");
                    return {
                      id: typeof ruleId === "string" ? ruleId : "",
                      selector: typeof selector === "string" ? selector : "",
                      enabled: typeof ruleEnabled === "boolean" ? ruleEnabled : true
                    };
                  })
                  .filter((rule) => rule.selector.length > 0)
              : []
          };
        })
    : [];
  return { version: 1, settings: { globalEnabled }, sites };
}

async function renderAiRules(): Promise<void> {
  const result = await chrome.storage.local.get(AI_RULE_STORAGE_KEY);
  const store = normalizeAiStoreForContent(result[AI_RULE_STORAGE_KEY]);
  const style = ensureAiStyleElement();
  clearAiHiddenMarkers();

  if (!store.settings.globalEnabled) {
    style.textContent = "";
    return;
  }

  const url = ownerPageUrl();
  const site = store.sites.find((candidate) => candidate.enabled && candidate.matchers.some((matcher) => matchesUrl(matcher, url)));
  if (!site) {
    style.textContent = "";
    return;
  }

  const enabledRules = site.rules.filter((rule) => rule.enabled);
  if (enabledRules.length === 0) {
    style.textContent = "";
    return;
  }

  style.textContent = `[${AI_HIDDEN_ATTR}] { display: none !important; }`;
  for (const rule of enabledRules) {
    try {
      document.querySelectorAll(rule.selector).forEach((element) => {
        element.setAttribute(AI_HIDDEN_ATTR, "true");
      });
    } catch {
      /* skip invalid selector */
    }
  }
}
```

- [ ] **Step 3: Wire into render-coordinator**

Replace `src/content/render-coordinator.ts` body so `renderAllRules` also runs the AI lane:
```ts
/* eslint-disable @typescript-eslint/no-unused-vars */

async function renderAllRules(): Promise<void> {
  await renderRules();
  await renderTextBlockRules();
  await renderAiRules();
}
```

- [ ] **Step 4: Re-render on AI store change**

In `src/content/index.ts`, find the storage-change condition:
```ts
    if (STORAGE_KEY in changes || TEXT_BLOCK_STORAGE_KEY in changes) {
      void renderAllRules();
    }
```
Replace with:
```ts
    if (STORAGE_KEY in changes || TEXT_BLOCK_STORAGE_KEY in changes || AI_RULE_STORAGE_KEY in changes) {
      void renderAllRules();
    }
```

- [ ] **Step 5: Register `ai-runtime.js`**

Insert `"src/content/ai-runtime.js"` immediately BEFORE `"src/content/render-coordinator.js"` in all three lists: `public/manifest.json` (`content_scripts[0].js`), `scripts/build.mjs` (`contentScriptFiles`), `src/background/service-worker.ts` (`contentScriptFiles`).

- [ ] **Step 6: Verify**

Run: `./infocutter check`
Expected: PASS. Then confirm the built file loads in order:
```bash
node -e "const js=require('./dist/manifest.json').content_scripts[0].js; const a=js.indexOf('src/content/ai-runtime.js'); const r=js.indexOf('src/content/render-coordinator.js'); const i=js.indexOf('src/content/index.js'); if(!(a>=0 && a<r && r<i)) throw new Error('order: '+js.join(',')); console.log('order ok')"
```
Expected: `order ok`, and `dist/src/content/ai-runtime.js` exists.

- [ ] **Step 7: Commit**

```bash
git add src/content/contracts.d.ts src/content/ai-runtime.ts src/content/render-coordinator.ts src/content/index.ts public/manifest.json scripts/build.mjs src/background/service-worker.ts
git commit -m "feat(infocutter): add separate AI render lane and wiring"
```

---

## Task 5: Final verification (devtools harness)

**Files:** none (verification only)

- [ ] **Step 1: Build** — `./infocutter rc` (expect PASS + zip).
- [ ] **Step 2: Devtools harness** — serve `dist/`, load a harness page that includes the compiled content scripts (with a `chrome` shim whose `storage.local.get` returns a seeded `infocutter.aiRuleStore`), then via `evaluate_script` verify:
  - `renderAiRules()` marks the AI-targeted elements with `data-infocutter-ai-hidden` and sets the `infocutter-ai-style-rules` style to `display:none`.
  - The manual lane (`data-infocutter-selector-hidden` / `infocutter-style-rules`) is untouched and independent.
  - Disabling `settings.globalEnabled` in the seeded store empties only the AI style element.
  - No console errors.
- [ ] **Step 3: Gate** — `./infocutter check` still PASS.

---

## Self-review notes (reconciled with spec)

- Separation: distinct types (`AiRule` etc., no shared alias), distinct key (`infocutter.aiRuleStore`), distinct DOM lane (`AI_HIDDEN_ATTR` + `AI_STYLE_ELEMENT_ID`), distinct modules (spec §Separation guarantees). The only cross-boundary reuse is the generic `matchesUrl` pure helper (spec §guarantee 4).
- Constants: categories as a const array with derived type; key/version/DOM ids all named constants (spec §Constants; no hardcoding).
- No manual-store change beyond one render-coordinator line + one storage.onChanged clause; no migration (new store, v1).
- Tests: `ai-rule-storage` normalize/match unit-tested (shared, importable); render lane verified via devtools (spec §Testing).
