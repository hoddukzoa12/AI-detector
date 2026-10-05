# AI Auto-Masking — Phase 1 (Detection Core) Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the testable AI detection core — config store, LiteLLM client (prompt/parse), detection filter, and the content block collector — that turns serialized page blocks into rules written to the separate `aiRuleStore`. No UI, no auto-trigger (those are Phase 2).

**Architecture:** New shared modules (`ai-config`, `ai-llm-client`, `ai-detection`) + a content collector (`ai-collector`), plus an `enabledCategories` setting on the existing separate AI store. Pure logic (prompt build, response parse, category/confidence filter) is unit-tested; the thin `fetch` and the DOM serialization are verified via a devtools stub.

**Tech Stack:** TypeScript shared ES modules + content global scripts; Manifest V3 (`<all_urls>` already grants the LiteLLM host); node:test.

---

## Working context

- Worktree: `/Users/jeonghan/Documents/WORK/WORKSPACE/apps/chrome-extension-mono-wt-infocutter-aifill`
- Run from: `cd vibecode-chrome-extension-infocutter`
- Branch `feat/infocutter-ai-fill-20260531` (stacked on the AI-separation branch, so `aiRuleStore`/`replaceAiSiteRules`/`ai-types` already exist).
- Gate per task: `./infocutter check`. `pipe:test` is a glob — new test files auto-collect.
- Strict conventions: no `//` line comments (`/* */` ok); shared types use `type` (repo eslint `consistent-type-definitions: type`); content global files start with `/* eslint-disable @typescript-eslint/no-unused-vars */`; `Reflect.get(...)` results MUST be annotated `: unknown` (repo eslint `no-unsafe-assignment`); all magic values are named constants.

## File structure

- `src/shared/constants.ts` (modify) — `AI_CONFIG_KEY`, `AI_DETECTION_ENDPOINT_DEFAULT`, `AI_CONFIDENCE_THRESHOLD`, `AI_COLLECT_MAX_BLOCKS`, `AI_COLLECT_MAX_TEXT_LENGTH`.
- `src/content/constants.ts` (modify) — `AI_COLLECT_MAX_BLOCKS`, `AI_COLLECT_MAX_TEXT_LENGTH`.
- `src/shared/ai-types.ts` (modify) — add `enabledCategories` to `AiRuleStore.settings`.
- `src/shared/ai-rule-storage.ts` (modify) — normalize `enabledCategories` + `setAiEnabledCategories`.
- `src/shared/ai-config.ts` (new) — endpoint/key/model + analyzed hosts.
- `src/shared/ai-llm-client.ts` (new) — `AiBlock`/`AiDetection` types, `buildAiDetectionPrompt`, `parseAiDetectionResponse`, `callLiteLLM`.
- `src/shared/ai-detection.ts` (new) — `filterDetections`, `runAiDetection`.
- `tests/ai-config.test.ts`, `tests/ai-llm-client.test.ts`, `tests/ai-detection.test.ts` (new).
- `src/content/contracts.d.ts` (modify) — ambient `AiBlockRecord`.
- `src/content/ai-collector.ts` (new) — `collectAiBlocks()`.
- Three content-script lists — register `ai-collector.js`.

---

## Task 1: Constants

**Files:** Modify `src/shared/constants.ts`, `src/content/constants.ts`

- [ ] **Step 1:** Append to `src/shared/constants.ts`:
```ts
export const AI_CONFIG_KEY = "infocutter.aiConfig";
export const AI_DETECTION_ENDPOINT_DEFAULT = "https://llm.ranode.net/v1";
export const AI_CONFIDENCE_THRESHOLD = 0.6;
export const AI_COLLECT_MAX_BLOCKS = 120;
export const AI_COLLECT_MAX_TEXT_LENGTH = 200;
```

- [ ] **Step 2:** Append to `src/content/constants.ts` (among the top-level consts):
```ts
const AI_COLLECT_MAX_BLOCKS = 120;
const AI_COLLECT_MAX_TEXT_LENGTH = 200;
```

- [ ] **Step 3:** `./infocutter check` → PASS.

