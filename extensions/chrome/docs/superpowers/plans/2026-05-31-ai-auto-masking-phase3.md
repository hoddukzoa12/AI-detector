# AI Auto-Masking Phase 3 (rule management UI) Implementation Plan

> REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** Let the user browse and toggle generated AI rules by category in the options page, and clear them — all within the existing "AI 가림" tab, reading/writing only the separated `aiRuleStore`.

**Architecture:** A new options module `ai-rules.ts` renders `aiRuleStore.sites[].rules[]` grouped per site, filterable by category, with per-rule and per-site enable toggles (reusing existing `setAiRuleEnabled`/`setAiSiteEnabled`) and a clear-all button (`clearAiRules`). Re-renders on `storage.onChanged` for the AI key. A pure `summarizeAiRules` helper is unit-tested. The category-label map is extracted to a shared `ai-category-labels.ts` so settings + rules UI use one source.

**Tech Stack:** MV3 options layer, TS, node:test. No new storage functions (mutators already exist). No manifest change.

---

## Task 1: extract AI_CATEGORY_LABELS (DRY)

**Files:** Create `src/options/ai-category-labels.ts`; modify `src/options/ai-settings.ts`.

- [ ] Create `src/options/ai-category-labels.ts`:
```ts
import type { AiRuleCategory } from "../shared/ai-types.js";

export const AI_CATEGORY_LABELS: Record<AiRuleCategory, string> = {
  violence: "폭력",
  sexual: "선정성",
  gore: "잔혹/고어",
  hate: "혐오 발언",
  shock: "충격/혐오감",
  other: "기타"
};
```
- [ ] In `src/options/ai-settings.ts`: remove the local `AI_CATEGORY_LABELS` const and add `import { AI_CATEGORY_LABELS } from "./ai-category-labels.js";`.
- [ ] `./infocutter check` PASS. Commit `refactor(infocutter): extract AI category labels to shared options module`.

---

## Task 2: summarizeAiRules + test (TDD)

**Files:** Create `src/options/ai-rules.ts` (summary only for now), `tests/ai-rules-summary.test.ts`.

- [ ] **Step 1 — failing test** `tests/ai-rules-summary.test.ts`:
```ts
import test from "node:test";
import assert from "node:assert/strict";

import { summarizeAiRules } from "../src/options/ai-rules.js";
import type { AiRuleStore } from "../src/shared/ai-types.js";

const store: AiRuleStore = {
  version: 1,
  settings: { globalEnabled: true, enabledCategories: ["sexual", "violence"] },
  sites: [
    {
      id: "s1", matchers: ["https://a.com/*"], enabled: true, generatedAt: "t",
      rules: [
        { id: "r1", selector: "#a", enabled: true, category: "sexual", reason: "", confidence: 0.9, model: "m", createdAt: "t" },
        { id: "r2", selector: "#b", enabled: false, category: "violence", reason: "", confidence: 0.8, model: "m", createdAt: "t" }
      ]
    },
    {
      id: "s2", matchers: ["https://b.com/*"], enabled: true, generatedAt: "t",
      rules: [
        { id: "r3", selector: "#c", enabled: true, category: "sexual", reason: "", confidence: 0.7, model: "m", createdAt: "t" }
      ]
    }
  ]
};

void test("summarizeAiRules counts sites, rules, and per-category totals", () => {
  const summary = summarizeAiRules(store);
  assert.equal(summary.totalSites, 2);
  assert.equal(summary.totalRules, 3);
  assert.equal(summary.byCategory.sexual, 2);
  assert.equal(summary.byCategory.violence, 1);
  assert.equal(summary.byCategory.gore, 0);
});
```
- [ ] **Step 2 — implement** `src/options/ai-rules.ts` with the full module (summary + render + wire) below. After this task the test must pass; the render/wire parts are exercised in Task 3+ via devtools.

