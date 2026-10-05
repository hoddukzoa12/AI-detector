# AI Auto-Masking Phase 2 (trigger wiring) Implementation Plan

> REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** Wire the Phase 1 detection core into real triggers — a popup "analyze this page" button, an options AI settings section, and an automatic first-visit `webNavigation.onCompleted` trigger.

**Architecture:** The **background service-worker is the orchestrator and the only holder of the API key** — content never receives the secret. Content exposes a `collectAiBlocks` message that returns serialized blocks; background reads `AiConfig` + `AiRuleStore`, builds the prompt, calls LiteLLM, parses/filters, writes `aiRuleStore` via `replaceAiSiteRules`, and marks the host analyzed. The content AI render lane (Phase 1) then hides via `storage.onChanged`. Options writes settings directly through the shared ES modules (no message needed). Tabs are data-driven (add a `data-tab` button + matching panel).

**Tech Stack:** MV3, TypeScript, node:test. Reuses Phase 1 shared modules. `webNavigation` permission + `<all_urls>` already present in manifest.

---

## Task 1: message types

**Files:** Modify `src/shared/messages.ts`.

- [ ] Add to the `messageTypes` const object:
```ts
collectAiBlocks: "infocutter/collect-ai-blocks",
analyzePageAi: "infocutter/analyze-page-ai",
```
- [ ] Verify `./infocutter check` passes. Commit `feat(infocutter): add AI Phase 2 message types`.

---

## Task 2: ai-orchestrator (decision core + composition) + test

**Files:** Create `src/shared/ai-orchestrator.ts`, `tests/ai-orchestrator.test.ts`.

- [ ] **Step 1 — failing test** `tests/ai-orchestrator.test.ts`:
```ts
import test from "node:test";
import assert from "node:assert/strict";

import { decideAiAnalysis } from "../src/shared/ai-orchestrator.js";
import type { AiConfig } from "../src/shared/ai-config.js";
import type { AiRuleStore, AiRuleCategory } from "../src/shared/ai-types.js";

const baseConfig: AiConfig = { endpoint: "e", apiKey: "k", model: "m", analyzedHosts: [] };
const cats: AiRuleCategory[] = ["sexual"];
const baseStore: AiRuleStore = { version: 1, settings: { globalEnabled: true, enabledCategories: cats }, sites: [] };

void test("decideAiAnalysis proceeds when configured + enabled + has categories", () => {
  const d = decideAiAnalysis(baseConfig, baseStore);
  assert.equal(d.proceed, true);
  if (d.proceed) {
    assert.deepEqual(d.categories, ["sexual"]);
    assert.equal(d.model, "m");
  }
});

void test("decideAiAnalysis skips with blank api key", () => {
  const d = decideAiAnalysis({ ...baseConfig, apiKey: "   " }, baseStore);
  assert.equal(d.proceed, false);
  if (!d.proceed) assert.equal(d.reason, "no-api-key");
});

void test("decideAiAnalysis skips when globally disabled", () => {
  const d = decideAiAnalysis(baseConfig, { ...baseStore, settings: { globalEnabled: false, enabledCategories: cats } });
  assert.equal(d.proceed, false);
  if (!d.proceed) assert.equal(d.reason, "disabled");
});

void test("decideAiAnalysis skips with no enabled categories", () => {
  const empty: AiRuleCategory[] = [];
  const d = decideAiAnalysis(baseConfig, { ...baseStore, settings: { globalEnabled: true, enabledCategories: empty } });
  assert.equal(d.proceed, false);
  if (!d.proceed) assert.equal(d.reason, "no-categories");
});
```