- [ ] **Step 4:** Commit:
```bash
git add src/shared/constants.ts src/content/constants.ts
git commit -m "feat(infocutter): add AI detection constants"
```

---

## Task 2: enabledCategories on the AI store settings

**Files:** Modify `src/shared/ai-types.ts`, `src/shared/ai-rule-storage.ts`; Test `tests/ai-rule-storage.test.ts`

- [ ] **Step 1: extend the type**

In `src/shared/ai-types.ts`, change the `AiRuleStore` settings line:
```ts
  settings: { globalEnabled: boolean };
```
to:
```ts
  settings: { globalEnabled: boolean; enabledCategories: AiRuleCategory[] };
```

- [ ] **Step 2: add a failing test**

Append to `tests/ai-rule-storage.test.ts`:
```ts
void test("normalizeAiRuleStore defaults enabledCategories to all categories and filters unknown ones", () => {
  const def = normalizeAiRuleStore(undefined);
  assert.equal(def.settings.enabledCategories.length, 6);

  const narrowed = normalizeAiRuleStore({
    version: 1,
    settings: { globalEnabled: true, enabledCategories: ["sexual", "nonsense"] },
    sites: []
  });
  assert.deepEqual(narrowed.settings.enabledCategories, ["sexual"]);
});
```
(Add `normalizeAiRuleStore` to the existing import from `../src/shared/ai-rule-storage.js` if it is not already imported — it is.)

- [ ] **Step 3: run it — FAIL**

Run: `npm run pipe:test` → FAIL (`enabledCategories` is undefined / typecheck error on the new settings field).

- [ ] **Step 4: implement**

In `src/shared/ai-rule-storage.ts`:

(a) add `AI_RULE_CATEGORIES` to the constants import:
```ts
import { AI_RULE_CATEGORIES, AI_RULE_STORAGE_KEY, AI_RULE_STORAGE_VERSION } from "./constants.js";
```
(it already imports the latter two.)

(b) add a helper above `normalizeAiRuleStore`:
```ts
function normalizeEnabledCategories(value: unknown): AiRuleCategory[] {
  if (!Array.isArray(value)) {
    return [...AI_RULE_CATEGORIES];
  }
  return value.filter((entry): entry is AiRuleCategory => AI_RULE_CATEGORIES.includes(entry as AiRuleCategory));
}
```

(c) in `emptyAiRuleStore`, set the settings to:
```ts
    settings: { globalEnabled: true, enabledCategories: [...AI_RULE_CATEGORIES] },
```

(d) in `normalizeAiRuleStore`, after computing `globalEnabled`, add:
```ts
  const enabledCategoriesValue: unknown = settingsValue && typeof settingsValue === "object" ? Reflect.get(settingsValue, "enabledCategories") : undefined;
  const enabledCategories = normalizeEnabledCategories(enabledCategoriesValue);
```
and change the returned settings to:
```ts
    settings: { globalEnabled, enabledCategories },
```

(e) append a setter (after the other exported mutations):
```ts
export async function setAiEnabledCategories(categories: AiRuleCategory[]): Promise<AiRuleStore> {
  const store = await readAiRuleStore();
  const next: AiRuleStore = { ...store, settings: { ...store.settings, enabledCategories: normalizeEnabledCategories(categories) } };
  await writeAiRuleStore(next);
  return next;
}
```
Note: the content-side `normalizeAiStoreForContent` (in `ai-runtime.ts`) is intentionally NOT changed — the render lane stays category-agnostic.

- [ ] **Step 5:** `./infocutter check` → PASS (new test passes; existing AI tests still pass).

- [ ] **Step 6:** Commit:
```bash
git add src/shared/ai-types.ts src/shared/ai-rule-storage.ts tests/ai-rule-storage.test.ts
git commit -m "feat(infocutter): add enabledCategories to AI store settings"
```

---

## Task 3: ai-config module (credentials + analyzed hosts)

**Files:** Create `src/shared/ai-config.ts`, `tests/ai-config.test.ts`