`src/options/ai-rules.ts`:
```ts
import { AI_RULE_CATEGORIES, AI_RULE_STORAGE_KEY } from "../shared/constants.js";
import type { AiRuleCategory, AiRuleStore, AiRule, AiSiteRules } from "../shared/ai-types.js";
import { readAiRuleStore, setAiSiteEnabled, setAiRuleEnabled, clearAiRules } from "../shared/ai-rule-storage.js";
import { profileNameFromMatcher } from "../shared/storage-matchers.js";
import { AI_CATEGORY_LABELS } from "./ai-category-labels.js";
import {
  aiRuleFilterElement, aiRuleClearButtonElement, aiRuleListElement,
  aiRuleEmptyElement, aiRuleSummaryElement
} from "./elements.js";

export type AiRuleSummary = {
  totalSites: number;
  totalRules: number;
  byCategory: Record<AiRuleCategory, number>;
};

export function summarizeAiRules(store: AiRuleStore): AiRuleSummary {
  const byCategory = {} as Record<AiRuleCategory, number>;
  for (const category of AI_RULE_CATEGORIES) {
    byCategory[category] = 0;
  }
  let totalRules = 0;
  for (const site of store.sites) {
    for (const rule of site.rules) {
      totalRules += 1;
      byCategory[rule.category] += 1;
    }
  }
  return { totalSites: store.sites.length, totalRules, byCategory };
}

function siteLabel(matchers: string[]): string {
  const first = matchers[0];
  return first ? profileNameFromMatcher(first) : "알 수 없는 사이트";
}

function buildRuleRow(siteId: string, rule: AiRule): HTMLElement {
  const row = document.createElement("div");
  row.className = "options__ai-rule";

  const toggleLabel = document.createElement("label");
  toggleLabel.className = "options__ai-rule-toggle";
  const toggle = document.createElement("input");
  toggle.type = "checkbox";
  toggle.checked = rule.enabled;
  toggle.addEventListener("change", () => {
    void setAiRuleEnabled(siteId, rule.id, toggle.checked);
  });
  toggleLabel.append(toggle);

  const badge = document.createElement("span");
  badge.className = "options__ai-badge";
  badge.textContent = AI_CATEGORY_LABELS[rule.category];

  const selector = document.createElement("code");
  selector.className = "options__ai-selector";
  selector.textContent = rule.selector;

  const meta = document.createElement("span");
  meta.className = "options__ai-rule-meta";
  meta.textContent = `${Math.round(rule.confidence * 100)}% · ${rule.reason}`;

  row.append(toggleLabel, badge, selector, meta);
  return row;
}

function buildSiteCard(site: AiSiteRules, filter: AiRuleCategory | "all"): HTMLElement | null {
  const rules = filter === "all" ? site.rules : site.rules.filter((rule) => rule.category === filter);
  if (rules.length === 0) {
    return null;
  }
  const card = document.createElement("section");
  card.className = "options__ai-site-card";

  const header = document.createElement("div");
  header.className = "options__ai-site-header";

  const siteToggleLabel = document.createElement("label");
  siteToggleLabel.className = "options__ai-rule-toggle";
  const siteToggle = document.createElement("input");
  siteToggle.type = "checkbox";
  siteToggle.checked = site.enabled;
  siteToggle.addEventListener("change", () => {
    void setAiSiteEnabled(site.id, siteToggle.checked);
  });
  siteToggleLabel.append(siteToggle);

  const title = document.createElement("h3");
  title.className = "options__ai-site-title";
  title.textContent = siteLabel(site.matchers);

  const count = document.createElement("span");
  count.className = "options__ai-rule-meta";
  count.textContent = `규칙 ${rules.length}개`;

  header.append(siteToggleLabel, title, count);
  card.append(header);
  for (const rule of rules) {
    card.append(buildRuleRow(site.id, rule));
  }
  return card;
}

export async function renderAiRuleList(): Promise<void> {
  const store = await readAiRuleStore();
  const filterValue = aiRuleFilterElement.value;
  const filter: AiRuleCategory | "all" =
    AI_RULE_CATEGORIES.includes(filterValue as AiRuleCategory) ? (filterValue as AiRuleCategory) : "all";

  const summary = summarizeAiRules(store);
  aiRuleSummaryElement.textContent = `사이트 ${summary.totalSites}곳 · 규칙 ${summary.totalRules}개`;

  aiRuleListElement.replaceChildren();
  let shown = 0;
  for (const site of store.sites) {
    const card = buildSiteCard(site, filter);
    if (card) {
      aiRuleListElement.append(card);
      shown += 1;
    }
  }
  aiRuleEmptyElement.hidden = shown > 0;
}

function buildFilterOptions(): void {
  const allOption = document.createElement("option");
  allOption.value = "all";
  allOption.textContent = "전체 카테고리";
  aiRuleFilterElement.append(allOption);
  for (const category of AI_RULE_CATEGORIES) {
    const option = document.createElement("option");
    option.value = category;
    option.textContent = AI_CATEGORY_LABELS[category];
    aiRuleFilterElement.append(option);
  }
}

export function wireAiRules(): void {
  buildFilterOptions();
  aiRuleFilterElement.addEventListener("change", () => {
    void renderAiRuleList();
  });
  aiRuleClearButtonElement.addEventListener("click", () => {
    if (!window.confirm("생성된 AI 규칙을 모두 삭제할까요?")) {
      return;
    }
    void clearAiRules();
  });
  chrome.storage.onChanged.addListener((changes, areaName) => {
    if (areaName === "local" && AI_RULE_STORAGE_KEY in changes) {
      void renderAiRuleList();
    }
  });
  void renderAiRuleList();
}
```
- [ ] **Step 3** `./infocutter check` PASS (1 new test). Commit `feat(infocutter): add AI rule management module (summary + render + toggles)`.