- [ ] **Step 2 — implement** `src/shared/ai-orchestrator.ts`:
```ts
import type { AiConfig } from "./ai-config.js";
import { readAiConfig, markHostAnalyzed } from "./ai-config.js";
import type { AiRuleStore, AiRuleCategory } from "./ai-types.js";
import { readAiRuleStore } from "./ai-rule-storage.js";
import { runAiDetection } from "./ai-detection.js";
import { buildAiDetectionPrompt, parseAiDetectionResponse, callLiteLLM } from "./ai-llm-client.js";
import type { AiBlock, AiDetection } from "./ai-llm-client.js";
import { hostnameMatcher, hostnameFromUrl } from "./storage-matchers.js";

export type AiAnalysisDecision =
  | { proceed: true; categories: AiRuleCategory[]; model: string }
  | { proceed: false; reason: "no-api-key" | "disabled" | "no-categories" };

export function decideAiAnalysis(config: AiConfig, store: AiRuleStore): AiAnalysisDecision {
  if (config.apiKey.trim().length === 0) {
    return { proceed: false, reason: "no-api-key" };
  }
  if (!store.settings.globalEnabled) {
    return { proceed: false, reason: "disabled" };
  }
  if (store.settings.enabledCategories.length === 0) {
    return { proceed: false, reason: "no-categories" };
  }
  return { proceed: true, categories: store.settings.enabledCategories, model: config.model };
}

export type AiAnalysisOutcome =
  | { status: "ok"; count: number }
  | { status: "skipped"; reason: string };

export async function analyzePageForAi(
  url: string,
  collectBlocks: () => Promise<AiBlock[]>
): Promise<AiAnalysisOutcome> {
  const config = await readAiConfig();
  const store = await readAiRuleStore();
  const decision = decideAiAnalysis(config, store);
  if (!decision.proceed) {
    return { status: "skipped", reason: decision.reason };
  }
  const blocks = await collectBlocks();
  if (blocks.length === 0) {
    return { status: "skipped", reason: "no-blocks" };
  }
  const detect = async (input: AiBlock[]): Promise<AiDetection[]> => {
    const prompt = buildAiDetectionPrompt(input, decision.categories);
    const text = await callLiteLLM(config, prompt);
    return parseAiDetectionResponse(text);
  };
  const count = await runAiDetection([hostnameMatcher(url)], blocks, decision.categories, decision.model, detect);
  await markHostAnalyzed(hostnameFromUrl(url));
  return { status: "ok", count };
}
```
On LLM failure `callLiteLLM` throws → `analyzePageForAi` rejects → host is NOT marked analyzed (retry-able), per spec.

- [ ] **Step 3** `./infocutter check` PASS (4 new tests). Commit `feat(infocutter): add AI analysis orchestrator (decision + composition)`.

---

## Task 3: content collectAiBlocks message handler

**Files:** Modify `src/content/index.ts`.

- [ ] In the `chrome.runtime.onMessage` dispatch (alongside the other `if (type === messageTypes.X)` branches), add:
```ts
if (type === messageTypes.collectAiBlocks) {
  sendResponse({ ok: true, data: collectAiBlocks() });
  return;
}
```
`collectAiBlocks` is the content global from `ai-collector.js` (loaded before `index.js`). `messageTypes` is already imported.
- [ ] `./infocutter check` PASS. Commit `feat(infocutter): content handler returns AI blocks on demand`.

---

## Task 4: background orchestration + auto-trigger

**Files:** Modify `src/background/service-worker.ts`.