- [ ] **Step 1: failing test** — create `tests/ai-config.test.ts`:
```ts
import test from "node:test";
import assert from "node:assert/strict";

import { isHostAnalyzed, normalizeAiConfig } from "../src/shared/ai-config.js";

void test("normalizeAiConfig fills defaults for unknown input", () => {
  const config = normalizeAiConfig(undefined);
  assert.equal(config.endpoint, "https://llm.ranode.net/v1");
  assert.equal(config.apiKey, "");
  assert.equal(config.model, "");
  assert.deepEqual(config.analyzedHosts, []);
});

void test("isHostAnalyzed reflects the analyzedHosts list", () => {
  const config = normalizeAiConfig({ endpoint: "x", apiKey: "k", model: "m", analyzedHosts: ["example.com"] });
  assert.equal(isHostAnalyzed(config, "example.com"), true);
  assert.equal(isHostAnalyzed(config, "other.com"), false);
});
```

- [ ] **Step 2:** `npm run pipe:test` → FAIL (module missing).

- [ ] **Step 3:** create `src/shared/ai-config.ts`:
```ts
import { AI_CONFIG_KEY, AI_DETECTION_ENDPOINT_DEFAULT } from "./constants.js";

export type AiConfig = {
  endpoint: string;
  apiKey: string;
  model: string;
  analyzedHosts: string[];
};

function emptyAiConfig(): AiConfig {
  return { endpoint: AI_DETECTION_ENDPOINT_DEFAULT, apiKey: "", model: "", analyzedHosts: [] };
}

export function normalizeAiConfig(candidate: unknown): AiConfig {
  if (!candidate || typeof candidate !== "object") {
    return emptyAiConfig();
  }
  const endpoint: unknown = Reflect.get(candidate, "endpoint");
  const apiKey: unknown = Reflect.get(candidate, "apiKey");
  const model: unknown = Reflect.get(candidate, "model");
  const analyzedHosts: unknown = Reflect.get(candidate, "analyzedHosts");
  return {
    endpoint: typeof endpoint === "string" && endpoint.length > 0 ? endpoint : AI_DETECTION_ENDPOINT_DEFAULT,
    apiKey: typeof apiKey === "string" ? apiKey : "",
    model: typeof model === "string" ? model : "",
    analyzedHosts: Array.isArray(analyzedHosts)
      ? analyzedHosts.filter((host): host is string => typeof host === "string")
      : []
  };
}

export async function readAiConfig(): Promise<AiConfig> {
  const result = await chrome.storage.local.get(AI_CONFIG_KEY);
  return normalizeAiConfig(result[AI_CONFIG_KEY]);
}

export async function writeAiConfig(config: AiConfig): Promise<void> {
  await chrome.storage.local.set({ [AI_CONFIG_KEY]: config });
}

export function isHostAnalyzed(config: AiConfig, host: string): boolean {
  return config.analyzedHosts.includes(host);
}

export async function markHostAnalyzed(host: string): Promise<AiConfig> {
  const config = await readAiConfig();
  if (config.analyzedHosts.includes(host)) {
    return config;
  }
  const next: AiConfig = { ...config, analyzedHosts: [...config.analyzedHosts, host] };
  await writeAiConfig(next);
  return next;
}
```

- [ ] **Step 4:** `./infocutter check` → PASS (2 new tests).

- [ ] **Step 5:** Commit:
```bash
git add src/shared/ai-config.ts tests/ai-config.test.ts
git commit -m "feat(infocutter): add AI config store (credentials + analyzed hosts)"
```

---

## Task 4: ai-llm-client (prompt build, response parse, call)

**Files:** Create `src/shared/ai-llm-client.ts`, `tests/ai-llm-client.test.ts`