---

## Task 3: options HTML + elements + wire + CSS

**Files:** Modify `public/options.html`, `src/options/elements.ts`, `src/options/index.ts`, `public/options.css`.

- [ ] **options.html** — inside `panel-ai`, AFTER the LiteLLM connection `<section class="options__create-card">`, add:
```html
<section class="options__list-wrap">
  <h2 class="options__section-title">생성된 AI 규칙</h2>
  <div class="options__ai-rule-toolbar">
    <select id="ai-rule-filter" class="options__select"></select>
    <button id="ai-rule-clear-button" type="button" class="options__danger">AI 규칙 모두 삭제</button>
  </div>
  <p id="ai-rule-summary" class="options__meta">AI 규칙을 불러오는 중...</p>
  <div id="ai-rule-list" class="options__site-list"></div>
  <p id="ai-rule-empty" class="options__empty">생성된 AI 규칙이 없습니다.</p>
</section>
```
- [ ] **elements.ts** — add:
```ts
export const aiRuleFilterElement = requiredElement("ai-rule-filter", HTMLSelectElement, surface);
export const aiRuleClearButtonElement = requiredElement("ai-rule-clear-button", HTMLButtonElement, surface);
export const aiRuleListElement = requiredElement("ai-rule-list", HTMLDivElement, surface);
export const aiRuleEmptyElement = requiredElement("ai-rule-empty", HTMLParagraphElement, surface);
export const aiRuleSummaryElement = requiredElement("ai-rule-summary", HTMLParagraphElement, surface);
```
- [ ] **index.ts** — add `import { wireAiRules } from "./ai-rules.js";` and call `wireAiRules();` next to `wireAiSettings();`.
- [ ] **options.css** — append layout rules. Use EXISTING color tokens/variables already defined in options.css (do not introduce new raw hex — there is a banned-hex pre-commit gate; reuse the file's existing CSS custom properties / neutral classes for borders + badge background). Structure:
```css
.options__ai-rule-toolbar { display: flex; gap: 8px; align-items: center; margin: 8px 0; }
.options__ai-site-card { border: 1px solid var(--options-border, #d1d5db); border-radius: 8px; padding: 8px 12px; margin: 8px 0; }
.options__ai-site-header { display: flex; align-items: center; gap: 8px; }
.options__ai-site-title { font-size: 14px; margin: 0; }
.options__ai-rule { display: flex; align-items: center; gap: 8px; padding: 4px 0; flex-wrap: wrap; }
.options__ai-badge { font-size: 11px; padding: 2px 6px; border-radius: 4px; }
.options__ai-selector { font-size: 12px; }
.options__ai-rule-meta { font-size: 12px; opacity: 0.7; }
.options__ai-rule-toggle { display: inline-flex; align-items: center; }
```
(Before committing, the implementer MUST grep options.css for the actual variable names / existing border + muted-background classes and substitute them, replacing any raw hex that the banned-hex gate would reject. Run the pre-commit gate via the normal commit.)
- [ ] `./infocutter check` PASS. Commit `feat(infocutter): options UI for managing AI rules by category`.

---

## Task 4: verify + review + MR

- [ ] `./infocutter rc` PASS.
- [ ] Devtools: seed `aiRuleStore` (via the shimmed storage) with 2 sites/3 rules, boot the options AI panel, confirm: summary line, site cards with per-site + per-rule toggles, category filter narrows the list, clear button empties it, and toggles persist to `infocutter.aiRuleStore` (never the manual `infocutter.ruleStore`).
- [ ] `./infocutter check` PASS.
- [ ] Final code review (separation still holds; reads/writes only aiRuleStore). MR via push options, target main.

---

## Notes
- No new storage functions — `setAiSiteEnabled`/`setAiRuleEnabled`/`clearAiRules` already exist (Phase 1).
- Re-render is driven by `storage.onChanged` on the AI key, so toggles/clear reflect immediately and external auto-trigger writes also refresh the list live.
- Category labels now single-sourced in `ai-category-labels.ts`.