- [ ] **Imports** (top, with the other shared imports):
```ts
import { analyzePageForAi } from "../shared/ai-orchestrator.js";
import { readAiConfig, isHostAnalyzed } from "../shared/ai-config.js";
import { readAiRuleStore } from "../shared/ai-rule-storage.js";
import { hostnameFromUrl } from "../shared/storage-matchers.js";
import type { AiBlock } from "../shared/ai-llm-client.js";
```
- [ ] **Helper** (module scope):
```ts
async function collectAiBlocksFromTab(tabId: number): Promise<AiBlock[]> {
  const response: unknown = await chrome.tabs.sendMessage(tabId, { type: messageTypes.collectAiBlocks });
  if (response && typeof response === "object") {
    const data: unknown = Reflect.get(response, "data");
    if (Array.isArray(data)) {
      return data as AiBlock[];
    }
  }
  return [];
}
```
- [ ] **Manual handler** inside the existing `onMessage` async dispatch (reuse the existing `tabId` local):
```ts
if (type === messageTypes.analyzePageAi) {
  const url = "url" in message && typeof message.url === "string" ? message.url : null;
  if (tabId === null || url === null) {
    sendResponse({ ok: false });
    return;
  }
  const outcome = await analyzePageForAi(url, () => collectAiBlocksFromTab(tabId));
  sendResponse({ ok: true, data: outcome });
  return;
}
```
(Do NOT call `ensureContentScript` — the content script is already injected by the manifest; re-injecting would double-register listeners.)
- [ ] **Auto-trigger** (module scope, top-level registration):
```ts
chrome.webNavigation.onCompleted.addListener((details) => {
  if (details.frameId !== 0) {
    return;
  }
  const url = details.url;
  if (!/^https?:\/\//.test(url)) {
    return;
  }
  void (async () => {
    const config = await readAiConfig();
    if (config.apiKey.trim().length === 0) {
      return;
    }
    const store = await readAiRuleStore();
    if (!store.settings.globalEnabled) {
      return;
    }
    if (isHostAnalyzed(config, hostnameFromUrl(url))) {
      return;
    }
    await analyzePageForAi(url, () => collectAiBlocksFromTab(details.tabId));
  })().catch((error: unknown) => {
    console.warn("인포커터 AI 자동 분석에 실패했습니다", error);
  });
});
```
- [ ] `./infocutter check` PASS. Commit `feat(infocutter): background AI orchestration + first-visit auto-trigger`.

---

## Task 5: popup manual trigger

**Files:** Modify `public/popup.html`, `src/popup/elements.ts`, `src/popup/index.ts`.

- [ ] **popup.html** — add a new actions section after the text-block actions section:
```html
<section class="popup__actions">
  <button id="analyze-ai-button" type="button" class="popup__secondary">이 페이지 자극 영역 자동 가림</button>
</section>
```
- [ ] **elements.ts** — add:
```ts
export const analyzeAiButtonElement = requiredElement("analyze-ai-button", HTMLButtonElement, surface);
```
- [ ] **index.ts** — import `analyzeAiButtonElement` (add to the existing elements import) and `messageTypes` (already imported); add a describe helper + handler:
```ts
function describeAiOutcome(outcome: unknown): string {
  if (outcome && typeof outcome === "object") {
    const status: unknown = Reflect.get(outcome, "status");
    if (status === "ok") {
      const count: unknown = Reflect.get(outcome, "count");
      const n = typeof count === "number" ? count : 0;
      return n > 0 ? `자극 영역 ${n}곳을 가렸습니다.` : "가릴 영역을 찾지 못했습니다.";
    }
    if (status === "skipped") {
      const reason: unknown = Reflect.get(outcome, "reason");
      if (reason === "no-api-key") return "옵션에서 API 키를 먼저 입력하세요.";
      if (reason === "disabled") return "옵션에서 AI 자동 가림을 먼저 켜세요.";
      if (reason === "no-categories") return "옵션에서 가릴 카테고리를 한 개 이상 고르세요.";
      if (reason === "no-blocks") return "분석할 콘텐츠를 찾지 못했습니다.";
    }
  }
  return "분석을 완료했습니다.";
}

analyzeAiButtonElement.addEventListener("click", () => {
  void (async () => {
    try {
      statusElement.textContent = "자극 영역을 분석하는 중...";
      const tab = await getActiveTab();
      if (!isSupportedUrl(tab.url)) {
        statusElement.textContent = "이 페이지에서는 분석할 수 없습니다.";
        return;
      }
      const response = await sendRuntimeMessage<{ ok: boolean; data?: unknown }>({
        type: messageTypes.analyzePageAi,
        tabId: tab.id,
        url: tab.url
      });
      statusElement.textContent = response.ok ? describeAiOutcome(response.data) : "분석에 실패했습니다.";
    } catch (error) {
      statusElement.textContent = error instanceof Error ? error.message : "분석에 실패했습니다.";
    }
  })();
});
```
- [ ] `./infocutter check` PASS. Commit `feat(infocutter): popup AI analyze-this-page button`.