- [ ] **Step 1: failing test** — create `tests/ai-llm-client.test.ts`:
```ts
import test from "node:test";
import assert from "node:assert/strict";

import { buildAiDetectionPrompt, parseAiDetectionResponse } from "../src/shared/ai-llm-client.js";

void test("buildAiDetectionPrompt includes the enabled categories and block selectors", () => {
  const prompt = buildAiDetectionPrompt(
    [{ selector: "#ad1", text: "광고", imageAlt: "", imageSrc: "" }],
    ["sexual", "violence"]
  );
  assert.ok(prompt.includes("sexual"));
  assert.ok(prompt.includes("violence"));
  assert.ok(prompt.includes("#ad1"));
  assert.ok(prompt.toUpperCase().includes("JSON"));
});

void test("parseAiDetectionResponse extracts a JSON array, coerces category, drops malformed", () => {
  const body = "여기 결과입니다:\n```json\n[" +
    '{"selector":"#ad1","category":"sexual","reason":"r","confidence":0.9},' +
    '{"selector":"#ad2","category":"weird","reason":"r","confidence":0.7},' +
    '{"category":"gore","reason":"no selector","confidence":0.8}' +
    "]\n```";
  const result = parseAiDetectionResponse(body);
  assert.equal(result.length, 2);
  assert.equal(result[0].category, "sexual");
  assert.equal(result[1].category, "other");
  assert.equal(result[1].selector, "#ad2");
});
```

- [ ] **Step 2:** `npm run pipe:test` → FAIL (module missing).

- [ ] **Step 3:** create `src/shared/ai-llm-client.ts`:
```ts
import { AI_RULE_CATEGORIES } from "./constants.js";
import type { AiRuleCategory } from "./ai-types.js";

export type AiBlock = {
  selector: string;
  text: string;
  imageAlt: string;
  imageSrc: string;
};

export type AiDetection = {
  selector: string;
  category: AiRuleCategory;
  reason: string;
  confidence: number;
};

export function buildAiDetectionPrompt(blocks: AiBlock[], categories: AiRuleCategory[]): string {
  const categoryLine = categories.join(", ");
  const blockLines = blocks
    .map((block) => `- selector: ${block.selector} | text: ${block.text} | imageAlt: ${block.imageAlt} | imageSrc: ${block.imageSrc}`)
    .join("\n");
  return [
    "You flag web page regions that are provocative/disturbing for a user who wants them hidden.",
    `Only consider these categories: ${categoryLine}.`,
    "Given the page blocks below (each has a CSS selector), return ONLY a JSON array.",
    'Each item: {"selector": string, "category": one of the listed categories, "reason": short string, "confidence": number 0..1}.',
    "Return an empty array [] if nothing qualifies. Use the exact selector strings provided.",
    "",
    "Blocks:",
    blockLines
  ].join("\n");
}

function coerceCategory(value: unknown): AiRuleCategory {
  return AI_RULE_CATEGORIES.includes(value as AiRuleCategory) ? (value as AiRuleCategory) : "other";
}

export function parseAiDetectionResponse(text: string): AiDetection[] {
  const start = text.indexOf("[");
  const end = text.lastIndexOf("]");
  if (start < 0 || end <= start) {
    return [];
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(text.slice(start, end + 1));
  } catch {
    return [];
  }
  if (!Array.isArray(parsed)) {
    return [];
  }
  const detections: AiDetection[] = [];
  for (const entry of parsed) {
    if (!entry || typeof entry !== "object") {
      continue;
    }
    const selector: unknown = Reflect.get(entry, "selector");
    if (typeof selector !== "string" || selector.length === 0) {
      continue;
    }
    const reason: unknown = Reflect.get(entry, "reason");
    const confidence: unknown = Reflect.get(entry, "confidence");
    detections.push({
      selector,
      category: coerceCategory(Reflect.get(entry, "category")),
      reason: typeof reason === "string" ? reason : "",
      confidence: typeof confidence === "number" ? confidence : 0
    });
  }
  return detections;
}

