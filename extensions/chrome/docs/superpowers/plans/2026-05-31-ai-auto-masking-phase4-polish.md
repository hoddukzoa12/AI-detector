# AI Auto-Masking Phase 4 (polish) Implementation Plan

> REQUIRED SUB-SKILL: superpowers:subagent-driven-development.

**Goal:** Close the three known follow-ups from Phases 1–3 without changing the data-separation guarantee: (A) clamp `confidence` to [0,1], (B) reset `analyzedHosts` when AI settings change so auto-trigger re-analyzes, (C) gate the content render lane by `enabledCategories` so disabling a category hides its rules live.

**Architecture:** A is a pure parse/normalize hardening (shared). B adds one `resetAnalyzedHosts` helper (ai-config) wired at the two options write sites. C extends the content-side store record (add per-rule `category` + settings `enabledCategories`) and filters rendered rules by it. All AI data stays in `aiRuleStore`/`aiConfig`.

**Tech Stack:** MV3, TS, node:test. No manifest change.

---

## Task A: clamp confidence to [0,1] (TDD)

**Files:** Modify `src/shared/ai-llm-client.ts`, `src/shared/ai-rule-storage.ts`, `tests/ai-llm-client.test.ts`.

- [ ] **Step 1 — extend the existing test** `tests/ai-llm-client.test.ts`, add:
```ts
void test("parseAiDetectionResponse clamps confidence into [0,1] and zeroes non-finite", () => {
  const body = "[" +
    '{"selector":"#a","category":"sexual","reason":"r","confidence":5},' +
    '{"selector":"#b","category":"gore","reason":"r","confidence":-0.5},' +
    '{"selector":"#c","category":"hate","reason":"r","confidence":0.42}' +
    "]";
  const result = parseAiDetectionResponse(body);
  const a = result[0]; assert.ok(a); assert.equal(a.confidence, 1);
  const b = result[1]; assert.ok(b); assert.equal(b.confidence, 0);
  const c = result[2]; assert.ok(c); assert.equal(c.confidence, 0.42);
});
```
- [ ] **Step 2** — in `src/shared/ai-llm-client.ts` add an exported helper and use it in `parseAiDetectionResponse`:
```ts
export function clampConfidence(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? Math.min(1, Math.max(0, value)) : 0;
}
```
Replace the confidence line in `parseAiDetectionResponse` with:
```ts
      confidence: clampConfidence(confidence)
```
- [ ] **Step 3** — in `src/shared/ai-rule-storage.ts`, import `clampConfidence` from `./ai-llm-client.js` and replace the `normalizeAiRule` confidence line (`confidence: typeof confidence === "number" ? confidence : 0`) with `confidence: clampConfidence(confidence)`. (No import cycle: ai-llm-client does not import ai-rule-storage.)
- [ ] **Step 4** `./infocutter check` PASS (1 new test). Commit `fix(infocutter): clamp AI detection confidence into [0,1]`.

---

## Task B: reset analyzedHosts on settings change

**Files:** Modify `src/shared/ai-config.ts`, `src/options/ai-settings.ts`.

- [ ] **Step 1** — in `src/shared/ai-config.ts` add (next to `markHostAnalyzed`):
```ts
export async function resetAnalyzedHosts(): Promise<AiConfig> {
  const config = await readAiConfig();
  const next: AiConfig = { ...config, analyzedHosts: [] };
  await writeAiConfig(next);
  return next;
}
```
- [ ] **Step 2** — in `src/options/ai-settings.ts`:
  - import `resetAnalyzedHosts` alongside `readAiConfig`/`writeAiConfig`.
  - In the save-config handler, change the `writeAiConfig({...})` call to reset analyzed hosts (changing key/model/endpoint should force re-analysis):
    ```ts
    await writeAiConfig({
      ...current,
      endpoint: aiEndpointElement.value.trim() || AI_DETECTION_ENDPOINT_DEFAULT,
      apiKey: aiApiKeyElement.value.trim(),
      model: aiModelElement.value.trim(),
      analyzedHosts: []
    });
    ```
  - In the category-checkbox `change` handler, after `await setAiEnabledCategories(next);` add `await resetAnalyzedHosts();` (changing which categories to act on should re-scan on next visit). Keep the existing status text.
- [ ] **Step 3** `./infocutter check` PASS. Commit `feat(infocutter): reset analyzed hosts when AI key/model/categories change`.

Note: the global on/off toggle does NOT reset analyzed hosts (turning off then on should not force a full re-scan).

---

## Task C: gate content render lane by enabledCategories

**Files:** Modify `src/content/contracts.d.ts`, `src/content/ai-runtime.ts`.

- [ ] **Step 1** — in `src/content/contracts.d.ts`, extend the records:
  - `AiRuleRecord` add `category: string;`
  - `AiRuleStoreRecord.settings` becomes `{ globalEnabled: boolean; enabledCategories: string[] | null }`
- [ ] **Step 2** — in `src/content/ai-runtime.ts` `normalizeAiStoreForContent`:
  - empty default settings → `{ globalEnabled: true, enabledCategories: null }`.
  - parse `enabledCategories`: read `settingsValue.enabledCategories`; if it is an array, keep only strings; otherwise `null` (legacy/absent → no category filter, preserving prior behavior).
  - per-rule: read `category` → `typeof category === "string" ? category : ""` and include it in the returned rule record.
  - return `{ version: 1, settings: { globalEnabled, enabledCategories }, sites }`.
- [ ] **Step 3** — in `renderAiRules`, replace the enabled-rules filter with a category-aware one:
```ts
  const categoryFilter = store.settings.enabledCategories;
  const enabledRules = site.rules.filter((rule) =>
    rule.enabled && (categoryFilter === null || categoryFilter.includes(rule.category))
  );
```
- [ ] **Step 4** `./infocutter check` PASS. Commit `feat(infocutter): gate AI render lane by enabled categories`.

When `enabledCategories` is `null` (legacy store without the field), behavior is unchanged (all enabled rules render). When present, a rule renders only if its category is currently enabled — so unchecking a category in options hides its rules live via storage.onChanged.

---

## Task D: verify + review + MR

- [ ] `./infocutter rc` PASS, `./infocutter check` PASS.
- [ ] Devtools: seed `aiRuleStore` with rules across two categories; load the content AI render harness; confirm that with `enabledCategories` excluding a category, that category's selectors are NOT marked `data-infocutter-ai-hidden`, while included ones are; and a `null`/legacy settings still hides all enabled rules.
- [ ] Final code review (separation intact; clamp correct; reset only on the intended writes; render gate backward-compatible). MR via push options, target main.

## Notes
- No new storage keys; all changes stay within `aiRuleStore`/`aiConfig`.
- `clampConfidence` single-sourced in ai-llm-client and reused by the store normalizer.
- Content category gate is backward-compatible via the `null` sentinel.