---

## Task 6: options AI settings section

**Files:** Modify `public/options.html`, `src/options/elements.ts`, `public/options.css`; create `src/options/ai-settings.ts`; wire in `src/options/index.ts`.

- [ ] **options.html** — add tab button to the `<nav role="tablist">` (after `tab-name-watch`):
```html
<button class="options__tab" type="button" role="tab" id="tab-ai" data-tab="ai" aria-controls="panel-ai" aria-selected="false" tabindex="-1">AI 가림</button>
```
and add the panel (after the last panel):
```html
<div class="options__panel" role="tabpanel" id="panel-ai" data-panel="ai" aria-labelledby="tab-ai" hidden>
  <section class="options__create-card">
    <h2 class="options__section-title">AI 자동 가림</h2>
    <label class="options__ai-toggle"><input id="ai-global-toggle" type="checkbox" /><span>AI 자동 가림 사용</span></label>
    <p id="ai-status" class="options__meta">설정을 불러오는 중...</p>
    <h2 class="options__section-title">가릴 카테고리</h2>
    <div id="ai-category-list" class="options__ai-category-list"></div>
    <h2 class="options__section-title">LiteLLM 연결</h2>
    <div class="options__template-toolbar">
      <input id="ai-endpoint" class="options__input" type="text" placeholder="https://llm.ranode.net/v1" />
      <input id="ai-api-key" class="options__input" type="password" placeholder="API 키" />
      <input id="ai-model" class="options__input" type="text" placeholder="모델 이름" />
      <button id="ai-save-config-button" type="button">연결 저장</button>
    </div>
  </section>
</div>
```
Category checkboxes are built dynamically from `AI_RULE_CATEGORIES` (single source) — not hardcoded in HTML.
- [ ] **elements.ts** — add:
```ts
export const aiGlobalToggleElement = requiredElement("ai-global-toggle", HTMLInputElement, surface);
export const aiStatusElement = requiredElement("ai-status", HTMLParagraphElement, surface);
export const aiCategoryListElement = requiredElement("ai-category-list", HTMLDivElement, surface);
export const aiEndpointElement = requiredElement("ai-endpoint", HTMLInputElement, surface);
export const aiApiKeyElement = requiredElement("ai-api-key", HTMLInputElement, surface);
export const aiModelElement = requiredElement("ai-model", HTMLInputElement, surface);
export const aiSaveConfigButtonElement = requiredElement("ai-save-config-button", HTMLButtonElement, surface);
```
- [ ] **ai-settings.ts** — create:
```ts
import { AI_RULE_CATEGORIES, AI_DETECTION_ENDPOINT_DEFAULT } from "../shared/constants.js";
import type { AiRuleCategory } from "../shared/ai-types.js";
import { readAiConfig, writeAiConfig } from "../shared/ai-config.js";
import { readAiRuleStore, setAiGlobalEnabled, setAiEnabledCategories } from "../shared/ai-rule-storage.js";
import {
  aiGlobalToggleElement, aiStatusElement, aiCategoryListElement,
  aiEndpointElement, aiApiKeyElement, aiModelElement, aiSaveConfigButtonElement
} from "./elements.js";

const AI_CATEGORY_LABELS: Record<AiRuleCategory, string> = {
  violence: "폭력",
  sexual: "선정성",
  gore: "잔혹/고어",
  hate: "혐오 발언",
  shock: "충격/혐오감",
  other: "기타"
};

function buildCategoryCheckboxes(enabled: AiRuleCategory[]): void {
  aiCategoryListElement.replaceChildren();
  for (const category of AI_RULE_CATEGORIES) {
    const label = document.createElement("label");
    label.className = "options__ai-category";
    const input = document.createElement("input");
    input.type = "checkbox";
    input.value = category;
    input.checked = enabled.includes(category);
    input.addEventListener("change", () => {
      void (async () => {
        const next = Array.from(
          aiCategoryListElement.querySelectorAll<HTMLInputElement>("input[type='checkbox']")
        )
          .filter((box) => box.checked)
          .map((box) => box.value as AiRuleCategory);
        await setAiEnabledCategories(next);
        aiStatusElement.textContent = "카테고리를 저장했습니다.";
      })();
    });
    const span = document.createElement("span");
    span.textContent = AI_CATEGORY_LABELS[category];
    label.append(input, span);
    aiCategoryListElement.append(label);
  }
}

export function wireAiSettings(): void {
  aiGlobalToggleElement.addEventListener("change", () => {
    void (async () => {
      await setAiGlobalEnabled(aiGlobalToggleElement.checked);
      aiStatusElement.textContent = aiGlobalToggleElement.checked ? "AI 자동 가림을 켰습니다." : "AI 자동 가림을 껐습니다.";
    })();
  });

  aiSaveConfigButtonElement.addEventListener("click", () => {
    void (async () => {
      const current = await readAiConfig();
      await writeAiConfig({
        ...current,
        endpoint: aiEndpointElement.value.trim() || AI_DETECTION_ENDPOINT_DEFAULT,
        apiKey: aiApiKeyElement.value.trim(),
        model: aiModelElement.value.trim()
      });
      aiStatusElement.textContent = "연결 설정을 저장했습니다.";
    })();
  });

  void (async () => {
    const config = await readAiConfig();
    const store = await readAiRuleStore();
    aiEndpointElement.value = config.endpoint;
    aiApiKeyElement.value = config.apiKey;
    aiModelElement.value = config.model;
    aiGlobalToggleElement.checked = store.settings.globalEnabled;
    buildCategoryCheckboxes(store.settings.enabledCategories);
    aiStatusElement.textContent = config.apiKey.trim().length === 0
      ? "API 키를 입력하면 AI 자동 가림을 사용할 수 있습니다."
      : "AI 설정을 불러왔습니다.";
  })();
}
```
- [ ] **index.ts** — add `import { wireAiSettings } from "./ai-settings.js";` and call `wireAiSettings();` next to `wireNameWatch();`.
- [ ] **options.css** — append:
```css
.options__ai-toggle { display: flex; align-items: center; gap: 8px; margin: 8px 0; }
.options__ai-category-list { display: flex; flex-wrap: wrap; gap: 12px; margin: 8px 0; }
.options__ai-category { display: flex; align-items: center; gap: 6px; }
```
- [ ] `./infocutter check` PASS. Commit `feat(infocutter): options AI settings section (toggle, categories, LiteLLM)`.

---

## Task 7: final verification + review + MR

- [ ] `./infocutter rc` PASS.
- [ ] Devtools (Mode A harness or options page load): verify options AI panel renders the 6 category checkboxes, the toggle + save persist to `chrome.storage.local` under `infocutter.aiConfig` / `infocutter.aiRuleStore`; verify popup analyze button sends `analyzePageAi`. Stub `fetch` to confirm a canned detection lands in `aiRuleStore` (not the manual store) and renders via the AI lane.
- [ ] `./infocutter check` PASS.
- [ ] Final code review (separation guarantee still holds: secret stays in background, AI data only in aiRuleStore). MR via push options, target main.

---

## Notes (spec reconciliation)

- Background is the only secret holder; content gets no API key (security + separation).
- Settings written directly through shared modules from options (no message); only the cross-tab/secret-bearing analyze path uses background messaging.
- `webNavigation` + `<all_urls>` already in manifest; no permission change.
- Known Phase-3 follow-ups remain: AI rule management UI (browse/toggle by category); render lane category-gating; changing settings does not reset `analyzedHosts`.