export async function callLiteLLM(config: { endpoint: string; apiKey: string; model: string }, prompt: string): Promise<string> {
  const response = await fetch(`${config.endpoint}/chat/completions`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${config.apiKey}`
    },
    body: JSON.stringify({
      model: config.model,
      messages: [{ role: "user", content: prompt }]
    })
  });
  if (!response.ok) {
    throw new Error(`LiteLLM 호출 실패: ${response.status}`);
  }
  const data: unknown = await response.json();
  const choices: unknown = data && typeof data === "object" ? Reflect.get(data, "choices") : null;
  const first: unknown = Array.isArray(choices) ? choices[0] : null;
  const message: unknown = first && typeof first === "object" ? Reflect.get(first, "message") : null;
  const content: unknown = message && typeof message === "object" ? Reflect.get(message, "content") : null;
  return typeof content === "string" ? content : "";
}
```

- [ ] **Step 4:** `./infocutter check` → PASS (2 new tests).

- [ ] **Step 5:** Commit:
```bash
git add src/shared/ai-llm-client.ts tests/ai-llm-client.test.ts
git commit -m "feat(infocutter): add LiteLLM client (prompt build + tolerant parse)"
```

---

## Task 5: ai-detection (filter + run)

**Files:** Create `src/shared/ai-detection.ts`, `tests/ai-detection.test.ts`

- [ ] **Step 1: failing test** — create `tests/ai-detection.test.ts`:
```ts
import test from "node:test";
import assert from "node:assert/strict";

import { filterDetections } from "../src/shared/ai-detection.js";

void test("filterDetections keeps only enabled categories above the threshold", () => {
  const detections = [
    { selector: "#a", category: "sexual" as const, reason: "", confidence: 0.9 },
    { selector: "#b", category: "violence" as const, reason: "", confidence: 0.5 },
    { selector: "#c", category: "gore" as const, reason: "", confidence: 0.95 }
  ];
  const kept = filterDetections(detections, ["sexual", "violence"], 0.6);
  assert.deepEqual(kept.map((d) => d.selector), ["#a"]);
});
```

- [ ] **Step 2:** `npm run pipe:test` → FAIL (module missing).

- [ ] **Step 3:** create `src/shared/ai-detection.ts`:
```ts
import { AI_CONFIDENCE_THRESHOLD } from "./constants.js";
import { replaceAiSiteRules } from "./ai-rule-storage.js";
import type { AiBlock, AiDetection } from "./ai-llm-client.js";
import type { AiRuleCategory } from "./ai-types.js";

export function filterDetections(
  detections: AiDetection[],
  enabledCategories: AiRuleCategory[],
  threshold: number
): AiDetection[] {
  return detections.filter((detection) => (
    enabledCategories.includes(detection.category) && detection.confidence >= threshold
  ));
}

export async function runAiDetection(
  matchers: string[],
  blocks: AiBlock[],
  enabledCategories: AiRuleCategory[],
  model: string,
  detect: (blocks: AiBlock[]) => Promise<AiDetection[]>
): Promise<number> {
  const detections = await detect(blocks);
  const kept = filterDetections(detections, enabledCategories, AI_CONFIDENCE_THRESHOLD);
  if (kept.length === 0) {
    return 0;
  }
  await replaceAiSiteRules(
    matchers,
    kept.map((detection) => ({
      selector: detection.selector,
      category: detection.category,
      reason: detection.reason,
      confidence: detection.confidence
    })),
    model
  );
  return kept.length;
}
```

- [ ] **Step 4:** `./infocutter check` → PASS (1 new test).

- [ ] **Step 5:** Commit:
```bash
git add src/shared/ai-detection.ts tests/ai-detection.test.ts
git commit -m "feat(infocutter): add AI detection filter + run orchestration"
```

---

## Task 6: content block collector + registration

**Files:** Modify `src/content/contracts.d.ts`; Create `src/content/ai-collector.ts`; register in three lists.

- [ ] **Step 1: ambient block type** — append to `src/content/contracts.d.ts`:
```ts
interface AiBlockRecord {
  selector: string;
  text: string;
  imageAlt: string;
  imageSrc: string;
}
```

- [ ] **Step 2: create `src/content/ai-collector.ts`:**
```ts
/* eslint-disable @typescript-eslint/no-unused-vars */

function isAiCollectableElement(element: Element): boolean {
  if (typeof element.id === "string" && element.id.startsWith("infocutter-")) {
    return false;
  }
  if (element.closest("input, textarea, select, [type='password'], [contenteditable='true']")) {
    return false;
  }
  return true;
}

function collectAiBlocks(): AiBlockRecord[] {
  const blocks: AiBlockRecord[] = [];
  const candidates = document.querySelectorAll("section, article, li, figure, aside, img, video");
  for (const element of candidates) {
    if (blocks.length >= AI_COLLECT_MAX_BLOCKS) {
      break;
    }
    if (!isAiCollectableElement(element)) {
      continue;
    }
    const text = (element.textContent ?? "").replace(/\s+/g, " ").trim().slice(0, AI_COLLECT_MAX_TEXT_LENGTH);
    const image = element instanceof HTMLImageElement ? element : element.querySelector("img");
    const imageAlt = image instanceof HTMLImageElement ? image.alt : "";
    const imageSrc = image instanceof HTMLElement ? image.getAttribute("src") ?? "" : "";
    if (text.length === 0 && imageSrc.length === 0) {
      continue;
    }
    blocks.push({ selector: buildSelector(element), text, imageAlt, imageSrc });
  }
  return blocks;
}
```
(`buildSelector` is the existing content global from `selector-engine.ts`; `AI_COLLECT_MAX_BLOCKS`/`AI_COLLECT_MAX_TEXT_LENGTH` are the content consts from Task 1; `AiBlockRecord` is the ambient type from Step 1.)

- [ ] **Step 3: register `ai-collector.js`** — insert `"src/content/ai-collector.js"` immediately BEFORE `"src/content/render-coordinator.js"` in all three lists (`public/manifest.json`, `scripts/build.mjs`, `src/background/service-worker.ts`). It uses `buildSelector` from `selector-engine.js`, which loads earlier.

- [ ] **Step 4: verify**

Run `./infocutter check` → PASS. Then:
```bash
node -e "const js=require('./dist/manifest.json').content_scripts[0].js; const c=js.indexOf('src/content/ai-collector.js'); const s=js.indexOf('src/content/selector-engine.js'); const i=js.indexOf('src/content/index.js'); if(!(s<c && c<i)) throw new Error('order: '+js.join(',')); console.log('order ok')"
```
Expect `order ok`, and `dist/src/content/ai-collector.js` exists.

- [ ] **Step 5: commit**
```bash
git add src/content/contracts.d.ts src/content/ai-collector.ts public/manifest.json scripts/build.mjs src/background/service-worker.ts
git commit -m "feat(infocutter): add AI block collector content module"
```

---

## Task 7: Final verification (devtools, stubbed LLM)

**Files:** none.

- [ ] **Step 1:** `./infocutter rc` → PASS.
- [ ] **Step 2:** Devtools harness (content side only — `collectAiBlocks` is the one new content global): load the compiled content scripts on a page with cards + an image + a `<input>`, then via `evaluate_script` call `collectAiBlocks()` and assert: returns an array of `{ selector, text, imageAlt, imageSrc }`; every selector resolves to exactly the intended element (`document.querySelectorAll(selector).length >= 1`); a form `<input>`/password field is NOT represented; length ≤ `AI_COLLECT_MAX_BLOCKS`; text fields are ≤ `AI_COLLECT_MAX_TEXT_LENGTH`; no console errors. (The shared brain — `buildAiDetectionPrompt`/`parseAiDetectionResponse`/`filterDetections`/`normalizeAiConfig` — is already covered by node:test and needs no devtools.)
- [ ] **Step 3:** `./infocutter check` → still PASS.

---

## Self-review notes (reconciled with spec)

- Phase 1 = detection core only (config, client, detection, collector, enabledCategories). UI, the manual popup trigger, the background detect-composition, and auto first-visit are Phase 2 (spec §Phasing).
- Secrets in `ai-config` (`infocutter.aiConfig`), separate from the rule store (spec §Architecture). `enabledCategories` is a rule-related preference, so it lives in `aiRuleStore.settings`; the AI render lane stays category-agnostic.
- Pure logic unit-tested (prompt/parse/filter/config-normalize); `callLiteLLM` thin `fetch` + DOM collector verified via devtools (spec §Testing).
- All magic values are constants; `Reflect.get` annotated `: unknown`; shared types use `type`; content collector is a global script registered in the three lists (repo conventions).
- No manual-store or manual-render change; AI data still only flows into `aiRuleStore`.
